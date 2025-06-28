# tmux-llm

A tmux plugin to get quick reactions from an LLM assistant to the terminal window contents.

This plugin is intentionally simple in terms of functionality as well as architecture.

## Functionality

- Select text in a tmux pane.
- Hit Ctrl+G.
- Get a streamed response from an LLM API in a tmux popup.
- Configure any openai-compatible provider / API.


## Architecture

The bulk of the implementation is contained in a single Python
script with no dependencies (i.e. using just urrllib etc.).

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
