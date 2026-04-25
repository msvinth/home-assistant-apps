# Copilot Terminal

A terminal interface for GitHub Copilot CLI in Home Assistant.

## About

This app provides a web-based terminal with GitHub Copilot CLI pre-installed, allowing you to access Copilot's powerful AI capabilities directly from your Home Assistant dashboard. The terminal provides full access to Copilot's code generation, explanation, and problem-solving capabilities.

## Installation

1. Add this repository to your Home Assistant app store
2. Install the Copilot Terminal app
3. Start the app
4. Click "OPEN WEB UI" to access the terminal
5. On first use, follow the GitHub OAuth prompts to log in to your GitHub account

## Configuration

No configuration is needed! The app uses GitHub OAuth authentication (device flow), so you'll be prompted to log in to your GitHub account the first time you use it.

Alternatively, you can set a `GH_TOKEN` or `GITHUB_TOKEN` environment variable with a fine-grained PAT that has the "Copilot Requests" permission.

Your authentication credentials are stored in `/data/home/.copilot/` and will persist across app updates and restarts.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `auto_launch_copilot` | `true` | Automatically start Copilot when opening the terminal |
| `ha_smart_context` | `true` | Generate Home Assistant context for Copilot sessions |
| `enable_ha_mcp` | `true` | Enable Home Assistant MCP server integration |
| `persistent_apk_packages` | `[]` | APK packages to install on every startup |
| `persistent_pip_packages` | `[]` | Python packages to install on every startup |

## Usage

Copilot launches automatically when you open the terminal. You can also start Copilot manually with:

```bash
copilot
```

### Common Commands

- `copilot` - Start an interactive Copilot session
- `copilot --help` - See all available commands
- `copilot -p "your prompt"` - Ask Copilot a single question
- `copilot --continue` - Continue the most recent conversation
- `copilot --resume` - Resume from conversation list

The terminal starts directly in your `/config` directory, giving you immediate access to all your Home Assistant configuration files.

## Features

- **Web Terminal**: Access a full terminal environment via your browser
- **Auto-Launching**: Copilot starts automatically when you open the terminal
- **GitHub Copilot AI**: Access Copilot's AI capabilities for programming, troubleshooting and more
- **Direct Config Access**: Terminal starts in `/config` for immediate access to all Home Assistant files
- **Simple Setup**: Uses GitHub OAuth for easy authentication
- **Home Assistant Integration**: Access directly from your dashboard
- **Home Assistant MCP Server**: Built-in integration with [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) for natural language control

## Home Assistant MCP Integration

This app includes the [homeassistant-ai/ha-mcp](https://github.com/homeassistant-ai/ha-mcp) MCP server, enabling Copilot to directly interact with your Home Assistant instance using natural language.

### What You Can Do

- **Control Devices**: "Turn off the living room lights", "Set the thermostat to 72°F"
- **Query States**: "What's the temperature in the bedroom?", "Is the front door locked?"
- **Manage Automations**: "Create an automation that turns on the porch light at sunset"
- **Work with Scripts**: "Run my movie mode script", "Create a script for my morning routine"
- **View History**: "Show me the energy usage for the last week"
- **Debug Issues**: "Why isn't my motion sensor automation triggering?"
- **Manage Dashboards**: "Add a weather card to my dashboard"

### How It Works

The MCP (Model Context Protocol) server automatically connects to your Home Assistant using the Supervisor API. No manual configuration or token setup is required.

### Security Note

The ha-mcp integration gives Copilot extensive control over your Home Assistant instance. Only enable this if you understand and accept these capabilities. You can disable it by setting `enable_ha_mcp: false` in the app configuration.

### Disabling the Integration

```yaml
enable_ha_mcp: false
```

## Troubleshooting

- If Copilot doesn't start automatically, try running `copilot` manually
- If you see permission errors, try restarting the app
- If you have authentication issues, use the `/login` command inside Copilot
- Check the app logs for any error messages

## Credits

This app was inspired by the [Claude Terminal](https://github.com/heytcass/home-assistant-addons) add-on by Tom Cassady.
