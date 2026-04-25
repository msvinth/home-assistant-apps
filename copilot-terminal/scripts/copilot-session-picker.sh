#!/bin/bash

# Copilot Session Picker - Interactive menu for choosing Copilot session type
# Provides options for new session, continue, resume, custom command, or regular shell
# With tmux session persistence for reconnection on navigation

TMUX_SESSION_NAME="copilot"

# Colors - GitHub palette
BLUE='\033[38;2;88;166;255m'
WHITE='\033[1;37m'
DIM='\033[2m'
NC='\033[0m'

show_banner() {
    clear
    echo ""
    echo -e "  ${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BLUE}║${NC}                                                              ${BLUE}║${NC}"
    echo -e "  ${BLUE}║${NC}   ${WHITE}Copilot Terminal${NC}  ${DIM}·  Session Picker${NC}                        ${BLUE}║${NC}"
    echo -e "  ${BLUE}║${NC}                                                              ${BLUE}║${NC}"
    echo -e "  ${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_existing_session() {
    tmux has-session -t "$TMUX_SESSION_NAME" 2>/dev/null
}

show_menu() {
    echo "Choose your Copilot session type:"
    echo ""

    if check_existing_session; then
        echo "  0) 🔄 Reconnect to existing session (recommended)"
        echo ""
    fi

    echo "  1) 🆕 New interactive session (default)"
    echo "  2) ⏩ Continue most recent conversation (--continue)"
    echo "  3) 📋 Resume from conversation list (--resume)"
    echo "  4) ⚙️  Custom Copilot command (manual flags)"
    echo "  5) 🐚 Drop to bash shell"
    echo "  6) ❌ Exit"
    echo ""
}

get_user_choice() {
    local choice
    local default="1"

    if check_existing_session; then
        default="0"
    fi

    printf "Enter your choice [0-6] (default: %s): " "$default" >&2
    read -r choice

    if [ -z "$choice" ]; then
        choice="$default"
    fi

    choice=$(echo "$choice" | tr -d '[:space:]')
    echo "$choice"
}

attach_existing_session() {
    echo "🔄 Reconnecting to existing Copilot session..."
    sleep 1
    exec tmux attach-session -t "$TMUX_SESSION_NAME"
}

launch_copilot_new() {
    echo "🚀 Starting new Copilot session..."

    if check_existing_session; then
        echo "   (closing previous session)"
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" 'copilot'
}

launch_copilot_continue() {
    echo "⏩ Continuing most recent conversation..."

    if check_existing_session; then
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" 'copilot --continue'
}

launch_copilot_resume() {
    echo "📋 Opening conversation list for selection..."

    if check_existing_session; then
        tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
    fi

    sleep 1
    exec tmux new-session -s "$TMUX_SESSION_NAME" 'copilot --resume'
}

launch_copilot_custom() {
    echo ""
    echo "Enter your Copilot command (e.g., 'copilot --help' or 'copilot -p \"hello\"'):"
    echo "Available flags: --continue, --resume, -p (print), --model, etc."
    echo -n "> copilot "
    read -r custom_args

    if [ -z "$custom_args" ]; then
        echo "No arguments provided. Starting default session..."
        launch_copilot_new
    else
        echo "🚀 Running: copilot $custom_args"

        if check_existing_session; then
            tmux kill-session -t "$TMUX_SESSION_NAME" 2>/dev/null
        fi

        sleep 1
        exec tmux new-session -s "$TMUX_SESSION_NAME" "copilot $custom_args"
    fi
}

launch_bash_shell() {
    echo "🐚 Dropping to bash shell..."
    echo "Tip: Run 'tmux new-session -A -s copilot \"copilot\"' to start with persistence"
    sleep 1
    exec bash
}

exit_session_picker() {
    echo "👋 Goodbye!"
    exit 0
}

main() {
    while true; do
        show_banner
        show_menu
        choice=$(get_user_choice)

        case "$choice" in
            0)
                if check_existing_session; then
                    attach_existing_session
                else
                    echo "❌ No existing session found"
                    sleep 1
                fi
                ;;
            1)
                launch_copilot_new
                ;;
            2)
                launch_copilot_continue
                ;;
            3)
                launch_copilot_resume
                ;;
            4)
                launch_copilot_custom
                ;;
            5)
                launch_bash_shell
                ;;
            6)
                exit_session_picker
                ;;
            *)
                echo ""
                echo "❌ Invalid choice: '$choice'"
                echo "Please select a number between 0-6"
                echo ""
                printf "Press Enter to continue..." >&2
                read -r
                ;;
        esac
    done
}

# Handle cleanup on exit
trap 'echo ""; exit 0' EXIT INT TERM

# If an existing tmux session is running, reattach immediately.
if check_existing_session; then
    exec tmux attach-session -t "$TMUX_SESSION_NAME"
fi

main "$@"
