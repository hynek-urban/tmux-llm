#!/usr/bin/env python3
"""
tmux-llm: A simple Python script to get LLM responses for tmux plugin.
Takes text from stdin and streams the response from an OpenAI-compatible API.
"""

import json
import os
import sys
import textwrap
import urllib.error  
import urllib.request
from typing import Any
from typing import Dict
from typing import Iterator

DEFAULT_ENDPOINT = "https://api.openai.com/v1/chat/completions"
DEFAULT_MODEL = "gpt-4o-mini"


def get_fold_width() -> int:
    """Calculate fold width from environment variables set by shell script."""
    # Get terminal width
    terminal_width = int(os.getenv("COLUMNS", "120"))
    popup_width_str = os.getenv("TMUX_LLM_POPUP_WIDTH", "90%")
    
    if popup_width_str.endswith("%"):
        percentage = int(popup_width_str[:-1])
        popup_width = int(terminal_width * percentage / 100)
    else:
        popup_width = int(popup_width_str)
    
    # Account for margins and padding
    fold_width = popup_width - 4
    return max(40, fold_width)  # Minimum 40 chars


class StreamingWrapper:
    """Handle streaming text with word-boundary wrapping and margins."""
    
    def __init__(self, width: int):
        self.width = width
        self.current_line = ""
        self.buffer = ""
    
    def add_text(self, text: str) -> str:
        """Add text and return any complete wrapped lines."""
        self.buffer += text
        output = ""
        
        # Process complete words
        while " " in self.buffer or "\n" in self.buffer:
            if "\n" in self.buffer:
                # Handle explicit newlines
                parts = self.buffer.split("\n", 1)
                self.current_line += parts[0]
                output += self._finish_line()
                self.buffer = parts[1] if len(parts) > 1 else ""
                self.current_line = ""
            else:
                # Find next space
                space_idx = self.buffer.find(" ")
                word = self.buffer[:space_idx + 1]
                
                if len(self.current_line + word.strip()) > self.width:
                    # Word would overflow, finish current line
                    if self.current_line:
                        output += self._finish_line()
                        self.current_line = word.strip()
                    else:
                        # Single word longer than width, just add it
                        self.current_line = word.strip()
                else:
                    self.current_line += word
                
                self.buffer = self.buffer[space_idx + 1:]
        
        return output
    
    def finish(self) -> str:
        """Finish processing and return final line."""
        if self.buffer:
            self.current_line += self.buffer
        return self._finish_line() if self.current_line else ""
    
    def _finish_line(self) -> str:
        """Add margins and return completed line."""
        return f" {self.current_line.strip()} \n"


def get_config() -> Dict[str, str]:
    """Get configuration from environment variables with defaults."""
    return {
        "api_endpoint": os.getenv("TMUX_LLM_API_ENDPOINT", DEFAULT_ENDPOINT),
        "model": os.getenv("TMUX_LLM_MODEL", DEFAULT_MODEL),
        "api_key": os.getenv("TMUX_LLM_API_KEY", ""),
    }


def create_request(text: str, config: Dict[str, str]) -> urllib.request.Request:
    """Create the API request with proper headers and payload."""
    headers = {
        "Content-Type": "application/json",
        "Authorization": f'Bearer {config["api_key"]}',
    }

    system_prompt = (
        "You are an assistant designed to provide concise, helpful responses that will be displayed "
        "in a mid-sized, non-interactive popup window. Your responses should be:\n\n"
        "- Concise but complete (you must fit roughly within 20 lines)\n"
        "- Directly actionable when possible\n"
        "- Complete and self-contained (no follow-up questions)\n"
        "- Focused on the most likely helpful information\n\n"
        "Do not ask for clarification or additional information. Work with what you're given and "
        "provide the best possible answer based on the available context.\n\n"
        "Never provide lists, bullet points, or numbered items with more than three items. "
        "Use short sentences and paragraphs. Be very consise!"
    )

    payload = {
        "model": config["model"],
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text}
        ],
        "stream": True,
        "temperature": 0.7,
    }

    data = json.dumps(payload).encode("utf-8")
    return urllib.request.Request(config["api_endpoint"], data=data, headers=headers, method="POST")


def parse_sse_line(line: str) -> Dict[str, Any]:
    """Parse a Server-Sent Events line."""
    if line.startswith("data: "):
        data_str = line[6:].strip()
        if data_str == "[DONE]":
            return {"done": True}
        try:
            return json.loads(data_str)
        except json.JSONDecodeError:
            return {}
    return {}


def stream_response(request: urllib.request.Request) -> Iterator[str]:
    """Stream the response from the API."""
    try:
        with urllib.request.urlopen(request) as response:
            buffer = ""
            for chunk in response:
                buffer += chunk.decode("utf-8")
                lines = buffer.split("\n")
                buffer = lines[-1]  # Keep incomplete line in buffer

                for line in lines[:-1]:
                    if not line.strip():
                        continue

                    data = parse_sse_line(line)
                    if data.get("done"):
                        return

                    # Extract content from the response
                    choices = data.get("choices", [])
                    if choices and "delta" in choices[0]:
                        content = choices[0]["delta"].get("content", "")
                        if content:
                            yield content

    except urllib.error.HTTPError as e:
        error_msg = f"HTTP Error {e.code}: {e.reason}"
        try:
            error_data = e.read().decode("utf-8")
            error_json = json.loads(error_data)
            if "error" in error_json:
                error_msg = f"API Error: {error_json['error'].get('message', error_msg)}"
        except:
            pass
        yield f"\nError: {error_msg}\n"

    except Exception as e:
        yield f"\nError: {str(e)}\n"


def main() -> None:
    """Main function to read input and stream LLM response."""
    # Read input from stdin
    input_text = sys.stdin.read().strip()

    if not input_text:
        print("Error: No input text provided", file=sys.stderr)
        sys.exit(1)

    # Get configuration and setup wrapper
    config = get_config()
    fold_width = get_fold_width()
    wrapper = StreamingWrapper(fold_width)

    # Create request
    request = create_request(input_text, config)

    # Stream response with wrapping
    try:
        for chunk in stream_response(request):
            wrapped_output = wrapper.add_text(chunk)
            if wrapped_output:
                sys.stdout.write(wrapped_output)
                sys.stdout.flush()
        
        # Output any remaining text
        final_output = wrapper.finish()
        if final_output:
            sys.stdout.write(final_output)
        
    except KeyboardInterrupt:
        print("\n\nInterrupted", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
