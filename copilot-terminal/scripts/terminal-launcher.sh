#!/bin/bash

# Terminal launcher for ttyd - manages welcome screen and tmux sessions
# Handles reconnection gracefully by skipping welcome on existing sessions.
# If Copilot was killed while the user was away, it auto-restarts on reconnect.

SESSION_NAME="copilot"

# If a tmux session already exists, handle reconnection.
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    client_count=$(tmux list-clients -t "$SESSION_NAME" 2>/dev/null | wc -l | tr -d ' ')
    pane_cmd=$(tmux display-message -t "$SESSION_NAME" -p '#{pane_current_command}')

    if [ "$client_count" -eq 0 ] && [ "$pane_cmd" = "bash" ]; then
        # User is reconnecting after being away, and Copilot isn't running.
        tmux send-keys -t "$SESSION_NAME" "copilot" Enter
    fi

    exec tmux attach-session -t "$SESSION_NAME"
fi

# First launch - show welcome if available
if command -v welcome >/dev/null 2>&1; then
    welcome
fi

# Verify copilot binary works before launching tmux session
if ! copilot --version >/dev/null 2>&1; then
    echo ""
    echo -e "\033[1;31m⚠  Copilot CLI failed to start.\033[0m"
    echo ""
    echo "Diagnostics:"
    copilot --version 2>&1 || true
    echo ""
    echo "This is likely a glibc compatibility issue on Alpine Linux."
    echo "The native binary requires glibc but Alpine uses musl."
    echo ""
    echo "You can still use this shell. Try running 'copilot' to see the error."
    echo ""
    exec bash
fi

# Start new tmux session running copilot.
# If copilot exits, fall back to bash so the session stays alive.
exec tmux new-session -s "$SESSION_NAME" 'copilot; echo ""; echo "Copilot exited. You are now in a bash shell."; echo "Run '\''copilot'\'' to restart, or '\''exit'\'' to close."; exec bash'
