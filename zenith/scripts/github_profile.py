#!/usr/bin/env python3
import sys
import os
import json
import urllib.request
import subprocess

CONFIG_DIR = os.path.expanduser("~/.config/zenith")
USER_FILE = os.path.join(CONFIG_DIR, "github_user.txt")
CACHE_FILE = os.path.join(CONFIG_DIR, "github_data.json")
AVATAR_FILE = os.path.join(CONFIG_DIR, "assets", "github_avatar.png")

def get_current_user():
    if len(sys.argv) > 1 and sys.argv[1] == "--save" and len(sys.argv) > 2:
        username = sys.argv[2].strip()
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(USER_FILE, "w") as f:
            f.write(username)
        return username
    if len(sys.argv) > 1 and not sys.argv[1].startswith("--"):
        return sys.argv[1].strip()
    if os.path.exists(USER_FILE):
        try:
            with open(USER_FILE) as f:
                u = f.read().strip()
                if u: return u
        except Exception:
            pass
    # Try to find out from git config if there is github.user or user.name without spaces


    for cfg_key in ["github.user", "user.name"]:
        try:
            u = subprocess.check_output(["git", "config", "--global", cfg_key], stderr=subprocess.DEVNULL).decode().strip()
            if u and " " not in u:
                return u
        except Exception:
            pass
    return ""

def fetch_profile(username):
    data = {
        "login": username,
        "name": username,
        "handle": ("@" + username) if username else "",
        "bio": "",
        "avatar": AVATAR_FILE if (os.path.exists(AVATAR_FILE) and username) else "",
        "stars": 0,
        "repos": 0,
        "forks": 0,
        "totalContributions": 0,
        "contributions": []
    }

    if not username:
        return data

    # 1. GitHub API Profile
    try:
        req = urllib.request.Request(f"https://api.github.com/users/{username}", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=5) as r:
            u = json.loads(r.read().decode())
            data["login"] = u.get("login", username)
            data["name"] = u.get("name") or u.get("login", username)
            data["handle"] = "@" + data["login"]
            if u.get("bio"):
                data["bio"] = u["bio"]
            data["repos"] = u.get("public_repos", 0)

            # download avatar
            avatar_url = u.get("avatar_url")
            if avatar_url:
                os.makedirs(os.path.dirname(AVATAR_FILE), exist_ok=True)
                urllib.request.urlretrieve(avatar_url, AVATAR_FILE)
                data["avatar"] = AVATAR_FILE
    except Exception:
        pass

    # 2. GitHub Repos (stars & forks)
    try:
        req_r = urllib.request.Request(f"https://api.github.com/users/{username}/repos?per_page=100", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req_r, timeout=5) as resp_r:
            repos = json.loads(resp_r.read().decode())
            data["stars"] = sum(r.get("stargazers_count", 0) for r in repos)
            data["forks"] = sum(r.get("forks_count", 0) for r in repos)
    except Exception:
        pass

    # 3. Contributions
    try:
        req_c = urllib.request.Request(f"https://github-contributions-api.jogruber.de/v4/{username}?y=last", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req_c, timeout=5) as resp_c:
            c = json.loads(resp_c.read().decode())
            data["totalContributions"] = c.get("total", {}).get("lastYear", 0)
            raw = c.get("contributions", [])
            # 24 weeks * 7 days = 168 cells
            days = raw[-168:] if len(raw) >= 168 else raw
            while len(days) < 168:
                days.insert(0, {"date": "", "count": 0, "level": 0})
            data["contributions"] = days
    except Exception:
        pass

    # Fallback to cache if contributions empty but cache exists
    if not data["contributions"] and os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE) as f:
                old = json.load(f)
                if old.get("login") == username and old.get("contributions"):
                    data["contributions"] = old["contributions"]
                    data["totalContributions"] = old.get("totalContributions", 0)
        except Exception:
            pass

    # Save cache
    try:
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(CACHE_FILE, "w") as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

    return data

if __name__ == "__main__":
    user = get_current_user()
    res = fetch_profile(user)
    print(json.dumps(res))
