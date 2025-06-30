#!/usr/bin/env bash

# tmux-llm shell wrapper script
# This script extracts selected text from tmux and sends it to the Python script

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$CURRENT_DIR")"
PYTHON_SCRIPT="$PARENT_DIR/tmux-llm.py"

# Get popup dimensions from environment variables (set by tmux-llm.tmux)
POPUP_WIDTH="${TMUX_LLM_POPUP_WIDTH:-90%}"
POPUP_HEIGHT="${TMUX_LLM_POPUP_HEIGHT:-70%}"

# Function to get selected text from tmux
get_selected_text() {
    # Try to get selected text from copy buffer
    local selected_text
    selected_text=$(tmux show-buffer 2>/dev/null || echo "")
    
    # If no selection, get the current pane content (last 50 lines)
    if [ -z "$selected_text" ]; then
        selected_text=$(tmux capture-pane -p -S -50)
    fi
    
    echo "$selected_text"
}


# Main function
main() {
    # Check if Python script exists
    if [ ! -f "$PYTHON_SCRIPT" ]; then
        tmux display-popup -w 80 -h 10 -E "echo 'Error: tmux-llm.py script not found at $PYTHON_SCRIPT'; echo; echo 'Press any key to close...'; read -n 1"
        exit 1
    fi
    
    # Get selected text
    local input_text
    input_text=$(get_selected_text)
    
    if [ -z "$input_text" ]; then
        tmux display-popup -w 80 -h 10 -E "echo 'Error: No text selected or captured from pane'; echo; echo 'Press any key to close...'; read -n 1"
        exit 1
    fi
    
    
    # Create a temporary script to run in the popup
    local temp_script
    temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
echo -n "Waiting..."
EOF
    
    # Create a temporary file for the input text to avoid shell escaping issues
    local temp_input
    temp_input=$(mktemp)
    printf '%s' "$input_text" > "$temp_input"
    
    # Add the command to pipe input from temp file to Python script with text wrapping
    echo "export COLUMNS=\$(tput cols)" >> "$temp_script"
    echo "export TMUX_LLM_POPUP_WIDTH=\"$POPUP_WIDTH\"" >> "$temp_script"
    echo "python3 \"$PYTHON_SCRIPT\" < \"$temp_input\" | { read -r first_line; echo -e '\\r\\033[K'; echo \"\$first_line\"; cat; }" >> "$temp_script"
    
    # Add cleanup and footer
    cat >> "$temp_script" << EOF
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Press any key to close..."
read -n 1
rm -f "$temp_input"
EOF
    
    chmod +x "$temp_script"
    
    # Run in popup - no need for complex escaping since we're using temp files
    tmux display-popup -w "$POPUP_WIDTH" -h "$POPUP_HEIGHT" -E "bash '$temp_script'; rm -f '$temp_script'"
}

main "$@"
