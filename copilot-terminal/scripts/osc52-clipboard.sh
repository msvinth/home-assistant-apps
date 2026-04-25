#!/bin/bash
# OSC 52 clipboard wrapper — drop-in replacement for xclip/xsel in headless environments
# Sends clipboard data to the browser via OSC 52 escape sequences through ttyd/tmux.
#
# Supports common xclip/xsel invocation patterns:
#   echo "text" | xclip -selection clipboard    (copy to clipboard)
#   xclip -selection clipboard -o               (paste — not supported, exits silently)
#   echo "text" | xsel --clipboard --input      (copy)
#   xsel --clipboard --output                   (paste — not supported)

MODE="copy"

# Parse arguments to detect copy vs paste mode
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output|-O)
            MODE="paste"
            shift
            ;;
        -selection|-sel|--clipboard|--primary|-i|--input|-b|-p)
            shift
            # Consume the selection name argument if present (e.g., "clipboard")
            if [[ $# -gt 0 && "$1" != -* ]]; then
                shift
            fi
            ;;
        *)
            shift
            ;;
    esac
done

if [ "$MODE" = "paste" ]; then
    # OSC 52 paste is not reliably supported — exit silently
    exit 0
fi

# Read stdin
text="$(cat)"

if [ -z "$text" ]; then
    exit 0
fi

# Base64 encode
encoded="$(printf '%s' "$text" | base64 | tr -d '\n')"

# Determine the correct escape sequence based on whether we're inside tmux
if [ -n "$TMUX" ]; then
    # Wrap OSC 52 in tmux passthrough: DCS tmux; <escaped-osc52> ST
    printf '\ePtmux;\e\e]52;c;%s\a\e\\' "$encoded"
else
    # Direct OSC 52
    printf '\e]52;c;%s\a' "$encoded"
fi
