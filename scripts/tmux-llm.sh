#!/usr/bin/env bash

# tmux-llm shell wrapper script
# This script extracts selected text from tmux and sends it to the Python script

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PYTHON_SCRIPT="$CURRENT_DIR/tmux-llm.py"

# Get popup dimensions from environment variables (set by tmux-llm.tmux)
POPUP_WIDTH="${TMUX_LLM_POPUP_WIDTH:-70%}"
POPUP_HEIGHT="${TMUX_LLM_POPUP_HEIGHT:-70%}"

# Function to get selected text from tmux
get_selected_text() {
    # Check if there's currently selected text in copy mode
    local selection_present
    selection_present=$(tmux display-message -p "#{selection_present}" 2>/dev/null || echo "0")
    
    local selected_text=""
    
    # If there's an active selection, capture the currently selected text directly  
    if [ "$selection_present" = "1" ]; then
        # Get the selection coordinates
        local sel_start_y sel_end_y
        sel_start_y=$(tmux display-message -p "#{selection_start_y}" 2>/dev/null || echo "0")
        sel_end_y=$(tmux display-message -p "#{selection_end_y}" 2>/dev/null || echo "0")
        
        # Capture the selected lines
        selected_text=$(tmux capture-pane -p -S "$sel_start_y" -E "$sel_end_y" 2>/dev/null || echo "")
    fi
    
    # If no active selection or buffer is empty, get the current pane content (last 50 lines)
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
    temp_output=\$(mktemp)
    python3 \"$PYTHON_SCRIPT\" < \"$temp_input\" | { read -n 1 -r first_line; echo -e '\\r\\033[K'; { echo -n \"\$first_line\"; cat; } | tee \"\$temp_output\"; }
    clear
    echo
    less -R \"\$temp_output\"
    rm -f \"\$temp_output\"
    " >> "$temp_script"
    # echo "python3 \"$PYTHON_SCRIPT\" < \"$temp_input\" | less" >> "$temp_script"
    
    # Add cleanup
    cat >> "$temp_script" << EOF
rm -f "$temp_input"
EOF
    
    chmod +x "$temp_script"
    
    # Run in popup - no need for complex escaping since we're using temp files
    tmux display-popup -w "$POPUP_WIDTH" -h "$POPUP_HEIGHT" -E "bash '$temp_script'; rm -f '$temp_script'"
}

main "$@"
