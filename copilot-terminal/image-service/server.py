#!/usr/bin/env python3
"""Image upload proxy for Copilot Terminal.

Lightweight aiohttp server (no extra deps — py3-aiohttp is pre-installed) that:
  - Serves custom HTML with paste/drag-drop image upload support
  - Handles POST /upload (saves images to /data/images/)
  - Proxies HTTP + WebSocket to ttyd on an internal port
"""

import asyncio
import os
import sys
import time
from pathlib import Path

from aiohttp import web, ClientSession, WSMsgType

TTYD_PORT = int(os.environ.get('TTYD_PORT', 7681))
TTYD_URL = f'http://127.0.0.1:{TTYD_PORT}'
UPLOAD_DIR = Path(os.environ.get('UPLOAD_DIR', '/data/images'))
PORT = int(os.environ.get('IMAGE_SERVICE_PORT', 7680))
MAX_SIZE = 10 * 1024 * 1024  # 10 MB
ALLOWED_TYPES = frozenset({
    'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml',
})
EXT_MAP = {
    'image/jpeg': '.jpg', 'image/png': '.png', 'image/gif': '.gif',
    'image/webp': '.webp', 'image/svg+xml': '.svg',
}
STATIC_DIR = Path(__file__).parent / 'static'

# Hop-by-hop headers that must NOT be forwarded through a proxy
HOP_BY_HOP = frozenset({
    'transfer-encoding', 'connection', 'keep-alive',
    'upgrade', 'proxy-authorization', 'proxy-authenticate', 'te', 'trailers',
    'content-length',
})


IMAGE_MAX_AGE = int(os.environ.get('IMAGE_MAX_AGE_HOURS', 6)) * 3600
CLEANUP_INTERVAL = 30 * 60


def log(msg):
    print(f'[image-service] {msg}', flush=True)


async def cleanup_old_images(app):
    """Periodically delete uploaded images older than IMAGE_MAX_AGE."""
    while True:
        await asyncio.sleep(CLEANUP_INTERVAL)
        try:
            now = time.time()
            removed = 0
            for f in UPLOAD_DIR.iterdir():
                if f.is_file() and (now - f.stat().st_mtime) > IMAGE_MAX_AGE:
                    f.unlink()
                    removed += 1
            if removed:
                log(f'Cleanup: removed {removed} image(s) older than {IMAGE_MAX_AGE // 3600}h')
        except Exception as exc:
            log(f'Cleanup error: {exc}')


async def on_startup(app):
    app['session'] = ClientSession(auto_decompress=False)
    app['cleanup_task'] = asyncio.create_task(cleanup_old_images(app))
    log(f'Proxy ready — port {PORT} → ttyd :{TTYD_PORT}')
    log(f'Image cleanup: every {CLEANUP_INTERVAL // 60}min, max age {IMAGE_MAX_AGE // 3600}h')


async def on_cleanup(app):
    app['cleanup_task'].cancel()
    await app['session'].close()


async def handle_upload(request):
    """Save an uploaded image and return its file path."""
    reader = await request.multipart()
    field = await reader.next()
    if not field or field.name != 'image':
        return web.json_response({'error': 'No image provided'}, status=400)

    content_type = field.headers.get('Content-Type', '')
    if content_type not in ALLOWED_TYPES:
        return web.json_response(
            {'error': f'Unsupported image type: {content_type}'}, status=400,
        )

    ext = EXT_MAP.get(content_type, '.png')
    filename = f'pasted-{int(time.time() * 1000)}{ext}'
    filepath = UPLOAD_DIR / filename

    size = 0
    with open(filepath, 'wb') as f:
        while True:
            chunk = await field.read_chunk(8192)
            if not chunk:
                break
            size += len(chunk)
            if size > MAX_SIZE:
                filepath.unlink(missing_ok=True)
                return web.json_response(
                    {'error': 'File too large (10 MB max)'}, status=400,
                )
            f.write(chunk)

    filepath.chmod(0o644)
    return web.json_response({
        'success': True,
        'path': str(filepath),
        'filename': filename,
        'size': size,
    })


async def ws_proxy(request, path='ws'):
    """Bidirectional WebSocket proxy to ttyd."""
    ws_up = web.WebSocketResponse(protocols=['tty'], heartbeat=20.0)
    await ws_up.prepare(request)

    qs = request.query_string
    ws_url = f'ws://127.0.0.1:{TTYD_PORT}/{path}{"?" + qs if qs else ""}'
    log(f'WS proxy → {ws_url}')

    session = request.app['session']
    try:
        async with session.ws_connect(
            ws_url, protocols=['tty'], heartbeat=30.0,
        ) as ws_down:
            async def forward(src, dst):
                async for msg in src:
                    if msg.type == WSMsgType.BINARY:
                        await dst.send_bytes(msg.data)
                    elif msg.type == WSMsgType.TEXT:
                        await dst.send_str(msg.data)
                    elif msg.type == WSMsgType.PING:
                        await dst.ping(msg.data)
                    elif msg.type == WSMsgType.PONG:
                        await dst.pong(msg.data)
                    elif msg.type in (
                        WSMsgType.CLOSE, WSMsgType.CLOSING, WSMsgType.ERROR,
                    ):
                        return

            done, pending = await asyncio.wait(
                [
                    asyncio.create_task(forward(ws_up, ws_down)),
                    asyncio.create_task(forward(ws_down, ws_up)),
                ],
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in pending:
                task.cancel()
    except Exception as exc:
        log(f'WSocket proxy error: {exc}')

    return ws_up


async def terminal_proxy(request):
    """Proxy /terminal/* to ttyd — handles both HTTP and WebSocket."""
    path = request.match_info.get('path', '')

    if request.headers.get('upgrade', '').lower() == 'websocket':
        return await ws_proxy(request, path)

    url = f'{TTYD_URL}/{path}'
    if request.query_string:
        url += f'?{request.query_string}'

    log(f'HTTP {request.method} /terminal/{path} → {url}')

    session = request.app['session']
    try:
        async with session.request(
            request.method,
            url,
            headers={
                k: v for k, v in request.headers.items()
                if k.lower() not in HOP_BY_HOP and k.lower() != 'host'
            },
            data=await request.read(),
            allow_redirects=False,
        ) as resp:
            body = await resp.read()
            headers = {
                k: v for k, v in resp.headers.items()
                if k.lower() not in HOP_BY_HOP
            }
            headers['Permissions-Policy'] = 'clipboard-read=*, clipboard-write=*'
            log(f'  → {resp.status} ({len(body)} bytes, ct={resp.content_type})')
            return web.Response(
                body=body,
                status=resp.status,
                headers=headers,
            )
    except Exception as exc:
        log(f'Proxy error for /terminal/{path}: {exc}')
        return web.Response(text=f'Terminal not ready: {exc}', status=502)


async def index_handler(request):
    resp = web.FileResponse(STATIC_DIR / 'index.html')
    resp.headers['Permissions-Policy'] = 'clipboard-read=*, clipboard-write=*'
    return resp


def create_app():
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    app = web.Application(client_max_size=MAX_SIZE + 4096)
    app.on_startup.append(on_startup)
    app.on_cleanup.append(on_cleanup)

    app.router.add_get('/', index_handler)
    app.router.add_post('/upload', handle_upload)
    app.router.add_route('*', '/terminal/{path:.*}', terminal_proxy)
    app.router.add_route('*', '/terminal', terminal_proxy)

    return app


if __name__ == '__main__':
    log(f'Starting — port {PORT} → ttyd :{TTYD_PORT}')
    web.run_app(
        create_app(),
        host='0.0.0.0',
        port=PORT,
        print=lambda s: log(s),
    )
