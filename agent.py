#!/usr/bin/env python3
"""Minimal agent - just runs the real prompt. Prompt handles fetch + pick via LLM tools."""
import subprocess, pathlib

PROMPT_FILE = pathlib.Path(__file__).parent / "prompt_research_safe_push.md"
MODEL = "ollama/qwen3:8b"

def main():
    prompt = PROMPT_FILE.read_text()
    # Let the prompt handle fetch_board + pick_idea via LLM tools (fetch/web_search)
    subprocess.run(["opencode", "run", "-m", MODEL, "--auto", prompt])

if __name__ == "__main__":
    main()
