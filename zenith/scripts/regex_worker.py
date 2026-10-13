#!/usr/bin/env python3
"""
Zenith Regex Generator Worker
One-shot local LLM regex generation via Ollama (qwen2.5-coder:7b).
Outputs JSON for RegexView.qml.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request

OLLAMA_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "qwen2.5-coder:7b"

def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print(json.dumps({"ok": False, "error": "Prompt vazio"}))
        return

    prompt = sys.argv[1].strip()
    sample = sys.argv[2].strip() if len(sys.argv) > 2 else ""

    instruction = (
        "You are an expert regular expression generator.\n"
        "Generate a regular expression matching the user specification.\n"
        f"Specification: {prompt}\n"
    )
    if sample:
        instruction += f"Sample text to match: {sample}\n"

    instruction += (
        "\nCRITICAL INSTRUCTIONS:\n"
        "1. Return ONLY the regex pattern string.\n"
        "2. Do NOT enclose in markdown code fences, backticks, quotes, or forward slashes (/.../).\n"
        "3. Do NOT provide explanations, comments, or extra text.\n"
        "4. Output MUST be ONLY the raw regex string."
    )

    payload = json.dumps({
        "model": OLLAMA_MODEL,
        "prompt": instruction,
        "stream": False,
        "options": {
            "temperature": 0.1,
            "top_p": 0.9
        }
    }).encode("utf-8")

    try:
        req = urllib.request.Request(
            OLLAMA_URL,
            data=payload,
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            raw = data.get("response", "").strip()
    except urllib.error.URLError:
        print(json.dumps({"ok": False, "error": "Ollama offline em localhost:11434"}))
        return
    except Exception as e:
        print(json.dumps({"ok": False, "error": f"Erro de comunicação: {e}"}))
        return

    # Clean up output
    regex = raw
    regex = re.sub(r"^```[a-zA-Z0-9_-]*\n?", "", regex)
    regex = re.sub(r"\n?```$", "", regex)
    regex = regex.strip()
    if regex.startswith("`") and regex.endswith("`"):
        regex = regex[1:-1].strip()
    if regex.startswith('"') and regex.endswith('"'):
        regex = regex[1:-1].strip()
    if regex.startswith("'") and regex.endswith("'"):
        regex = regex[1:-1].strip()
    if regex.startswith("/") and len(regex) > 2 and regex[-1] in "/giu":
        regex = re.sub(r"^/(.*)/[a-z]*$", r"\1", regex)

    if not regex:
        print(json.dumps({"ok": False, "error": "IA não retornou padrão válido"}))
        return

    matched = None
    if sample:
        try:
            matched = bool(re.search(regex, sample))
        except Exception:
            matched = False

    print(json.dumps({
        "ok": True,
        "regex": regex,
        "matched": matched,
        "sample": sample,
        "error": None
    }))

if __name__ == "__main__":
    main()
