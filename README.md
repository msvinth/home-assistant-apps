# Copilot Terminal for Home Assistant

This repository contains a custom Home Assistant app that integrates GitHub's Copilot CLI with Home Assistant.

## Installation

To add this repository to your Home Assistant instance:

1. Go to **Settings** → **Apps** → **App Store**
2. Click the three dots menu in the top right corner
3. Select **Repositories**
4. Add the URL: `https://github.com/msvinth/home-assistant-apps`
5. Click **Add**

## Apps

### Copilot Terminal

A web-based terminal interface with GitHub Copilot CLI pre-installed. This app provides a terminal environment directly in your Home Assistant dashboard, allowing you to use Copilot's powerful AI capabilities for coding, automation, and configuration tasks.

Features:
- Web terminal access through your Home Assistant UI
- Pre-installed GitHub Copilot CLI that launches automatically
- Direct access to your Home Assistant config directory
- GitHub OAuth authentication (device flow or PAT)
- Access to Copilot's complete capabilities including:
  - Code generation and explanation
  - Debugging assistance
  - Home Assistant automation help
  - MCP-powered extensibility

[Documentation](copilot-terminal/DOCS.md)

## Support

If you have any questions or issues with this app, please create an issue in this repository.

## Credits

This app was inspired by the [Claude Terminal](https://github.com/heytcass/home-assistant-addons) add-on by Tom Cassady.

## License

This repository is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
