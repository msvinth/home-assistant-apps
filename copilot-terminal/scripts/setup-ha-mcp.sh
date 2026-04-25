#!/usr/bin/with-contenv bashio
# Setup ha-mcp (Home Assistant MCP Server) for Copilot CLI
# This script configures Copilot CLI to use ha-mcp for Home Assistant integration
# Repository: https://github.com/homeassistant-ai/ha-mcp

set -e

configure_ha_mcp_server() {
    local enable_ha_mcp
    enable_ha_mcp=$(bashio::config 'enable_ha_mcp' 'true')

    if [ "$enable_ha_mcp" != "true" ]; then
        bashio::log.info "ha-mcp integration is disabled in configuration"
        return 0
    fi

    bashio::log.info "Setting up ha-mcp (Home Assistant MCP Server)..."

    if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
        bashio::log.warning "SUPERVISOR_TOKEN not available - ha-mcp setup skipped"
        bashio::log.warning "MCP server requires Supervisor API access"
        return 0
    fi

    if ! command -v uvx &> /dev/null; then
        bashio::log.warning "uvx not found - ha-mcp setup skipped"
        return 0
    fi

    bashio::log.info "Configuring Copilot CLI MCP server for Home Assistant..."

    # Copilot CLI uses ~/.copilot/mcp-config.json for MCP server configuration
    local mcp_config_dir="${HOME}/.copilot"
    local mcp_config_file="${mcp_config_dir}/mcp-config.json"

    mkdir -p "$mcp_config_dir"

    # Build the MCP configuration JSON matching copilot mcp add output format
    cat > "$mcp_config_file" << EOF
{
  "mcpServers": {
    "home-assistant": {
      "type": "local",
      "command": "uvx",
      "args": ["--index-strategy", "unsafe-best-match", "--python", "3.12", "ha-mcp"],
      "env": {
        "HOMEASSISTANT_URL": "http://supervisor/core",
        "HOMEASSISTANT_TOKEN": "${SUPERVISOR_TOKEN}"
      },
      "tools": ["*"]
    }
  }
}
EOF

    chmod 600 "$mcp_config_file"

    bashio::log.info "ha-mcp configured successfully via ${mcp_config_file}"
    bashio::log.info "Copilot CLI now has access to Home Assistant via MCP"
    bashio::log.info "Available tools: entity control, automations, scripts, dashboards, history, and more"
}

# Run setup if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    configure_ha_mcp_server
fi
