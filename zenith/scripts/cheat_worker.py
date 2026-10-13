#!/usr/bin/env python3
"""
Zenith Cheat Sheet Worker
Queries tldr & cht.sh and returns structured JSON for CheatView.qml.
"""
import json
import re
import subprocess
import sys
import urllib.request

def parse_tldr_output(query, text):
    lines = text.splitlines()
    desc_lines = []
    examples = []
    current_desc = ""

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        # Link or header lines
        if stripped.startswith("<http") or stripped.startswith("More info") or stripped.startswith("Mais informações"):
            continue
        # Command line (indented by 4-6 spaces)
        if (line.startswith("      ") or line.startswith("    ")) and stripped and not stripped.startswith("-"):
            if current_desc:
                examples.append({
                    "desc": current_desc,
                    "cmd": stripped
                })
                current_desc = ""
        else:
            # Descriptive line
            if not examples and not current_desc and not stripped.startswith("-") and not stripped.endswith(":"):
                desc_lines.append(stripped)
            else:
                current_desc = stripped.lstrip("- ").rstrip(":")

    overall_desc = " ".join(desc_lines) if desc_lines else f"Exemplos de uso para {query}"
    return overall_desc, examples

def parse_cht_output(query, text):
    lines = text.splitlines()
    desc_lines = []
    examples = []
    current_desc = ""

    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            comment = stripped.lstrip("# ").strip()
            if not examples and len(desc_lines) < 2:
                desc_lines.append(comment)
            else:
                current_desc = comment
        elif stripped.startswith(">") or (not stripped.startswith("<") and not stripped.startswith("/*")):
            cmd = stripped.lstrip("> ").strip()
            if cmd and len(cmd) > 2:
                examples.append({
                    "desc": current_desc if current_desc else f"Exemplo de {query}:",
                    "cmd": cmd
                })
                current_desc = ""
        if len(examples) >= 8:
            break

    overall_desc = " ".join(desc_lines) if desc_lines else f"Cheat sheet de {query}"
    return overall_desc, examples

def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print(json.dumps({"ok": False, "error": "Comando não especificado"}))
        return

    query = sys.argv[1].strip().lower()

    # 1. Try local tldr
    try:
        proc = subprocess.run(["tldr", query], capture_output=True, text=True)
        if proc.returncode == 0 and proc.stdout.strip():
            desc, examples = parse_tldr_output(query, proc.stdout.strip())
            if examples:
                print(json.dumps({
                    "ok": True,
                    "source": "tldr (local)",
                    "query": query,
                    "description": desc,
                    "examples": examples
                }, ensure_ascii=False))
                return
    except Exception:
        pass

    # 2. Try cheat.sh
    try:
        url = f"https://cht.sh/{query}?T"
        req = urllib.request.Request(url, headers={"User-Agent": "curl/8.0.0"})
        with urllib.request.urlopen(req, timeout=4) as resp:
            raw = resp.read().decode("utf-8", errors="replace").strip()
            if raw and not raw.startswith("<!DOCTYPE") and not raw.startswith("<html"):
                desc, examples = parse_cht_output(query, raw)
                if examples:
                    print(json.dumps({
                        "ok": True,
                        "source": "cheat.sh",
                        "query": query,
                        "description": desc,
                        "examples": examples
                    }, ensure_ascii=False))
                    return
    except Exception:
        pass

    print(json.dumps({
        "ok": False,
        "query": query,
        "error": f"Nenhum exemplo encontrado para '{query}'. Tente outro comando."
    }, ensure_ascii=False))

if __name__ == "__main__":
    main()
