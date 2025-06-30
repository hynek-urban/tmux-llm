#!/usr/bin/env bash

# tmux-llm shell wrapper script
# This script extracts selected text from tmux and sends it to the Python script

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$CURRENT_DIR")"
PYTHON_SCRIPT="$PARENT_DIR/tmux-llm.py"

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

# Function to display error in popup
show_error() {
    local error_msg="$1"
    # Create a temporary script to avoid shell escaping issues
    local temp_error_script
    temp_error_script=$(mktemp)
    cat > "$temp_error_script" << EOF
#!/bin/bash
printf '%s\n' $(printf %q "$error_msg")
echo
echo 'Press any key to close...'
read -n 1
EOF
    chmod +x "$temp_error_script"
    tmux display-popup -w 80 -h 10 -E "bash '$temp_error_script'; rm -f '$temp_error_script'"
}

# Main function
main() {
    # Check if Python script exists
    if [ ! -f "$PYTHON_SCRIPT" ]; then
        show_error "Error: tmux-llm.py script not found at $PYTHON_SCRIPT"
        exit 1
    fi
    
    # Get selected text
    local input_text
    input_text=$(get_selected_text)
    
    if [ -z "$input_text" ]; then
        show_error "Error: No text selected or captured from pane"
        exit 1
    fi
    
    # Check if API key is configured
    local api_key
    api_key=$(tmux show-environment -g TMUX_LLM_API_KEY 2>/dev/null | cut -d= -f2-)
    
    if [ -z "$api_key" ]; then
        show_error "Error: TMUX_LLM_API_KEY not configured. Set with: tmux set-option -g @tmux-llm-api-key 'your-api-key'"
        exit 1
    fi
    
    # Create a temporary script to run in the popup
    local temp_script
    temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
echo "🤖 Processing your request..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
EOF
    
    # Create a temporary file for the input text to avoid shell escaping issues
    local temp_input
    temp_input=$(mktemp)
    printf '%s' "$input_text" > "$temp_input"
    
    # Add the command to pipe input from temp file to Python script
    echo "python3 \"$PYTHON_SCRIPT\" < \"$temp_input\"" >> "$temp_script"
    
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
    tmux display-popup -w 90% -h 70% -E "bash '$temp_script'; rm -f '$temp_script'"
}

main "$@"