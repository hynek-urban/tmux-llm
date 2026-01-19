#!/usr/bin/env bash

# tmux-llm plugin configuration
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default configuration
default_key_binding="C-g"
default_api_endpoint="https://api.openai.com/v1/chat/completions"
default_model="gpt-4.1-mini"
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

# Get config value with env var precedence
get_config_value() {
    local env_var="$1" tmux_opt="$2" default="$3"
    if [ -z "$env_var" ]; then
        tmux_get_option "$tmux_opt" "$default"
        return
    fi
    if [ -n "${!env_var:-}" ]; then
        echo "${!env_var}"
    else
        tmux_get_option "$tmux_opt" "$default"
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
    
    # Get configuration options (env var > tmux option > default)
    key_binding=$(get_config_value "" "@tmux-llm-key" "$default_key_binding")
    api_endpoint=$(get_config_value "TMUX_LLM_API_ENDPOINT" "@tmux-llm-api-endpoint" "$default_api_endpoint")
    model=$(get_config_value "TMUX_LLM_MODEL" "@tmux-llm-model" "$default_model")
    api_key=$(get_config_value "TMUX_LLM_API_KEY" "@tmux-llm-api-key" "")
    popup_width=$(get_config_value "TMUX_LLM_POPUP_WIDTH" "@tmux-llm-popup-width" "$default_popup_width")
    popup_height=$(get_config_value "TMUX_LLM_POPUP_HEIGHT" "@tmux-llm-popup-height" "$default_popup_height")
    
    # Export environment variables for the Python script
    tmux set-environment -g TMUX_LLM_API_ENDPOINT "$api_endpoint"
    tmux set-environment -g TMUX_LLM_MODEL "$model"
    tmux set-environment -g TMUX_LLM_API_KEY "$api_key"
    tmux set-environment -g TMUX_LLM_POPUP_WIDTH "$popup_width"
    tmux set-environment -g TMUX_LLM_POPUP_HEIGHT "$popup_height"
    
    # Bind the key to the shell script
    tmux bind-key -n "$key_binding" run-shell "bash $CURRENT_DIR/tmux-llm.sh"
    tmux bind-key -T copy-mode "$key_binding" send -X copy-pipe-and-cancel "bash $CURRENT_DIR/tmux-llm.sh"
    tmux bind-key -T copy-mode-vi "$key_binding" send -X copy-pipe-and-cancel "bash $CURRENT_DIR/tmux-llm.sh"
}

main
