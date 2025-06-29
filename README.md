# tmux-llm

A tmux plugin to get quick reactions from an LLM assistant to the terminal window contents.

This plugin is intentionally simple in terms of functionality as well as architecture.

## Functionality

- Select text in a tmux pane.
- Hit Ctrl+G.
- Get a streamed response from an LLM API in a tmux popup.
- Configure any openai-compatible provider / API.


## Installation

### Using TPM (Tmux Plugin Manager)

Add this line to your `~/.tmux.conf`:

```bash
set -g @plugin 'your-username/tmux-llm'
```

Then press `prefix + I` to install.

### Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/your-username/tmux-llm ~/.tmux/plugins/tmux-llm
   ```

2. Add this line to your `~/.tmux.conf`:
   ```bash
   run-shell ~/.tmux/plugins/tmux-llm/plugin.tmux
   ```

3. Reload tmux configuration:
   ```bash
   tmux source-file ~/.tmux.conf
   ```

## Configuration

Set your API key and customize options in `~/.tmux.conf`:

```bash
# Required: Set your API key
set -g @tmux-llm-api-key 'your-api-key-here'

# Optional: Customize key binding (default: Ctrl+G)
set -g @tmux-llm-key 'C-g'

# Optional: Set API endpoint (default: OpenAI)
set -g @tmux-llm-api-endpoint 'https://api.openai.com/v1/chat/completions'

# Optional: Set model (default: gpt-3.5-turbo)
set -g @tmux-llm-model 'gpt-4'
```

## Usage

1. Select text in a tmux pane (copy mode) or just position cursor anywhere
2. Press `Ctrl+G` (or your configured key binding)
3. The LLM response will appear in a popup window
4. Press any key to close the popup

## Architecture

The bulk of the implementation is contained in a single Python
script with no dependencies (i.e. using just urllib etc.).

The Python script just takes text on the standard input and
streams the response right back. There is no conversation
history and no additional context from the user beyond the
selected text.

It is possible to configure the API endpoint, model name and API
key in a way that is customary for tmux plugins.

There is a shell wrapper which extracts the currently selected
text, sends it to Python and displays the output in a popup
window. `tmux display-popup` is used to actually display the
popup.
