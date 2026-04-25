# Changelog

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
