#!/bin/bash
# tmux status bar script for Copilot Terminal
# Shows: GitHub auth status | HA connection | time

STATUS_PARTS=()

# Check GitHub auth status
check_github_auth() {
    if [ -f "${HOME}/.copilot/config.json" ] 2>/dev/null || \
       [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
        echo "#[fg=#3fb950]●#[fg=colour245] GitHub"
    else
        echo "#[fg=#ff7b72]○#[fg=colour245] GitHub"
    fi
}

# Check HA connectivity
check_ha_status() {
    if [ -n "${SUPERVISOR_TOKEN:-}" ]; then
        local result
        result=$(curl -s -o /dev/null -w "%{http_code}" -m 3 \
            -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
            http://supervisor/core/api/config 2>/dev/null)
        if [ "$result" = "200" ]; then
            echo "#[fg=#3fb950]●#[fg=colour245] HA"
        else
            echo "#[fg=#d29922]○#[fg=colour245] HA"
        fi
    else
        echo "#[fg=colour240]- HA"
    fi
}

# Build status line
auth_status=$(check_github_auth)
ha_status=$(check_ha_status)
time_str="#[fg=colour245]%H:%M"

echo "${auth_status} ${ha_status} ${time_str}"
