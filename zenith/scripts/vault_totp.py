#!/usr/bin/env python3
"""
Panacea Vault TOTP (2FA) Service
RFC 6238 compliant TOTP generator for two-factor authentication.
"""

import sys
import json
import time
import hmac
import hashlib
import base64
import struct
import urllib.parse

def clean_secret(s):
    if not s:
        return ""
    s = s.strip()
    # Check if otpauth:// URI
    if s.lower().startswith("otpauth://"):
        try:
            parsed = urllib.parse.urlparse(s)
            params = urllib.parse.parse_qs(parsed.query)
            sec_list = params.get("secret") or params.get("Secret") or []
            if sec_list:
                s = sec_list[0].strip()
        except Exception:
            pass
    # Remove common separators (spaces, dashes)
    s = s.replace(" ", "").replace("-", "").upper()
    # Fix base32 padding
    missing_padding = len(s) % 8
    if missing_padding:
        s += "=" * (8 - missing_padding)
    return s

def calculate_totp(secret, interval=30, digits=6):
    s = clean_secret(secret)
    if not s:
        return {"code": "", "remaining": 0, "valid": False, "error": "Empty secret"}
    try:
        key = base64.b32decode(s, casefold=True)
    except Exception as e:
        return {"code": "", "remaining": 0, "valid": False, "error": f"Invalid base32: {e}"}

    now = int(time.time())
    counter = now // interval
    remaining = interval - (now % interval)
    counter_bytes = struct.pack(">Q", counter)

    try:
        h = hmac.new(key, counter_bytes, hashlib.sha1).digest()
        offset = h[-1] & 0x0F
        code_int = (struct.unpack(">I", h[offset:offset+4])[0] & 0x7FFFFFFF) % (10 ** digits)
        code_str = str(code_int).zfill(digits)
        # Format as 123 456 for readability
        formatted = f"{code_str[:3]} {code_str[3:]}" if digits == 6 else code_str
        return {
            "code": code_str,
            "formatted": formatted,
            "remaining": remaining,
            "period": interval,
            "valid": True
        }
    except Exception as e:
        return {"code": "", "remaining": 0, "valid": False, "error": str(e)}

def batch_totp(data):
    results = {}
    if isinstance(data, list):
        for item in data:
            if not isinstance(item, dict):
                continue
            entry_id = str(item.get("id", ""))
            secret = str(item.get("totp") or item.get("secret") or "")
            if secret:
                results[entry_id] = calculate_totp(secret)
    elif isinstance(data, dict):
        for entry_id, secret in data.items():
            if secret:
                results[str(entry_id)] = calculate_totp(str(secret))
    return results

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Missing command"}))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "code":
        secret = sys.argv[2] if len(sys.argv) > 2 else ""
        res = calculate_totp(secret)
        print(json.dumps(res))
    elif cmd == "batch":
        raw = sys.argv[2] if len(sys.argv) > 2 else ""
        if not raw and not sys.stdin.isatty():
            raw = sys.stdin.readline()
            if not raw:
                raw = sys.stdin.read()
        try:
            parsed = json.loads(raw) if raw else {}
            res = batch_totp(parsed)
            print(json.dumps(res), flush=True)
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)
    else:
        print(json.dumps({"error": f"Unknown command {cmd}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
