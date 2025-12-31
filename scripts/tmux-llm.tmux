#!/usr/bin/env bash

# tmux-llm plugin configuration
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default configuration
default_key_binding="C-g"
default_api_endpoint="https://api.openai.com/v1/chat/completions"
default_model="gpt-5-mini"
default_popup_width="70%"
default_popup_height="70%"

# Get tmux option with default
tmux_get_option() {
    local option="$1"
    local default_value="$2"
    local option_value
    option_value=$(tmux show-option -gqv "$option")
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

# Set up the plugin
main() {
    local key_binding
    local api_endpoint
    local model
    local api_key
    local popup_width
    local popup_height
    
    # Get configuration options
    key_binding=$(tmux_get_option "@tmux-llm-key" "$default_key_binding")
    api_endpoint=$(tmux_get_option "@tmux-llm-api-endpoint" "$default_api_endpoint")
    model=$(tmux_get_option "@tmux-llm-model" "$default_model")
    api_key=$(tmux_get_option "@tmux-llm-api-key" "")
    popup_width=$(tmux_get_option "@tmux-llm-popup-width" "$default_popup_width")
    popup_height=$(tmux_get_option "@tmux-llm-popup-height" "$default_popup_height")
    
    # Export environment variables for the Python script
    tmux set-environment -g TMUX_LLM_API_ENDPOINT "$api_endpoint"
    tmux set-environment -g TMUX_LLM_MODEL "$model"
    tmux set-environment -g TMUX_LLM_API_KEY "$api_key"
    tmux set-environment -g TMUX_LLM_POPUP_WIDTH "$popup_width"
    tmux set-environment -g TMUX_LLM_POPUP_HEIGHT "$popup_height"
    
    # Bind the key to the shell script
    tmux bind-key -n "$key_binding" run-shell "bash $CURRENT_DIR/tmux-llm.sh"
}

main
