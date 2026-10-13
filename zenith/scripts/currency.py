#!/usr/bin/env python3
import os
import sys
import json
import time
import urllib.request

CACHE_DIR = os.path.expanduser("~/.cache/zenith")
CACHE_FILE = os.path.join(CACHE_DIR, "currency_rates.json")

# Baseline offline rates (relative to USD = 1.0)
BASELINE_RATES = {
    "USD": 1.0,
    "BRL": 5.15,
    "EUR": 0.87,
    "GBP": 0.74,
    "JPY": 154.5,
    "CAD": 1.38,
    "AUD": 1.54,
    "CHF": 0.88,
    "CNY": 7.23,
    "ARS": 980.0,
    "BTC": 0.000016
}

def ensure_cache_dir():
    if not os.path.exists(CACHE_DIR):
        try:
            os.makedirs(CACHE_DIR, exist_ok=True)
        except Exception:
            pass

def load_cached_rates():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "rates" in data and isinstance(data["rates"], dict):
                    return data
        except Exception:
            pass
    return {"rates": BASELINE_RATES, "updated": 0, "source": "offline"}

def save_rates(data):
    ensure_cache_dir()
    try:
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

def fetch_online_rates():
    # Try open.er-api.com (free, no api key required)

    url = "https://open.er-api.com/v6/latest/USD"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Zenith/1.0"})
        with urllib.request.urlopen(req, timeout=4) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if data.get("result") == "success" and "rates" in data:
                rates = data["rates"]
                res = {
                    "rates": rates,
                    "updated": int(time.time()),
                    "source": "open.er-api.com"
                }
                save_rates(res)
                return res
    except Exception:
        pass

    # Fallback to cached or baseline
    return load_cached_rates()

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "get"
    if cmd == "fetch":
        data = fetch_online_rates()
        print(json.dumps(data))
    elif cmd == "get":
        data = load_cached_rates()
        # If cache is older than 24h or missing, trigger fetch in background or attempt fetch
        if data.get("updated", 0) < time.time() - 86400:
            data = fetch_online_rates()
        print(json.dumps(data))
    else:
        print(json.dumps(load_cached_rates()))

if __name__ == "__main__":
    main()
