# tmux-llm

A minimalist tmux plugin to get quick reactions from an LLM assistant to the terminal window contents.

Works with any openai-compatible API.

Created with the help of [Sculptor](https://imbue.com/product/sculptor/).


## Usage

1. (Optionally) Select text in a tmux pane (copy mode).
2. Press `Ctrl+G` (or your configured key binding).
3. The LLM response will appear in a popup window.
4. Press any key to close the popup window.


## Installation

### Using TPM (Tmux Plugin Manager)

Add these lines to your `~/.tmux.conf` (ensure you replace the API key with your actual API key):

```bash
set -g @tmux-llm-api-key '<your-api-key>'
set -g @plugin 'hynek-urban/tmux-llm'
```

Then press `prefix + I` to install.

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/hynek-urban/tmux-llm ~/.tmux/plugins/tmux-llm
   ```

2. Add these lines to your `~/.tmux.conf`:
   ```bash
   set -g @tmux-llm-api-key '<your-api-key>'
   run-shell 'bash ~/.tmux/plugins/tmux-llm/plugin.tmux'
   ```
   
   (Ensure you replace the API key with your actual API key.)

3. Reload your tmux config:
   ```bash
   tmux source-file ~/.tmux.conf
   ```


## Configuration

You may customize the following options in `~/.tmux.conf`:

```bash

# Customize key binding (default: Ctrl+G)
set -g @tmux-llm-key 'C-g'

# Set API endpoint (default: OpenAI)
set -g @tmux-llm-api-endpoint 'https://api.openai.com/v1/chat/completions'

# Set model (default: gpt-4o-mini)
set -g @tmux-llm-model 'gpt-4o'

# Customize popup dimensions (defaults: 90% width, 70% height)
set -g @tmux-llm-popup-width '80%'
set -g @tmux-llm-popup-height '60%'
```

## What gets actually sent to the LLM?

When you select text in tmux in copy-mode then the selected text
is exactly what is sent to the LLM (aside from a generic system
prompt).

When you don't explicitly select text, the last 50 lines get
sent by default. You can change this by setting the
@tmux-llm-terminal-history-length option.

Each invocation is isolated, there is no chat history.

If you need to provide some additional commentary to the LLM, do
that by typing it directly in your terminal.
