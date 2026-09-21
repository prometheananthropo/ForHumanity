#!/usr/bin/env python3
"""Minimal agent - just runs the real prompt via local LLM (Ollama)."""
import json, pathlib, urllib.request, urllib.error, datetime

BOARD_URL = "https://raw.githubusercontent.com/prometheananthropo/ForHumanity/main/board.json"
PROMPT_FILE = pathlib.Path(__file__).parent / "prompt_safe_push.md"
OLLAMA_URL = "http://192.168.1.200:11434/api/generate"
MODEL = "qwen3:8b"  # fast, change to qwen3.5:9b / gemma4:e4b / hf.co/... for rotation

def fetch_board():
    with urllib.request.urlopen(BOARD_URL, timeout=10) as r:
        return json.loads(r.read().decode())

def pick_idea(board):
    ideas = [t for t in board["tasks"] if t["type"] == "IDEA"]
    ideas.sort(key=lambda x: x["id"])
    # fewest RESEARCH first (balanced)
    def count_res(idea):
        return len([c for c in board["tasks"] if c["parent_id"] == idea["id"] and c["type"] == "RESEARCH"])
    ideas.sort(key=lambda x: count_res(x))
    return ideas[0] if ideas else None

def call_llm(prompt, board_snippet):
    payload = json.dumps({
        "model": MODEL,
        "prompt": f"{prompt}\n\nBOARD TASK:\n{json.dumps(board_snippet, indent=2)}\n\nDo RESEARCH for this IDEA (300w, citations). Output markdown only.",
        "stream": False,
        "options": {"temperature": 0.7}
    }).encode()
    req = urllib.request.Request(OLLAMA_URL, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())["response"]

def main():
    board = fetch_board()
    idea = pick_idea(board)
    if not idea:
        print("No IDEA found")
        return
    print(f"[WORKING][ID:{idea['id']}] {idea['title']}")
    prompt = PROMPT_FILE.read_text()
    print(f"[MODEL] {MODEL} via {OLLAMA_URL}")
    # Minimal: just run prompt + idea through LLM
    try:
        result = call_llm(prompt, idea)
        print(f"[RESULT][ID:{idea['id']}][MODEL] {MODEL}")
        print(result[:2000])
        # Save to /tmp for manual review, not auto-pushing (safe)
        out = pathlib.Path(f"/tmp/report_{idea['id']}.md")
        out.write_text(result)
        print(f"Saved to {out}")
    except Exception as e:
        print(f"LLM call failed: {e}")

if __name__ == "__main__":
    main()
