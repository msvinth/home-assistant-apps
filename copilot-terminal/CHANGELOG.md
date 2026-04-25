# Changelog

## 1.0.4

- **Fixed**: Further OOM reduction — removed Node.js/npm (~100MB+ RAM savings)
- **Removed**: nodejs, npm, vim, wget, tree, python3-aiohttp/requests/bs4/yaml from image
- **Improved**: Health check now reports swap usage and warns at 400MB threshold
- **Improved**: Lighter health check (fewer network checks, no node.js check)
- **Note**: Copilot CLI is a native binary — Node.js was never needed at runtime

## 1.0.3

- **Fixed**: OOM kills on memory-constrained systems (~2GB RAM)
- **Removed**: Python image-service proxy — ttyd now listens directly on ingress port, saving ~30-50MB RAM
- **Removed**: Unnecessary Python packages (aiohttp, requests, bs4, yaml) from Docker image
- **Removed**: `NODE_OPTIONS` env var — irrelevant for native Copilot binary
- **Added**: Memory warning at startup when available RAM is below 300MB
- **Improved**: Simpler architecture — fewer processes, lower memory footprint

## 1.0.2

- **Fixed**: Build failure on aarch64 — auto-detect architecture with `uname -m` instead of relying on `BUILD_ARCH` arg
- **Fixed**: Removed `BUILD_ARCH` build arg from build.yaml (Supervisor `{arch}` template not resolved)

## 1.0.1

- **Fixed**: Copilot CLI now works correctly — switched to standalone binary from GitHub releases
- **Fixed**: Switched from Alpine to Debian base image for glibc compatibility
- **Added**: `github_token` configuration option for PAT-based authentication
- **Added**: `ingress_stream` support for reliable WebSocket connections
- **Added**: Better error diagnostics when Copilot CLI fails to start
- **Improved**: Health check now verifies the binary actually runs, not just exists

## 1.0.0

- **Initial Release**: Copilot Terminal for Home Assistant
- **Web Terminal**: ttyd-based terminal with GitHub Copilot CLI pre-installed
- **GitHub Auth**: OAuth device flow authentication for GitHub Copilot
- **HA Smart Context**: Auto-generated Home Assistant context for Copilot sessions
- **MCP Integration**: ha-mcp server for natural language Home Assistant control
- **Image Upload**: Paste/drag-drop image upload support
- **Session Management**: tmux-based session persistence across browser reconnects
- **Persistent Packages**: APK and pip packages that survive container restarts
- **Health Checks**: System diagnostics on startup
