#!/usr/bin/env python3
"""Collection of saved passwords from installed browsers.

Выводит в stdout JSON-массив вида
    [{"url": ..., "login": ..., "pw": ..., "browser": ...}, ...]

Does not send or write anywhere: only reads browser profiles
of the current user and prints what is found. The pill then displays
the list and saves selected items to its encrypted vault.

Supported:
  * Firefox family (Firefox, Librewolf, Floorp) — via libnss3;
  * Chromium family (Chromium, Chrome, Brave, Vivaldi, Edge) —
    key from GNOME Keyring / KWallet via Secret Service.

Absence of any browser or library is not an error: it is simply
skipped.
"""

import base64
import glob
import json
import os
import sys

HOME = os.path.expanduser("~")


def log(*a):
    print(*a, file=sys.stderr)


# --------------------------------------------------------------------------
# Firefox and its forks: passwords in logins.json, encrypted with a key from key4.db.
# Decryption using the standard libnss3 library, the same one it uses
# browser; libnss will ask for the master password (if specified), so here
# Only an empty master password is supported (common case).
# --------------------------------------------------------------------------
import ctypes as C


class NSS:
    def __init__(self):
        self.lib = None
        for name in ("libnss3.so", "libnss3.dylib", "nss3.dll"):
            try:
                self.lib = C.CDLL(name)
                break
            except OSError:
                continue
        if not self.lib:
            raise OSError("libnss3 not found")

    def init(self, profile):
        self.lib.NSS_Init.argtypes = [C.c_char_p]
        if self.lib.NSS_Init(profile.encode()) != 0:
            raise OSError("NSS_Init failed for " + profile)

    def shutdown(self):
        try:
            self.lib.NSS_Shutdown()
        except Exception:
            pass

    def decrypt(self, b64):
        class SECItem(C.Structure):
            _fields_ = [("type", C.c_uint),
                        ("data", C.c_char_p),
                        ("len", C.c_uint)]

        raw = base64.b64decode(b64)
        inp = SECItem(0, raw, len(raw))
        out = SECItem(0, None, 0)
        self.lib.PK11SDR_Decrypt.argtypes = [C.POINTER(SECItem),
                                             C.POINTER(SECItem), C.c_void_p]
        if self.lib.PK11SDR_Decrypt(C.byref(inp), C.byref(out), None) != 0:
            return None
        return C.string_at(out.data, out.len).decode("utf-8", "replace")


def firefox_profiles():
    # The default Firefox profile is located in ~/.mozilla/firefox, but builds with
    # The $HOME/.config layout (and part of the distribution packages) keep it in
    # ~/.config/mozilla/firefox - without this path, your own passwords could not be found.
    xdg = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
    roots = [
        os.path.join(HOME, ".mozilla", "firefox"),
        os.path.join(xdg, "mozilla", "firefox"),
        os.path.join(HOME, ".librewolf"),
        os.path.join(xdg, "librewolf"),
        os.path.join(HOME, ".floorp"),
        os.path.join(HOME, ".zen"),
        os.path.join(HOME, ".var", "app", "org.mozilla.firefox",
                     ".mozilla", "firefox"),
    ]
    profiles = []
    for root in roots:
        for logins in glob.glob(os.path.join(root, "*", "logins.json")):
            profiles.append(os.path.dirname(logins))
    return profiles


def collect_firefox():
    out = []
    profiles = firefox_profiles()
    if not profiles:
        return out
    try:
        nss = NSS()
    except OSError as e:
        log("firefox:", e)
        return out

    for prof in profiles:
        try:
            with open(os.path.join(prof, "logins.json")) as f:
                data = json.load(f)
        except Exception:
            continue
        try:
            nss.init(prof)
        except OSError as e:
            log("firefox:", e)
            continue
        name = os.path.basename(prof)
        for item in data.get("logins", []):
            host = item.get("hostname", "") or ""
            # Firefox keeps a service record in the same logins.json - key
            # account synchronization (chrome://FirefoxAccounts). Her "password" is
            # this is JSON with scopedKeys, not a site password. We only take
            # regular web logins, the rest (chrome://, moz-proxy:, etc.)
            # we skip it, otherwise this key would leak into the storage.
            if not host.startswith(("http://", "https://")):
                continue
            user = nss.decrypt(item.get("encryptedUsername", ""))
            pw = nss.decrypt(item.get("encryptedPassword", ""))
            if pw is None:
                # usually means master password - silently skip
                continue
            out.append({
                "url": item.get("hostname", ""),
                "login": user or "",
                "pw": pw,
                "browser": "Firefox (%s)" % name,
            })
        nss.shutdown()
    return out


# --------------------------------------------------------------------------
# Chromium and forks: passwords in Login Data (SQLite), AES-GCM encrypted,
# the key ("peanuts"/browser key) is in GNOME Keyring / KWallet and can be obtained
# via Secret Service.
# --------------------------------------------------------------------------
def chromium_key(secret_label_app):
    try:
        import secretstorage
    except Exception as e:
        log("chromium: python-secretstorage missing:", e)
        return None
    try:
        from hashlib import pbkdf2_hmac
        bus = secretstorage.dbus_init()
        password = None
        for coll in secretstorage.get_all_collections(bus):
            try:
                if coll.is_locked():
                    coll.unlock()
            except Exception:
                pass
            for item in coll.get_all_items():
                if item.get_label() == secret_label_app + " Safe Storage":
                    password = item.get_secret()
                    break
            if password is not None:
                break
        if password is None:
            # browsers without keyring use a fixed key "peanuts"
            password = b"peanuts"
        return pbkdf2_hmac("sha1", password, b"saltysalt", 1, 16)
    except Exception as e:
        log("chromium: keyring error:", e)
        return None


def chromium_decrypt(blob, key):
    if not blob:
        return ""
    try:
        if blob[:3] in (b"v10", b"v11"):
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            nonce = blob[3:15]
            ct = blob[15:]
            return AESGCM(key).decrypt(nonce, ct, None).decode(
                "utf-8", "replace")
    except Exception as e:
        log("chromium: decrypt:", e)
    return None


CHROMIUM_ROOTS = [
    (".config/google-chrome", "Chrome", "Chrome"),
    (".config/chromium", "Chromium", "Chromium"),
    (".config/BraveSoftware/Brave-Browser", "Brave", "Brave"),
    (".config/vivaldi", "Vivaldi", "Vivaldi"),
    (".config/microsoft-edge", "Edge", "Microsoft Edge"),
]


def collect_chromium():
    import sqlite3
    import shutil
    import tempfile
    out = []
    for rel, name, secret_app in CHROMIUM_ROOTS:
        root = os.path.join(HOME, rel)
        if not os.path.isdir(root):
            continue
        key = chromium_key(secret_app)
        if key is None:
            continue
        for db in glob.glob(os.path.join(root, "*", "Login Data")):
            # copy: the browser keeps the file open
            tmp = tempfile.mktemp(suffix=".db")
            try:
                shutil.copyfile(db, tmp)
                con = sqlite3.connect(tmp)
                rows = con.execute(
                    "SELECT origin_url, username_value, password_value "
                    "FROM logins").fetchall()
                con.close()
            except Exception as e:
                log("chromium:", e)
                continue
            finally:
                try:
                    os.unlink(tmp)
                except OSError:
                    pass
            prof = os.path.basename(os.path.dirname(db))
            for url, user, enc in rows:
                if not (url or "").startswith(("http://", "https://")):
                    continue
                pw = chromium_decrypt(enc, key)
                if pw is None or pw == "":
                    continue
                out.append({
                    "url": url or "",
                    "login": user or "",
                    "pw": pw,
                    "browser": "%s (%s)" % (name, prof),
                })
    return out


def main():
    found = []
    try:
        found += collect_firefox()
    except Exception as e:
        log("firefox failed:", e)
    try:
        found += collect_chromium()
    except Exception as e:
        log("chromium failed:", e)

    # unique by (url, login, pw)
    seen = set()
    uniq = []
    for e in found:
        k = (e["url"], e["login"], e["pw"])
        if k in seen:
            continue
        seen.add(k)
        uniq.append(e)

    json.dump(uniq, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
