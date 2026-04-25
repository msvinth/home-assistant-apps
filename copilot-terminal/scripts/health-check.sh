#!/usr/bin/with-contenv bashio

# Health check script for Copilot Terminal app
# Validates environment and provides diagnostic information

check_system_resources() {
    bashio::log.info "=== System Resources Check ==="

    local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    local mem_free=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    bashio::log.info "Memory: ${mem_free}MB free of ${mem_total}MB total"

    if [ "$mem_free" -lt 256 ]; then
        bashio::log.error "Low memory warning: Less than 256MB available"
        bashio::log.info "This may cause installation or runtime issues"
    fi

    local disk_free=$(df -m /data | tail -1 | awk '{print $4}')
    bashio::log.info "Disk space in /data: ${disk_free}MB free"

    if [ "$disk_free" -lt 100 ]; then
        bashio::log.error "Low disk space warning: Less than 100MB in /data"
    fi
}

check_directory_permissions() {
    bashio::log.info "=== Directory Permissions Check ==="

    if [ -w "/data" ]; then
        bashio::log.info "/data directory: Writable ✓"
    else
        bashio::log.error "/data directory: Not writable ✗"
        return 1
    fi

    local test_dir="/data/.test_$$"
    if mkdir -p "$test_dir" 2>/dev/null; then
        bashio::log.info "Can create directories in /data ✓"
        rmdir "$test_dir"
    else
        bashio::log.error "Cannot create directories in /data ✗"
        return 1
    fi
}

check_node_installation() {
    bashio::log.info "=== Node.js Installation Check ==="

    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        bashio::log.info "Node.js installed: $node_version ✓"
    else
        bashio::log.error "Node.js not found ✗"
        return 1
    fi

    if command -v npm >/dev/null 2>&1; then
        local npm_version=$(npm --version)
        bashio::log.info "npm installed: $npm_version ✓"
    else
        bashio::log.error "npm not found ✗"
        return 1
    fi
}

check_copilot_cli() {
    bashio::log.info "=== Copilot CLI Check ==="

    if ! command -v copilot >/dev/null 2>&1; then
        bashio::log.error "Copilot CLI not found ✗"
        return 1
    fi

    bashio::log.info "Copilot CLI found at: $(which copilot) ✓"

    # Actually run the binary to verify glibc/musl compatibility
    local version_output
    if version_output=$(copilot --version 2>&1); then
        bashio::log.info "Copilot CLI version: ${version_output} ✓"
    else
        bashio::log.error "Copilot CLI binary failed to run ✗"
        bashio::log.error "Output: ${version_output}"
        bashio::log.info "This usually means the native binary is incompatible with Alpine musl libc"
        return 1
    fi
}

check_network_connectivity() {
    bashio::log.info "=== Network Connectivity Check ==="

    # Check DNS resolution using curl (bind-tools not installed)
    if curl -s --connect-timeout 5 --max-time 10 https://registry.npmjs.org > /dev/null 2>&1; then
        bashio::log.info "DNS resolution working ✓"
    else
        bashio::log.warning "DNS resolution may be failing - check network configuration"
        bashio::log.info "Try setting custom DNS servers (e.g., 8.8.8.8, 1.1.1.1)"
    fi

    # Try to reach npm registry
    if curl -s --head --connect-timeout 10 --max-time 15 https://registry.npmjs.org > /dev/null; then
        bashio::log.info "Can reach npm registry ✓"
    else
        bashio::log.warning "Cannot reach npm registry - this may affect Copilot CLI installation"
    fi

    # Try to reach GitHub API
    if curl -s --head --connect-timeout 10 --max-time 15 https://api.github.com > /dev/null; then
        bashio::log.info "Can reach GitHub API ✓"
    else
        bashio::log.warning "Cannot reach GitHub API - Copilot CLI requires GitHub connectivity"
    fi

    # Try to reach GitHub Container Registry
    if curl -s --head --connect-timeout 10 --max-time 15 https://ghcr.io > /dev/null; then
        bashio::log.info "Can reach GitHub Container Registry ✓"
    else
        bashio::log.error "Cannot reach GitHub Container Registry (ghcr.io)"
    fi
}

run_diagnostics() {
    bashio::log.info "========================================="
    bashio::log.info "Copilot Terminal App Health Check"
    bashio::log.info "========================================="

    local errors=0

    check_system_resources || ((errors++))
    check_directory_permissions || ((errors++))
    check_node_installation || ((errors++))
    check_copilot_cli || ((errors++))
    check_network_connectivity || ((errors++))

    bashio::log.info "========================================="

    if [ "$errors" -eq 0 ]; then
        bashio::log.info "✅ All checks passed successfully!"
    else
        bashio::log.error "❌ $errors check(s) failed"
        bashio::log.info "Please review the errors above"
    fi

    return $errors
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_diagnostics
fi
