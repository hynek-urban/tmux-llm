#!/usr/bin/env bash

# tmux-llm plugin configuration
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default configuration
default_key_binding="C-g"
default_api_endpoint="https://api.openai.com/v1/chat/completions"
default_model="gpt-4o-mini"

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
    
    # Get configuration options
    key_binding=$(tmux_get_option "@tmux-llm-key" "$default_key_binding")
    api_endpoint=$(tmux_get_option "@tmux-llm-api-endpoint" "$default_api_endpoint")
    model=$(tmux_get_option "@tmux-llm-model" "$default_model")
    api_key=$(tmux_get_option "@tmux-llm-api-key" "")
    
    # Export environment variables for the Python script
    tmux set-environment -g TMUX_LLM_API_ENDPOINT "$api_endpoint"
    tmux set-environment -g TMUX_LLM_MODEL "$model"
    tmux set-environment -g TMUX_LLM_API_KEY "$api_key"
    
    # Bind the key to the shell script
    tmux bind-key -n "$key_binding" run-shell "bash $CURRENT_DIR/scripts/tmux-llm.sh"
}

main
