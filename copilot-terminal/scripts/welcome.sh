#!/bin/bash

# Welcome banner and What's New display for Copilot Terminal
# Runs inside ttyd terminal (user-visible), not in run.sh boot logs
# Uses plain bash — no bashio dependency

# Colors - GitHub palette
BLUE='\033[38;2;88;166;255m'
GREEN='\033[38;2;63;185;80m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

MOTD_VERSION_FILE="/data/.motd-version"
ADDON_VERSION_FILE="/opt/scripts/addon-version"

get_current_version() {
    if [ -f "$ADDON_VERSION_FILE" ]; then
        cat "$ADDON_VERSION_FILE"
    else
        echo "unknown"
    fi
}

get_last_seen_version() {
    cat "$MOTD_VERSION_FILE" 2>/dev/null || echo "none"
}

save_version() {
    echo "$1" > "$MOTD_VERSION_FILE" 2>/dev/null
}

show_welcome_banner() {
    local version="$1"
    local ver_padding
    # Box interior is 58 chars; fixed prefix "   Copilot Terminal  v" is 22 chars
    ver_padding=$(printf '%*s' $((36 - ${#version})) '')
    echo ""
    echo -e "  ${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BLUE}║${NC}                                                          ${BLUE}║${NC}"
    echo -e "  ${BLUE}║${NC}   ${WHITE}Copilot Terminal${NC}  ${DIM}v${version}${NC}${ver_padding}${BLUE}║${NC}"
    echo -e "  ${BLUE}║${NC}   ${DIM}Home Assistant App  ·  Powered by GitHub Copilot CLI${NC}   ${BLUE}║${NC}"
    echo -e "  ${BLUE}║${NC}                                                          ${BLUE}║${NC}"
    echo -e "  ${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
}

CHANGELOG_FILE="/opt/scripts/CHANGELOG.md"

# Parse CHANGELOG.md and display entries newer than last_seen.
show_whats_new() {
    local version="$1"
    local last_seen="$2"

    if [ "$version" = "$last_seen" ] || [ "$version" = "unknown" ]; then
        return
    fi

    if [ ! -f "$CHANGELOG_FILE" ]; then
        echo ""
        echo -e "  ${DIM}Upgraded to v${version}. See CHANGELOG for details.${NC}"
        echo ""
        save_version "$version"
        return
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}What's New${NC}"

    local shown=false
    local count=0
    local max_versions=5

    local current_ver=""
    local in_section=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^##\ +([0-9]+\.[0-9]+\.[0-9]+) ]]; then
            current_ver="${BASH_REMATCH[1]}"
            in_section=false

            if version_newer_than "$current_ver" "$last_seen"; then
                if [ $count -ge $max_versions ]; then
                    echo ""
                    echo -e "  ${DIM}...and more. See CHANGELOG for full history.${NC}"
                    break
                fi
                in_section=true
                echo ""
                echo -e "  ${WHITE}${BOLD}v${current_ver}${NC}"
                shown=true
                count=$((count + 1))
            fi
            continue
        fi

        $in_section || continue

        if [[ "$line" =~ ^-\ \*\*([^*]+)\*\*:?\ *(.*) ]]; then
            local feature="${BASH_REMATCH[1]}"
            local desc="${BASH_REMATCH[2]}"
            feature="${feature%:}"
            desc="${desc#"${desc%%[![:space:]]*}"}"
            if [ -n "$desc" ]; then
                echo -e "  ${BLUE}*${NC} ${BOLD}${feature}${NC} — ${desc}"
            else
                echo -e "  ${BLUE}*${NC} ${BOLD}${feature}${NC}"
            fi
        fi
    done < "$CHANGELOG_FILE"

    if [ "$shown" = false ]; then
        echo ""
        echo -e "  ${DIM}Upgraded to v${version}. See CHANGELOG for details.${NC}"
    fi

    echo ""

    save_version "$version"
}

# Compare versions: returns 0 (true) if $1 is newer than $2
version_newer_than() {
    local target="$1"
    local baseline="$2"

    if [ "$baseline" = "none" ] || [ -z "$baseline" ]; then
        return 0
    fi

    local t_major t_minor t_patch b_major b_minor b_patch
    IFS='.' read -r t_major t_minor t_patch <<< "$target"
    IFS='.' read -r b_major b_minor b_patch <<< "$baseline"

    t_patch="${t_patch:-0}"
    b_patch="${b_patch:-0}"

    if [ "$t_major" -gt "$b_major" ] 2>/dev/null; then return 0; fi
    if [ "$t_major" -lt "$b_major" ] 2>/dev/null; then return 1; fi
    if [ "$t_minor" -gt "$b_minor" ] 2>/dev/null; then return 0; fi
    if [ "$t_minor" -lt "$b_minor" ] 2>/dev/null; then return 1; fi
    if [ "$t_patch" -gt "$b_patch" ] 2>/dev/null; then return 0; fi
    return 1
}

main() {
    local current_version
    current_version=$(get_current_version)
    local last_seen
    last_seen=$(get_last_seen_version)

    show_welcome_banner "$current_version"
    show_whats_new "$current_version" "$last_seen"

    echo ""
    printf "  Press Enter to continue (auto-continuing in 15s)..."
    read -t 15 -r || true
}

main "$@"
