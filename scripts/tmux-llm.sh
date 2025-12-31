#!/usr/bin/env bash

# tmux-llm shell wrapper script
# This script extracts displayed or selected text from tmux and sends it to the Python script.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PYTHON_SCRIPT="$CURRENT_DIR/tmux-llm.py"

# Get popup dimensions from environment variables (set by tmux-llm.tmux)
POPUP_WIDTH="${TMUX_LLM_POPUP_WIDTH:-70%}"
POPUP_HEIGHT="${TMUX_LLM_POPUP_HEIGHT:-70%}"


# Main function
main() {
    # Check if Python script exists
    if [ ! -f "$PYTHON_SCRIPT" ]; then
        tmux display-popup -w 80 -h 10 -E "echo 'Error: tmux-llm.py script not found at $PYTHON_SCRIPT'; echo; echo 'Press any key to close...'; read -n 1"
        exit 1
    fi

    # Get the input_text: either from the stdin (when selected) or the whole pane.
    local input_text
    input_text=$(cat)
    if [ -z "$input_text" ]; then
      input_text=$(tmux capture-pane -p)
    fi

    if [ -z "$input_text" ]; then
        tmux display-popup -w 80 -h 10 -E "echo 'Error: No text selected or captured from pane'; echo; echo 'Press any key to close...'; read -n 1"
        exit 1
    fi
    
    
    # Create a temporary script to run in the popup
    local temp_script
    temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
echo -n " Waiting..."
EOF
    
    # Create a temporary file for the input text to avoid shell escaping issues
    local temp_input
    temp_input=$(mktemp)
    printf '%s' "$input_text" > "$temp_input"
    
    # Add the command to pipe input from temp file to Python script with text wrapping
    echo "export COLUMNS=\$(tput cols)" >> "$temp_script"
    # Pipe to less to get scrolling.
    echo "
    set -e
    temp_output=\$(mktemp)
    python3 \"$PYTHON_SCRIPT\" < \"$temp_input\" | { read -n 1 -r first_line; echo -e '\\r\\033[K'; { echo -n \"\$first_line\"; cat; } | tee \"\$temp_output\"; }
    LESS=\"-P press 'q' to close\" less -R +1 \"\$temp_output\"
    rm -f \"\$temp_output\"
    " >> "$temp_script"
    
    # Add cleanup
    cat >> "$temp_script" << EOF
rm -f "$temp_input"
EOF
    
    chmod +x "$temp_script"
    
    # Run in popup - no need for complex escaping since we're using temp files
    tmux display-popup -w "$POPUP_WIDTH" -h "$POPUP_HEIGHT" -E "bash '$temp_script'; rm -f '$temp_script'"
}

main "$@"
