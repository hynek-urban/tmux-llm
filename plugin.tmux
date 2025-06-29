#!/usr/bin/env bash

# Main plugin file - this is the entry point for tmux plugin manager
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source the main plugin configuration
source "$CURRENT_DIR/tmux-llm.tmux"