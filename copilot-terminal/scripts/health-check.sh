#!/usr/bin/with-contenv bashio

# Health check script for Copilot Terminal app
# Validates environment and provides diagnostic information

check_system_resources() {
    bashio::log.info "=== System Resources Check ==="

    local mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    local mem_free=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
    local swap_total=$(awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo)
    local swap_free=$(awk '/SwapFree/ {print int($2/1024)}' /proc/meminfo)
    bashio::log.info "Memory: ${mem_free}MB free of ${mem_total}MB total"
    bashio::log.info "Swap: ${swap_free}MB free of ${swap_total}MB total"

    if [ "$mem_free" -lt 400 ]; then
        bashio::log.warning "⚠ Low memory: ${mem_free}MB available"
        bashio::log.warning "Copilot CLI needs ~400-500MB to process requests"
        bashio::log.warning "Consider stopping other add-ons to free memory"
    fi

    local disk_free=$(df -m /data | tail -1 | awk '{print $4}')
    bashio::log.info "Disk space in /data: ${disk_free}MB free"
}

check_directory_permissions() {
    bashio::log.info "=== Directory Permissions Check ==="

    if [ -w "/data" ]; then
        bashio::log.info "/data directory: Writable ✓"
    else
        bashio::log.error "/data directory: Not writable ✗"
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

    if [ -x "$(which copilot)" ]; then
        bashio::log.info "Copilot CLI is executable ✓"
    else
        bashio::log.error "Copilot CLI is not executable ✗"
        return 1
    fi

    local version_output
    if version_output=$(copilot --version 2>&1); then
        bashio::log.info "Copilot CLI version: ${version_output} ✓"
    else
        bashio::log.error "Copilot CLI binary failed to run ✗"
        bashio::log.error "Output: ${version_output}"
        return 1
    fi
}

check_network_connectivity() {
    bashio::log.info "=== Network Connectivity Check ==="

    if curl -s --head --connect-timeout 5 --max-time 10 https://api.github.com > /dev/null; then
        bashio::log.info "Can reach GitHub API ✓"
    else
        bashio::log.warning "Cannot reach GitHub API — Copilot CLI requires GitHub connectivity"
    fi
}

run_diagnostics() {
    bashio::log.info "========================================="
    bashio::log.info "Copilot Terminal App Health Check"
    bashio::log.info "========================================="

    local errors=0

    check_system_resources || ((errors++))
    check_directory_permissions || ((errors++))
    check_copilot_cli || ((errors++))
    check_network_connectivity || ((errors++))

    bashio::log.info "========================================="

    if [ "$errors" -eq 0 ]; then
        bashio::log.info "✅ All checks passed!"
    else
        bashio::log.error "❌ $errors check(s) failed"
    fi

    return $errors
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_diagnostics
fi
