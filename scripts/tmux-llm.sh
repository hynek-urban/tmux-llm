#!/usr/bin/env bash

# tmux-llm shell wrapper script
# This script extracts displayed or selected text from tmux and sends it to the Python script.

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PYTHON_SCRIPT="$CURRENT_DIR/tmux-llm.py"

# Get popup dimensions from environment variables (set by tmux-llm.tmux)
POPUP_WIDTH="${TMUX_LLM_POPUP_WIDTH:-70%}"
POPUP_HEIGHT="${TMUX_LLM_POPUP_HEIGHT:-70%}"

clamp_dimension() {
    local size="$1"
    local total_format="$2"
    local target_pane="$3"
    local total

    total=$(tmux display-message -p -t "$target_pane" "$total_format")
    if [[ "$size" =~ ^([0-9]+)%$ ]]; then
        local percentage=$((10#${BASH_REMATCH[1]}))
        (( percentage > 100 )) && percentage=100
        printf '%s%%' "$percentage"
    elif [[ "$size" =~ ^[0-9]+$ ]]; then
        local numeric_size=$((10#$size))
        (( numeric_size > total )) && numeric_size=$total
        printf '%s' "$numeric_size"
    else
        printf '%s' "$size"
    fi
}

center_position() {
    local size="$1"
    local total_format="$2"
    local target_pane="$3"

    if [[ "$size" =~ ^([0-9]+)%$ ]]; then
        local percentage=$((10#${BASH_REMATCH[1]}))
        (( percentage > 100 )) && percentage=100
        printf '%s%%' "$(( (100 - percentage) / 2 ))"
    elif [[ "$size" =~ ^[0-9]+$ ]]; then
        local total
        local numeric_size=$((10#$size))
        local position
        total=$(tmux display-message -p -t "$target_pane" "$total_format")
        position=$(( (total - numeric_size) / 2 ))
        (( position < 0 )) && position=0
        printf '%s' "$position"
    else
        printf '0'
    fi
}

supports_modal_panes() {
    tmux list-commands | grep -Eq '^new-pane( \([^)]*\))? \[[^]]*O[^]]*\]'
}

# Main function
main() {
    # Check if Python script exists
    if [ ! -f "$PYTHON_SCRIPT" ]; then
        tmux display-popup -w 80 -h 10 -E "echo 'Error: tmux-llm.py script not found at $PYTHON_SCRIPT'; echo; echo 'Press any key to close...'; read -n 1"
        exit 1
    fi

    local target_pane="${1:-}"
    if [ -z "$target_pane" ]; then
        target_pane=$(tmux display-message -p '#{pane_id}')
    fi

    # Get the input_text: either from the stdin (when selected) or the whole pane.
    local input_text
    input_text=$(cat)
    if [ -z "$input_text" ]; then
      input_text=$(tmux capture-pane -p -t "$target_pane")
    fi

    if [ -z "$input_text" ]; then
        tmux display-popup -w 80 -h 10 -E "echo 'Error: No text selected or captured from pane'; echo; echo 'Press any key to close...'; read -n 1"
        exit 1
    fi

    # Use a popup if this window already has a modal pane.
    local use_modal_pane=0
    if supports_modal_panes &&
        [ -z "$(tmux display-message -p -t "$target_pane" '#{window_modal_pane}')" ]; then
        use_modal_pane=1
    fi
    
    
    # Build the response viewer.
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
    echo "
    temp_output=\$(mktemp)
    temp_output_stderr=\$(mktemp)
    # Show output as it streams.
    python3 \"$PYTHON_SCRIPT\" < \"$temp_input\" 2>\$temp_output_stderr | { read -n 1 -r first_line; echo -e '\\r\\033[K'; { echo -n \"\$first_line\"; cat; } | tee \"\$temp_output\"; }
    # Open the result in less.
    if [ -s \"\$temp_output_stderr\" ]; then
      LESS=\"-P press 'q' to close\" less \"\$temp_output_stderr\"
    else
      LESS=\"-P press 'q' to close\" less -R +1 \"\$temp_output\"
    fi
    rm -f \"\$temp_output\"
    rm -f \"\$temp_output_stderr\"
    " >> "$temp_script"
    
    # Add cleanup
    cat >> "$temp_script" << EOF
rm -f "$temp_input"
EOF
    
    chmod +x "$temp_script"
    
    # Use a real pane for copy mode, with a popup fallback.
    if [ "$use_modal_pane" -eq 1 ]; then
        local popup_x
        local popup_y
        local popup_style
        local popup_border_style
        local pane_border_lines
        local modal_width
        local modal_height
        modal_width=$(clamp_dimension "$POPUP_WIDTH" '#{window_width}' "$target_pane")
        modal_height=$(clamp_dimension "$POPUP_HEIGHT" '#{window_height}' "$target_pane")
        popup_x=$(center_position "$modal_width" '#{window_width}' "$target_pane")
        popup_y=$(center_position "$modal_height" '#{window_height}' "$target_pane")
        popup_style=$(tmux show-option -wAqv -t "$target_pane" popup-style)
        popup_border_style=$(tmux show-option -wAqv -t "$target_pane" popup-border-style)
        # Pane borders do not support popup-only styles such as rounded.
        pane_border_lines=$(tmux show-option -wAqv -t "$target_pane" pane-border-lines)

        if ! tmux new-pane -O -t "$target_pane" \
            -x "$modal_width" -y "$modal_height" \
            -X "$popup_x" -Y "$popup_y" \
            -B "$pane_border_lines" \
            -s "$popup_style" -S "$popup_border_style" \
            "tmux set-option -p -t \"\$TMUX_PANE\" remain-on-exit off; bash '$temp_script'; rm -f '$temp_script'"; then
            rm -f "$temp_script" "$temp_input"
            return 1
        fi
    elif ! tmux display-popup -t "$target_pane" -w "$POPUP_WIDTH" -h "$POPUP_HEIGHT" -E "bash '$temp_script'; rm -f '$temp_script'"; then
        rm -f "$temp_script" "$temp_input"
        return 1
    fi
}

main "$@"
