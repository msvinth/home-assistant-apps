#!/usr/bin/with-contenv bashio

# Enable strict error handling
set -e
set -o pipefail

# Initialize environment for GitHub Copilot CLI using /data (HA best practice)
init_environment() {
    # Use /data exclusively - guaranteed writable by HA Supervisor
    local data_home="/data/home"
    local config_dir="/data/.config"
    local cache_dir="/data/.cache"
    local state_dir="/data/.local/state"
    local copilot_config_dir="/data/.config/copilot"

    bashio::log.info "Initializing Copilot CLI environment in /data..."

    # Create all required directories
    if ! mkdir -p "$data_home" "$config_dir/copilot" "$cache_dir" "$state_dir" "/data/.local"; then
        bashio::log.error "Failed to create directories in /data"
        exit 1
    fi

    # Set permissions
    chmod 755 "$data_home" "$config_dir" "$cache_dir" "$state_dir" "$copilot_config_dir"

    # Set XDG and application environment variables
    export HOME="$data_home"
    export XDG_CONFIG_HOME="$config_dir"
    export XDG_CACHE_HOME="$cache_dir"
    export XDG_STATE_HOME="$state_dir"
    export XDG_DATA_HOME="/data/.local/share"

    # Copilot CLI uses $HOME/.copilot/ for its config by default
    # By setting HOME to /data/home, config persists across restarts

    # Set GitHub token for Copilot CLI authentication if configured
    if bashio::config.has_value 'github_token'; then
        local gh_token
        gh_token=$(bashio::config 'github_token')
        if [ -n "$gh_token" ] && [ "$gh_token" != "null" ]; then
            export GITHUB_TOKEN="$gh_token"
            bashio::log.info "GitHub token configured from app settings"
        fi
    fi

    # Log memory status. The standalone Copilot binary is native (not Node.js),
    # so NODE_OPTIONS is not set — it would only affect MCP servers or npm tools.
    local mem_avail_mb
    mem_avail_mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    local mem_total_mb
    mem_total_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)

    if [ "$mem_avail_mb" -lt 300 ]; then
        bashio::log.warning "Low memory: ${mem_avail_mb}MB free of ${mem_total_mb}MB total"
        bashio::log.warning "Copilot CLI needs ~300-500MB to process requests"
        bashio::log.warning "Consider stopping other apps to free memory"
    else
        bashio::log.info "Memory: ${mem_avail_mb}MB free of ${mem_total_mb}MB total"
    fi

    # Install tmux configuration to user home directory
    if [ -f "/opt/scripts/tmux.conf" ]; then
        cp /opt/scripts/tmux.conf "$data_home/.tmux.conf"
        chmod 644 "$data_home/.tmux.conf"
        bashio::log.info "tmux configuration installed to $data_home/.tmux.conf"
    fi

    bashio::log.info "Environment initialized:"
    bashio::log.info "  - Home: $HOME"
    bashio::log.info "  - Config: $XDG_CONFIG_HOME"
    bashio::log.info "  - Copilot config: $HOME/.copilot"
    bashio::log.info "  - Cache: $XDG_CACHE_HOME"
}

# Verify required tools are available (installed at build time via Dockerfile)
install_tools() {
    bashio::log.info "Verifying required tools..."
    local missing=0
    for cmd in ttyd jq curl tmux; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            bashio::log.warning "${cmd} not found, attempting install..."
            if ! apt-get update -qq && apt-get install -y -qq "$cmd"; then
                bashio::log.error "Failed to install ${cmd}"
                missing=1
            fi
        fi
    done
    if [ "$missing" -eq 1 ]; then
        bashio::log.error "Some required tools are missing"
        exit 1
    fi
    bashio::log.info "All required tools available"
}

# Install persistent packages from config and saved state
install_persistent_packages() {
    bashio::log.info "Checking for persistent packages..."

    local persist_config="/data/persistent-packages.json"
    local apk_packages=""
    local pip_packages=""

    # Collect APK/APT packages from Home Assistant config
    if bashio::config.has_value 'persistent_apk_packages'; then
        local config_apk
        config_apk=$(bashio::config 'persistent_apk_packages')
        if [ -n "$config_apk" ] && [ "$config_apk" != "null" ]; then
            apk_packages="$config_apk"
            bashio::log.info "Found system packages in config: $apk_packages"
        fi
    fi

    # Collect pip packages from Home Assistant config
    if bashio::config.has_value 'persistent_pip_packages'; then
        local config_pip
        config_pip=$(bashio::config 'persistent_pip_packages')
        if [ -n "$config_pip" ] && [ "$config_pip" != "null" ]; then
            pip_packages="$config_pip"
            bashio::log.info "Found pip packages in config: $pip_packages"
        fi
    fi

    # Also check local persist-install config file
    if [ -f "$persist_config" ]; then
        bashio::log.info "Found local persistent packages config"

        local local_apk
        local_apk=$(jq -r '.apk_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        if [ -n "$local_apk" ]; then
            apk_packages="$apk_packages $local_apk"
        fi

        local local_pip
        local_pip=$(jq -r '.pip_packages | join(" ")' "$persist_config" 2>/dev/null || echo "")
        if [ -n "$local_pip" ]; then
            pip_packages="$pip_packages $local_pip"
        fi
    fi

    # Trim whitespace and remove duplicates
    apk_packages=$(echo "$apk_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
    pip_packages=$(echo "$pip_packages" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

    # Install APT packages
    if [ -n "$apk_packages" ]; then
        bashio::log.info "Installing persistent system packages: $apk_packages"
        # shellcheck disable=SC2086
        if apt-get update -qq && apt-get install -y -qq $apk_packages; then
            bashio::log.info "System packages installed successfully"
        else
            bashio::log.warning "Some system packages failed to install"
        fi
    fi

    # Install pip packages
    if [ -n "$pip_packages" ]; then
        bashio::log.info "Installing persistent pip packages: $pip_packages"
        # shellcheck disable=SC2086
        if pip3 install --break-system-packages --no-cache-dir $pip_packages; then
            bashio::log.info "pip packages installed successfully"
        else
            bashio::log.warning "Some pip packages failed to install"
        fi
    fi

    if [ -z "$apk_packages" ] && [ -z "$pip_packages" ]; then
        bashio::log.info "No persistent packages configured"
    fi
}

# Setup session picker script
setup_session_picker() {
    # Copy session picker script from built-in location
    if [ -f "/opt/scripts/copilot-session-picker.sh" ]; then
        if ! cp /opt/scripts/copilot-session-picker.sh /usr/local/bin/copilot-session-picker; then
            bashio::log.error "Failed to copy copilot-session-picker script"
            exit 1
        fi
        chmod +x /usr/local/bin/copilot-session-picker
        bashio::log.info "Session picker script installed successfully"
    else
        bashio::log.warning "Session picker script not found, using auto-launch mode only"
    fi

    # Setup persist-install script if it exists
    if [ -f "/opt/scripts/persist-install.sh" ]; then
        if ! cp /opt/scripts/persist-install.sh /usr/local/bin/persist-install; then
            bashio::log.warning "Failed to copy persist-install script"
        else
            chmod +x /usr/local/bin/persist-install
            bashio::log.info "Persist-install script installed successfully"
        fi
    fi

    # Setup welcome script
    if [ -f "/opt/scripts/welcome.sh" ]; then
        if cp /opt/scripts/welcome.sh /usr/local/bin/welcome; then
            chmod +x /usr/local/bin/welcome
            bashio::log.info "Welcome script installed successfully"
        else
            bashio::log.warning "Failed to copy welcome script"
        fi
    fi

    # Setup terminal launcher script (handles reconnection gracefully)
    if [ -f "/opt/scripts/terminal-launcher.sh" ]; then
        if cp /opt/scripts/terminal-launcher.sh /usr/local/bin/terminal-launcher; then
            chmod +x /usr/local/bin/terminal-launcher
            bashio::log.info "Terminal launcher script installed successfully"
        else
            bashio::log.warning "Failed to copy terminal-launcher script"
        fi
    fi

    # Setup ha-context script
    if [ -f "/opt/scripts/ha-context.sh" ]; then
        if cp /opt/scripts/ha-context.sh /usr/local/bin/ha-context; then
            chmod +x /usr/local/bin/ha-context
            bashio::log.info "HA context script installed successfully"
        else
            bashio::log.warning "Failed to copy ha-context script"
        fi
    fi

    # Write app version for welcome script to read (avoids bashio dependency in ttyd)
    bashio::addon.version > /opt/scripts/addon-version 2>/dev/null || echo "unknown" > /opt/scripts/addon-version
}

# Generate Home Assistant context file for Copilot sessions
generate_ha_context() {
    local ha_smart_context
    ha_smart_context=$(bashio::config 'ha_smart_context' 'true')

    if [ "$ha_smart_context" = "true" ]; then
        bashio::log.info "Generating Home Assistant context for Copilot sessions..."
        if [ -f /usr/local/bin/ha-context ]; then
            if /usr/local/bin/ha-context 2>&1 | while IFS= read -r line; do
                bashio::log.info "$line"
            done; then
                bashio::log.info "HA context generated successfully"
            else
                bashio::log.warning "HA context generation had issues, continuing..."
            fi
        else
            bashio::log.warning "ha-context script not found, skipping"
        fi

        # Copilot CLI searches for instructions in the CWD and parent dirs.
        # Different versions may look for different file names. Cover all variants:
        local instructions_file="${HOME}/.copilot/copilot-instructions.md"
        if [ -f "$instructions_file" ]; then
            mkdir -p /config/.github /config/.copilot
            ln -sf "$instructions_file" /config/.github/copilot-instructions.md
            ln -sf "$instructions_file" /config/copilot-instructions.md
            ln -sf "$instructions_file" /config/.copilot-instructions.md
            ln -sf "$instructions_file" /config/.copilot/copilot-instructions.md
            bashio::log.info "Copilot instructions linked to /config/ (multiple locations)"
        fi
    else
        bashio::log.info "HA Smart Context disabled in configuration"
    fi
}

# Determine Copilot launch command based on configuration
get_copilot_launch_command() {
    local auto_launch_copilot

    # Get configuration value, default to true for backward compatibility
    auto_launch_copilot=$(bashio::config 'auto_launch_copilot' 'true')

    if [ "$auto_launch_copilot" = "true" ]; then
        if [ -f /usr/local/bin/terminal-launcher ]; then
            echo "direct:/usr/local/bin/terminal-launcher"
        else
            bashio::log.warning "Terminal launcher not found, using basic command"
            echo "shell:tmux new-session -A -s copilot 'copilot'"
        fi
    else
        if [ -f /usr/local/bin/copilot-session-picker ]; then
            echo "direct:/usr/local/bin/copilot-session-picker"
        else
            bashio::log.warning "Session picker not found, falling back to auto-launch"
            if [ -f /usr/local/bin/terminal-launcher ]; then
                echo "direct:/usr/local/bin/terminal-launcher"
            else
                echo "shell:tmux new-session -A -s copilot 'copilot'"
            fi
        fi
    fi
}

# Start image upload service (Python proxy in front of ttyd)
# Provides drag-drop/paste image upload + clipboard helpers
start_image_service() {
    local image_port=7680
    local ttyd_port=7681
    local upload_dir="/data/images"

    bashio::log.info "Starting image upload service on port ${image_port}..."

    mkdir -p "${upload_dir}"
    chmod 755 "${upload_dir}"

    export IMAGE_SERVICE_PORT="${image_port}"
    export TTYD_PORT="${ttyd_port}"
    export UPLOAD_DIR="${upload_dir}"

    if [ ! -f /opt/image-service/server.py ]; then
        bashio::log.warning "Image service not found, ttyd will listen on ingress port directly"
        return 1
    fi

    PYTHONUNBUFFERED=1 python3 /opt/image-service/server.py 2>&1 &
    local pid=$!
    bashio::log.info "Image service started (PID: ${pid})"

    sleep 1
    return 0
}

# Start main web terminal
start_web_terminal() {
    bashio::log.info "HOME=${HOME}"

    # Try to start image service (proxy on 7680, ttyd on 7681)
    # If it fails, ttyd listens directly on 7680
    local ttyd_port=7680
    if start_image_service; then
        ttyd_port=7681
    fi

    bashio::log.info "Starting web terminal on port ${ttyd_port}..."

    # Get the appropriate launch command based on configuration
    local launch_spec
    launch_spec=$(get_copilot_launch_command)

    local auto_launch_copilot
    auto_launch_copilot=$(bashio::config 'auto_launch_copilot' 'true')
    bashio::log.info "Auto-launch Copilot: ${auto_launch_copilot}"

    # Set TTYD environment variable for tmux configuration
    export TTYD=1

    # Terminal theme - dark palette with GitHub blue/green accents
    local ttyd_theme='{"background":"#0d1117","foreground":"#c9d1d9","cursor":"#58a6ff","cursorAccent":"#0d1117","selectionBackground":"#264f78","selectionForeground":"#c9d1d9","black":"#0d1117","red":"#ff7b72","green":"#3fb950","yellow":"#d29922","blue":"#58a6ff","magenta":"#bc8cff","cyan":"#39d2c0","white":"#b1bac4","brightBlack":"#484f58","brightRed":"#ffa198","brightGreen":"#56d364","brightYellow":"#e3b341","brightBlue":"#79c0ff","brightMagenta":"#d2a8ff","brightCyan":"#56d4dd","brightWhite":"#f0f6fc"}'

    local launch_type="${launch_spec%%:*}"
    local launch_command="${launch_spec#*:}"

    bashio::log.info "Launch mode: ${launch_type}, command: ${launch_command}"

    if [ "$launch_type" = "direct" ]; then
        exec ttyd \
            --port "${ttyd_port}" \
            --interface 0.0.0.0 \
            --writable \
            --ping-interval 30 \
            --max-clients 5 \
            --client-option enableReconnect=true \
            --client-option reconnect=0 \
            --client-option reconnectInterval=3 \
            --client-option "theme=${ttyd_theme}" \
            --client-option fontSize=14 \
            --client-option disableLeaveAlert=true \
            "$launch_command"
    else
        exec ttyd \
            --port "${ttyd_port}" \
            --interface 0.0.0.0 \
            --writable \
            --ping-interval 30 \
            --max-clients 5 \
            --client-option enableReconnect=true \
            --client-option reconnect=0 \
            --client-option reconnectInterval=3 \
            --client-option "theme=${ttyd_theme}" \
            --client-option fontSize=14 \
            --client-option disableLeaveAlert=true \
            bash -c "$launch_command"
    fi
}

# Run health check
run_health_check() {
    if [ -f "/opt/scripts/health-check.sh" ]; then
        bashio::log.info "Running system health check..."
        chmod +x /opt/scripts/health-check.sh
        /opt/scripts/health-check.sh || bashio::log.warning "Some health checks failed but continuing..."
    fi
}

# Setup ha-mcp (Home Assistant MCP Server) for Copilot CLI integration
setup_ha_mcp() {
    if [ -f "/opt/scripts/setup-ha-mcp.sh" ]; then
        bashio::log.info "Setting up Home Assistant MCP integration..."
        chmod +x /opt/scripts/setup-ha-mcp.sh
        source /opt/scripts/setup-ha-mcp.sh
        configure_ha_mcp_server || bashio::log.warning "ha-mcp setup encountered issues but continuing..."
    else
        bashio::log.info "ha-mcp setup script not found, skipping MCP integration"
    fi
}

# Main execution
main() {
    bashio::log.info "Initializing Copilot Terminal app..."

    run_health_check
    init_environment
    install_tools
    setup_session_picker
    install_persistent_packages
    generate_ha_context
    setup_ha_mcp
    start_web_terminal
}

main "$@"
