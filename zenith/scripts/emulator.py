#!/usr/bin/env python3
import os
import sys
import json
import struct
import zlib
import shutil
import subprocess
import time
import urllib.request
import urllib.parse
from pathlib import Path

HOME = os.path.expanduser("~")
CONFIG_DIR = os.path.join(HOME, ".config", "zenith")
CACHE_DIR = os.path.join(HOME, ".cache", "zenith", "emulator")
ICONS_DIR = os.path.join(CACHE_DIR, "icons")
DATA_DIR = os.path.join(HOME, ".local", "share", "zenith", "emulator")
SAVES_DIR = os.path.join(DATA_DIR, "saves")
STATES_DIR = os.path.join(DATA_DIR, "states")
STATE_FILE = os.path.join(CONFIG_DIR, "emulator_state.json")
DOWNLOAD_STATUS_FILE = os.path.join(CACHE_DIR, "download_status.json")

DEFAULT_ROM_DIRS = [
    os.path.join(HOME, "ROMs"),
    os.path.join(HOME, "ROMs", "GBA"),
    os.path.join(HOME, "ROMs", "NDS"),
    os.path.join(HOME, "ROMs", "3DS"),
    os.path.join(HOME, "Games"),
    os.path.join(HOME, "Downloads"),
]

ROM_EXTENSIONS = {
    ".gba": "GBA",
    ".agb": "GBA",
    ".gb":  "GBA",
    ".gbc": "GBA",
    ".nds": "NDS",
    ".srl": "NDS",
    ".dsi": "NDS",
    ".3ds": "3DS",
    ".cci": "3DS",
    ".cxi": "3DS",
    ".3dsx": "3DS",
    ".cia": "3DS",
}

HOMEBREW_CATALOG = [
    {
        "id": "celeste_gba",
        "title": "Celeste Classic (GBA Port)",
        "platform": "GBA",
        "author": "JeffRuLz / Matt Makes Games",
        "desc_pt": "Port completo de Celeste Classic para Game Boy Advance com física, música e todos os níveis.",
        "desc_en": "Full Game Boy Advance port of Celeste Classic with accurate physics and soundtrack.",
        "filename": "Celeste_Classic.gba",
        "size_str": "5.2 MB",
        "url": "https://github.com/JeffRuLz/Celeste-Classic-GBA/releases/download/v1.2/Celeste.Classic.v1.2.Homebrew.gba"
    },
    {
        "id": "doom2d_gba",
        "title": "Doom 2D (AGB Edition)",
        "platform": "GBA",
        "author": "neparij",
        "desc_pt": "Ação frenética estilo Doom em 2D nativo para o Game Boy Advance.",
        "desc_en": "Fast-paced 2D Doom action game built natively for the Game Boy Advance.",
        "filename": "Doom2D_AGB.gba",
        "size_str": "4.8 MB",
        "url": "https://github.com/neparij/doom2d-agb/releases/download/v0.2.0/doom2d.0.2.0-d2265bc.gba"
    },
    {
        "id": "solar_guard_gba",
        "title": "Solar Guard (GBA Jam)",
        "platform": "GBA",
        "author": "Deft-Spade",
        "desc_pt": "Shoot 'em up espacial criado para a GBA Jam 2021 com gráficos pixel-art incríveis.",
        "desc_en": "Space shoot 'em up built for GBA Jam 2021 featuring crisp pixel-art graphics.",
        "filename": "Solar_Guard.gba",
        "size_str": "512 KB",
        "url": "https://github.com/Deft-Spade/Solar-Guard/releases/download/GBA-JAM-2021/Solar_Guard_GBA_JAM_2021.gba"
    },
    {
        "id": "snek_gba",
        "title": "Snek GBA",
        "platform": "GBA",
        "author": "LeonarthCG",
        "desc_pt": "Jogo arcade clássico da cobrinha (Snake) com visual moderno para GBA.",
        "desc_en": "Modern arcade Snake game designed for the Game Boy Advance.",
        "filename": "Snek_GBA.gba",
        "size_str": "1.7 MB",
        "url": "https://github.com/LeonarthCG/Snek-GBA/releases/download/v1.1/snek.gba"
    },
    {
        "id": "notebook_adv_gba",
        "title": "Notebook Adventure",
        "platform": "GBA",
        "author": "NotImplementedLife",
        "desc_pt": "Plataforma desenhado à mão num caderno escolar para Game Boy Advance.",
        "desc_en": "Hand-drawn notebook platformer adventure for Game Boy Advance.",
        "filename": "Notebook_Adventure.gba",
        "size_str": "1.1 MB",
        "url": "https://github.com/NotImplementedLife/NotebookAdventure/releases/download/v1.3/NotebookAdventure-1-3.gba"
    },
    {
        "id": "apix_nds",
        "title": "A-Pix Studio DS",
        "platform": "NDS",
        "author": "Alfombracitario",
        "desc_pt": "Estúdio interativo de Pixel Art para Nintendo DS usando as duas telas e a Stylus (Touchscreen).",
        "desc_en": "Interactive dual-screen Pixel Art editor for Nintendo DS using the Stylus touchscreen.",
        "filename": "A-Pix_Studio.nds",
        "size_str": "336 KB",
        "url": "https://github.com/Alfombracitario/A-PIX_DS/releases/download/0.7/A-Pix.nds"
    },
    {
        "id": "micpass_nds",
        "title": "DS Audio & Mic Lab",
        "platform": "NDS",
        "author": "korbosoft",
        "desc_pt": "Utilitário interativo de áudio e touchscreen para testar o hardware do Nintendo DS.",
        "desc_en": "Interactive audio & touchscreen utility for Nintendo DS hardware testing.",
        "filename": "DS_MicLab.nds",
        "size_str": "175 KB",
        "url": "https://github.com/korbosoft/ds-micpassthrough/releases/download/v2.1.0/ds-micpassthrough.nds"
    },
    {
        "id": "anemone_3ds",
        "title": "Anemone 3DS",
        "platform": "3DS",
        "author": "astronautlevel2",
        "desc_pt": "Aplicativo oficial homebrew 3DS com interface 3D/Dual-Screen completa para testar o motor Azahar.",
        "desc_en": "Official 3DS homebrew app with full dual-screen UI for testing the Azahar 3DS engine.",
        "filename": "Anemone3DS.3dsx",
        "size_str": "1.7 MB",
        "url": "https://github.com/astronautlevel2/Anemone3DS/releases/download/v3.0.1/Anemone3DS.3dsx"
    },
    {
        "id": "checkpoint_3ds",
        "title": "Checkpoint 3DS",
        "platform": "3DS",
        "author": "FlagBrew",
        "desc_pt": "Dashboard gráfico nativo de Nintendo 3DS desenvolvido pelo time FlagBrew.",
        "desc_en": "Native Nintendo 3DS graphical dashboard developed by the FlagBrew team.",
        "filename": "Checkpoint.3dsx",
        "size_str": "3.5 MB",
        "url": "https://github.com/BernardoGiordano/Checkpoint/releases/download/v5.3.0/Checkpoint.3dsx"
    }
]


def ensure_dirs():
    for d in [
        CACHE_DIR, ICONS_DIR, DATA_DIR, SAVES_DIR, STATES_DIR,
        os.path.join(HOME, "ROMs", "GBA"),
        os.path.join(HOME, "ROMs", "NDS"),
        os.path.join(HOME, "ROMs", "3DS"),
    ]:
        os.makedirs(d, exist_ok=True)


def load_state():
    ensure_dirs()
    default = {
        "favorites": [],
        "recent": [],
        "custom_dirs": [],
        "ds_layout": "Top/Bottom",
        "3ds_config": {
            "resolution_factor": 3,   # 3x = 720p HD
            "graphics_api": 2,        # 1 = OpenGL, 2 = Vulkan
            "layout_option": 0,       # 0 = Default, 2 = Large, 3 = Side-by-Side
            "auto_gamemode": True,
            "fullscreen": False
        }
    }
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                for k, v in default.items():
                    if k not in data:
                        data[k] = v
                if isinstance(data.get("3ds_config"), dict):
                    for k2, v2 in default["3ds_config"].items():
                        if k2 not in data["3ds_config"]:
                            data["3ds_config"][k2] = v2
                return data
        except Exception:
            pass
    return default


def save_state(st):
    ensure_dirs()
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(st, f, indent=2, ensure_ascii=False)
    except Exception:
        pass


def write_png_rgba(path, width, height, rgba_bytes):
    """Minimal pure-Python PNG writer for RGBA bytes."""
    def chunk(tag, data):
        return (
            struct.pack(">I", len(data)) +
            tag +
            data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    raw_rows = bytearray()
    stride = width * 4
    for y in range(height):
        raw_rows.append(0)  # Filter type 0 (None)
        raw_rows.extend(rgba_bytes[y * stride : (y + 1) * stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw_rows), 6)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def extract_nds_metadata(rom_path, icon_out_path):
    """Extract internal title, game code, and 32x32 4bpp BGR555 banner icon from a Nintendo DS ROM."""
    meta = {"internal_title": "", "game_code": "", "icon": ""}
    try:
        with open(rom_path, "rb") as f:
            hdr = f.read(0x200)
            if len(hdr) < 0x160:
                return meta
            raw_title = hdr[0x00:0x0C].split(b"\x00")[0].decode("ascii", errors="ignore").strip()
            raw_code = hdr[0x0C:0x10].split(b"\x00")[0].decode("ascii", errors="ignore").strip()
            meta["internal_title"] = raw_title
            if raw_code and raw_code != "####":
                meta["game_code"] = f"NTR-{raw_code}"

            banner_off = struct.unpack("<I", hdr[0x68:0x6C])[0]
            if banner_off > 0:
                f.seek(banner_off)
                banner = f.read(0x840)
                if len(banner) >= 0x340:
                    # Extract English UTF-16LE title at 0x240..0x340
                    eng_bytes = banner[0x240:0x340]
                    eng_title = eng_bytes.decode("utf-16-le", errors="ignore").split("\x00")[0].strip()
                    if eng_title:
                        lines = [ln.strip() for ln in eng_title.splitlines() if ln.strip()]
                        if lines:
                            meta["internal_title"] = " · ".join(lines[:2])

                    # Extract 32x32 4bpp tiled icon (0x20..0x220) + 16-color BGR555 palette (0x220..0x240)
                    if not os.path.exists(icon_out_path):
                        tile_data = banner[0x20:0x220]
                        pal_data = banner[0x220:0x240]
                        palette = []
                        for i in range(16):
                            c = struct.unpack("<H", pal_data[i * 2 : i * 2 + 2])[0]
                            r = ((c & 0x1F) * 255) // 31
                            g = (((c >> 5) & 0x1F) * 255) // 31
                            b = (((c >> 10) & 0x1F) * 255) // 31
                            a = 0 if i == 0 else 255
                            palette.append((r, g, b, a))

                        rgba = bytearray(32 * 32 * 4)
                        # 4x4 tiles of 8x8 pixels each
                        byte_idx = 0
                        for ty in range(4):
                            for tx in range(4):
                                for py in range(8):
                                    for px in range(0, 8, 2):
                                        bval = tile_data[byte_idx]
                                        byte_idx += 1
                                        c0 = palette[bval & 0x0F]
                                        c1 = palette[(bval >> 4) & 0x0F]
                                        x0 = tx * 8 + px
                                        y0 = ty * 8 + py
                                        off0 = (y0 * 32 + x0) * 4
                                        rgba[off0 : off0 + 4] = bytes(c0)
                                        off1 = (y0 * 32 + (x0 + 1)) * 4
                                        rgba[off1 : off1 + 4] = bytes(c1)
                        write_png_rgba(icon_out_path, 32, 32, rgba)
                    if os.path.exists(icon_out_path):
                        meta["icon"] = icon_out_path
    except Exception:
        pass
    return meta


def decode_3ds_smdh(smdh_bytes, icon_out_path):
    """Decode Nintendo 3DS SMDH structure (title, publisher, and 48x48 RGB565 Morton-tiled icon)."""
    meta = {"internal_title": "", "publisher": "", "icon": ""}
    if len(smdh_bytes) < 0x36C0 or smdh_bytes[:4] != b"SMDH":
        return meta
    try:
        # English application title is slot 1 (each slot is 0x200 bytes starting at 0x08)
        # Slot 1 starts at 0x08 + 0x200 = 0x208:
        # 0x00..0x80: short description (UTF-16LE)
        # 0x80..0x180: long description (UTF-16LE)
        # 0x180..0x200: publisher (UTF-16LE)
        slot_off = 0x208
        short_desc = smdh_bytes[slot_off : slot_off + 0x80].decode("utf-16-le", errors="ignore").split("\x00")[0].strip()
        publisher = smdh_bytes[slot_off + 0x180 : slot_off + 0x200].decode("utf-16-le", errors="ignore").split("\x00")[0].strip()
        if short_desc:
            meta["internal_title"] = short_desc.replace("\n", " ")
        if publisher:
            meta["publisher"] = publisher.replace("\n", " ")

        # Large icon (48x48 RGB565) is at offset 0x24C0..0x36C0 (0x1200 = 4608 bytes)
        if not os.path.exists(icon_out_path):
            large_icon = smdh_bytes[0x24C0:0x36C0]
            rgba = bytearray(48 * 48 * 4)

            # Morton (Z-order) lookup within an 8x8 tile
            def morton_index(x, y):
                idx = 0
                for b in range(3):
                    idx |= ((x >> b) & 1) << (2 * b)
                    idx |= ((y >> b) & 1) << (2 * b + 1)
                return idx

            tile_idx = 0
            for ty in range(6):
                for tx in range(6):
                    base_word = tile_idx * 64
                    tile_idx += 1
                    for py in range(8):
                        for px in range(8):
                            m = morton_index(px, py)
                            word_off = (base_word + m) * 2
                            c = struct.unpack("<H", large_icon[word_off : word_off + 2])[0]
                            r = (((c >> 11) & 0x1F) * 255) // 31
                            g = (((c >> 5) & 0x3F) * 255) // 63
                            b = ((c & 0x1F) * 255) // 31
                            ox = tx * 8 + px
                            oy = ty * 8 + py
                            dst = (oy * 48 + ox) * 4
                            rgba[dst : dst + 4] = bytes((r, g, b, 255))
            write_png_rgba(icon_out_path, 48, 48, rgba)
        if os.path.exists(icon_out_path):
            meta["icon"] = icon_out_path
    except Exception:
        pass
    return meta


def extract_3ds_metadata(rom_path, icon_out_path):
    meta = {"internal_title": "", "game_code": "", "icon": ""}
    try:
        with open(rom_path, "rb") as f:
            head = f.read(0x4000)
            # Check if .3dsx (3DSX magic at 0x00, SMDH offset at 0x20 if header_size >= 0x24)
            if head[:4] == b"3DSX" and len(head) >= 0x2C:
                hdr_sz = struct.unpack("<H", head[4:6])[0]
                if hdr_sz >= 0x24:
                    smdh_off, smdh_sz = struct.unpack("<II", head[0x20:0x28])
                    if smdh_off > 0 and smdh_sz >= 0x36C0:
                        f.seek(smdh_off)
                        smdh = f.read(0x36C0)
                        res = decode_3ds_smdh(smdh, icon_out_path)
                        meta.update(res)
                        meta["game_code"] = "HBRW-3DSX"
                        return meta
            # Otherwise search for SMDH magic in first 256KB or last 64KB (common in .cia/.3ds)
            f.seek(0)
            chunk = f.read(262144)
            pos = chunk.find(b"SMDH")
            if pos >= 0 and pos + 0x36C0 <= len(chunk):
                res = decode_3ds_smdh(chunk[pos : pos + 0x36C0], icon_out_path)
                meta.update(res)
                return meta
            # Check end of file for CIA SMDH
            fsize = os.path.getsize(rom_path)
            if fsize > 0x36C0:
                f.seek(max(0, fsize - 65536))
                tail = f.read(65536)
                pos = tail.find(b"SMDH")
                if pos >= 0 and pos + 0x36C0 <= len(tail):
                    res = decode_3ds_smdh(tail[pos : pos + 0x36C0], icon_out_path)
                    meta.update(res)
    except Exception:
        pass
    return meta


def generate_gba_badge_png(icon_out_path, code_text):
    """Generate a sleek pixel-art GBA cartridge badge PNG when no external boxart is cached."""
    if os.path.exists(icon_out_path):
        return icon_out_path
    try:
        w, h = 48, 48
        rgba = bytearray(w * h * 4)
        for y in range(h):
            for x in range(w):
                # Cartridge silhouette
                if x < 4 or x >= w - 4 or y < 4 or y >= h - 4:
                    rgba[(y * w + x) * 4 : (y * w + x + 1) * 4] = bytes((0, 0, 0, 0))
                    continue
                # Top notch corners
                if y < 8 and (x < 7 or x >= w - 7):
                    rgba[(y * w + x) * 4 : (y * w + x + 1) * 4] = bytes((0, 0, 0, 0))
                    continue
                # Cartridge shell dark indigo-violet
                r, g, b = 52, 46, 88
                # Grip ridges at top
                if 6 <= y <= 11 and 10 <= x < w - 10 and (y % 2 == 0):
                    r, g, b = 38, 33, 66
                # Label area in center
                elif 14 <= y <= 36 and 8 <= x < w - 8:
                    # Gradient purple-cyan label
                    t = (x - 8) / float(w - 16)
                    u = (y - 14) / 22.0
                    r = int(95 * (1 - t) + 35 * t)
                    g = int(60 * (1 - u) + 185 * u)
                    b = int(220 * (1 - t * 0.3))
                    # Inner screen stripe
                    if 16 <= y <= 20:
                        r, g, b = min(255, r + 40), min(255, g + 40), min(255, b + 30)
                # Bottom connector pins
                elif y >= 40 and 12 <= x < w - 12 and (x % 3 != 0):
                    r, g, b = 215, 175, 65
                rgba[(y * w + x) * 4 : (y * w + x + 1) * 4] = bytes((r, g, b, 255))
        write_png_rgba(icon_out_path, w, h, rgba)
        return icon_out_path
    except Exception:
        return ""


def extract_gba_metadata(rom_path, icon_out_path):
    meta = {"internal_title": "", "game_code": "", "icon": ""}
    try:
        ext = os.path.splitext(rom_path)[1].lower()
        with open(rom_path, "rb") as f:
            hdr = f.read(0x160)
            if ext in (".gba", ".agb") and len(hdr) >= 0xB4:
                raw_title = hdr[0xA0:0xAC].split(b"\x00")[0].decode("ascii", errors="ignore").strip()
                raw_code = hdr[0xAC:0xB0].split(b"\x00")[0].decode("ascii", errors="ignore").strip()
                if raw_title and all(32 <= ord(c) < 127 for c in raw_title):
                    meta["internal_title"] = raw_title
                if len(raw_code) == 4 and all(c.isalnum() for c in raw_code):
                    meta["game_code"] = f"AGB-{raw_code}"
                else:
                    meta["game_code"] = "AGB-HOME"
            elif ext in (".gb", ".gbc") and len(hdr) >= 0x150:
                raw_title = hdr[0x134:0x143].split(b"\x00")[0].decode("ascii", errors="ignore").strip()
                if raw_title:
                    meta["internal_title"] = raw_title
                meta["game_code"] = "DMG-CGB"
        meta["icon"] = generate_gba_badge_png(icon_out_path, meta["game_code"])
    except Exception:
        pass
    return meta


def format_size(num_bytes):
    if num_bytes < 1024:
        return f"{num_bytes} B"
    if num_bytes < 1024 * 1024:
        return f"{num_bytes / 1024.0:.0f} KB"
    if num_bytes < 1024 * 1024 * 1024:
        return f"{num_bytes / (1024.0 * 1024.0):.1f} MB"
    return f"{num_bytes / (1024.0 * 1024.0 * 1024.0):.2f} GB"


def find_bin(names):
    extra_paths = [
        os.path.join(HOME, ".nix-profile", "bin"),
        os.path.join(HOME, ".local", "bin"),
        "/run/current-system/sw/bin",
        "/usr/bin",
    ]
    for n in names:
        w = shutil.which(n)
        if w:
            return w
        for p in extra_paths:
            cand = os.path.join(p, n)
            if os.path.isfile(cand) and os.access(cand, os.X_OK):
                return cand
    return ""


def find_libretro_core(core_filename):
    candidates = [
        os.path.join(HOME, ".nix-profile", "lib", "retroarch", "cores", core_filename),
        os.path.join("/run/current-system/sw/lib/retroarch/cores", core_filename),
    ]
    for c in candidates:
        if os.path.exists(c):
            return os.path.realpath(c)
    # Fallback scan in /nix/store if needed
    try:
        for entry in os.listdir("/nix/store"):
            if "libretro-" in entry:
                cand = os.path.join("/nix/store", entry, "lib", "retroarch", "cores", core_filename)
                if os.path.exists(cand):
                    return cand
    except Exception:
        pass
    return ""


def get_engines_status():
    mgba_bin = find_bin(["mgba-qt", "mgba"])
    melonds_bin = find_bin(["melonDS", "melonds"])
    azahar_bin = find_bin(["azahar", "lime3ds", "citra-qt", "citra"])
    retroarch_bin = find_bin(["retroarch"])

    mgba_core = find_libretro_core("mgba_libretro.so")
    melonds_core = find_libretro_core("melonds_libretro.so")
    desmume_core = find_libretro_core("desmume_libretro.so")
    citra_core = find_libretro_core("citra_libretro.so")

    return {
        "mgba": {"installed": bool(mgba_bin), "bin": mgba_bin, "core": mgba_core, "in_island": bool(mgba_core)},
        "melonds": {"installed": bool(melonds_bin), "bin": melonds_bin, "core": melonds_core or desmume_core, "in_island": bool(melonds_core or desmume_core)},
        "azahar": {"installed": bool(azahar_bin), "bin": azahar_bin, "core": citra_core, "in_island": False},
        "retroarch": {"installed": bool(retroarch_bin), "bin": retroarch_bin}
    }


def scan_roms(st):
    ensure_dirs()
    dirs = []
    for d in DEFAULT_ROM_DIRS + st.get("custom_dirs", []):
        rp = os.path.expanduser(d)
        if os.path.isdir(rp) and rp not in dirs:
            dirs.append(rp)

    seen_paths = set()
    roms = []
    favs = set(st.get("favorites", []))
    recents = st.get("recent", [])

    for base_dir in dirs:
        # For ~/Downloads, only scan top-level so we don't recurse deeply into unrelated trees
        max_depth = 1 if base_dir.endswith("Downloads") else 3
        for root, subdirs, files in os.walk(base_dir):
            rel = os.path.relpath(root, base_dir)
            depth = 0 if rel == "." else rel.count(os.sep) + 1
            if depth >= max_depth:
                subdirs[:] = []
            # Skip hidden folders
            subdirs[:] = [sd for sd in subdirs if not sd.startswith(".")]
            for fname in files:
                ext = os.path.splitext(fname)[1].lower()
                if ext not in ROM_EXTENSIONS:
                    continue
                full_path = os.path.realpath(os.path.join(root, fname))
                if full_path in seen_paths:
                    continue
                seen_paths.add(full_path)
                try:
                    stat = os.stat(full_path)
                except OSError:
                    continue

                platform = ROM_EXTENSIONS[ext]
                stem = os.path.splitext(fname)[0]
                clean_name = stem.replace("_", " ").replace(".", " ").strip()
                icon_key = f"{platform.lower()}_{stem}_{stat.st_size}.png"
                icon_path = os.path.join(ICONS_DIR, icon_key)

                meta = {"internal_title": "", "game_code": "", "icon": ""}
                if platform == "GBA":
                    meta = extract_gba_metadata(full_path, icon_path)
                elif platform == "NDS":
                    meta = extract_nds_metadata(full_path, icon_path)
                elif platform == "3DS":
                    meta = extract_3ds_metadata(full_path, icon_path)

                # Count save states for this ROM
                slots = []
                for s in range(1, 5):
                    st_file = os.path.join(STATES_DIR, f"{stem}_slot{s}.state")
                    bmp_file = os.path.join(STATES_DIR, f"{stem}_slot{s}.bmp")
                    if os.path.exists(st_file):
                        slots.append({
                            "slot": s,
                            "mtime": int(os.path.getmtime(st_file)),
                            "preview": bmp_file if os.path.exists(bmp_file) else ""
                        })

                sram_file = os.path.join(SAVES_DIR, f"{stem}.sav")
                has_sram = os.path.exists(sram_file)

                rec_rank = recents.index(full_path) if full_path in recents else 999

                roms.append({
                    "path": full_path,
                    "filename": fname,
                    "stem": stem,
                    "title": clean_name,
                    "internal_title": meta.get("internal_title") or clean_name,
                    "game_code": meta.get("game_code") or platform,
                    "platform": platform,
                    "ext": ext.upper().lstrip("."),
                    "size": stat.st_size,
                    "size_str": format_size(stat.st_size),
                    "icon": meta.get("icon") or "",
                    "favorite": full_path in favs,
                    "recent_rank": rec_rank,
                    "can_in_island": platform in ("GBA", "NDS"),
                    "states_count": len(slots),
                    "states": slots,
                    "has_sram": has_sram,
                })

    roms.sort(key=lambda r: (0 if r["favorite"] else 1, r["recent_rank"], r["title"].lower()))
    return roms


def apply_azahar_config(cfg3ds):
    """Sync Zenith 3DS settings directly into Azahar's qt-config.ini."""
    az_dir = os.path.join(HOME, ".config", "azahar-emu")
    os.makedirs(az_dir, exist_ok=True)
    ini_path = os.path.join(az_dir, "qt-config.ini")

    res_factor = int(cfg3ds.get("resolution_factor", 3))
    gfx_api = int(cfg3ds.get("graphics_api", 2))
    layout_opt = int(cfg3ds.get("layout_option", 0))

    lines = []
    if os.path.exists(ini_path):
        try:
            with open(ini_path, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.read().splitlines()
        except Exception:
            lines = []

    overrides = {
        "resolution_factor": str(res_factor),
        "resolution_factor\\default": "false",
        "graphics_api": str(gfx_api),
        "graphics_api\\default": "false",
        "layout_option": str(layout_opt),
        "layout_option\\default": "false",
        "async_shader_compilation": "true",
        "async_shader_compilation\\default": "false",
    }

    in_renderer = False
    found_renderer = False
    out_lines = []
    written_keys = set()

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if in_renderer:
                for k, v in overrides.items():
                    if k not in written_keys:
                        out_lines.append(f"{k}={v}")
                        written_keys.add(k)
            in_renderer = (stripped.lower() == "[renderer]" or stripped.lower() == "[layout]")
            if stripped.lower() == "[renderer]":
                found_renderer = True
            out_lines.append(line)
            continue

        if "=" in stripped:
            k = stripped.split("=", 1)[0].strip()
            if k in overrides:
                out_lines.append(f"{k}={overrides[k]}")
                written_keys.add(k)
                continue
        out_lines.append(line)

    if not found_renderer:
        out_lines.append("\n[Renderer]")
        for k, v in overrides.items():
            if k not in written_keys:
                out_lines.append(f"{k}={v}")
    else:
        for k, v in overrides.items():
            if k not in written_keys:
                out_lines.append(f"{k}={v}")

    try:
        with open(ini_path, "w", encoding="utf-8") as f:
            f.write("\n".join(out_lines) + "\n")
    except Exception:
        pass


def remember_recent(st, rom_path):
    rec = [p for p in st.get("recent", []) if p != rom_path]
    rec.insert(0, rom_path)
    st["recent"] = rec[:30]
    save_state(st)


def launch_standalone(rom_path, fullscreen=False):
    st = load_state()
    remember_recent(st, rom_path)
    engines = get_engines_status()
    ext = os.path.splitext(rom_path)[1].lower()
    platform = ROM_EXTENSIONS.get(ext, "GBA")

    cfg3ds = st.get("3ds_config", {})
    use_fs = fullscreen or bool(cfg3ds.get("fullscreen", False))

    cmd = []
    if platform == "GBA":
        bin_path = engines["mgba"]["bin"]
        if bin_path:
            cmd = [bin_path]
            if use_fs:
                cmd.append("-f")
            else:
                cmd.extend(["-4"])
            cmd.append(rom_path)
    elif platform == "NDS":
        bin_path = engines["melonds"]["bin"]
        if bin_path:
            cmd = [bin_path]
            if use_fs:
                cmd.append("-f")
            cmd.append(rom_path)
    elif platform == "3DS":
        apply_azahar_config(cfg3ds)
        bin_path = engines["azahar"]["bin"]
        if bin_path:
            cmd = [bin_path]
            if ext == ".cia":
                cmd.extend(["-i", rom_path])
            else:
                if use_fs:
                    cmd.append("-f")
                else:
                    cmd.append("-w")
                cmd.append(rom_path)

    if not cmd:
        return {"ok": False, "error": f"Motor para {platform} não encontrado."}

    env = os.environ.copy()
    subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        env=env
    )
    return {"ok": True, "platform": platform, "cmd": cmd}


def get_catalog_with_status():
    items = []
    for entry in HOMEBREW_CATALOG:
        plat = entry["platform"]
        dest_dir = os.path.join(HOME, "ROMs", plat)
        dest_path = os.path.join(dest_dir, entry["filename"])
        item = dict(entry)
        item["installed"] = os.path.exists(dest_path)
        item["local_path"] = dest_path if item["installed"] else ""
        items.append(item)
    return items


def download_homebrew(item_id):
    ensure_dirs()
    target = next((x for x in HOMEBREW_CATALOG if x["id"] == item_id), None)
    if not target:
        return {"ok": False, "error": "Item não encontrado no catálogo"}

    dest_dir = os.path.join(HOME, "ROMs", target["platform"])
    os.makedirs(dest_dir, exist_ok=True)
    dest_path = os.path.join(dest_dir, target["filename"])

    try:
        req = urllib.request.Request(target["url"], headers={"User-Agent": "Zenith-Emulator/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
        with open(dest_path, "wb") as f:
            f.write(data)
        return {"ok": True, "path": dest_path, "id": item_id}
    except Exception as e:
        return {"ok": False, "error": str(e), "id": item_id}


def main():
    ensure_dirs()
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    st = load_state()

    if cmd == "all":
        roms = scan_roms(st)
        engines = get_engines_status()
        catalog = get_catalog_with_status()
        print(json.dumps({
            "roms": roms,
            "engines": engines,
            "catalog": catalog,
            "state": st,
            "rom_dirs": DEFAULT_ROM_DIRS[:4] + st.get("custom_dirs", []),
        }, ensure_ascii=False))

    elif cmd == "toggle_fav":
        rom_path = os.path.realpath(sys.argv[2]) if len(sys.argv) > 2 else ""
        favs = st.get("favorites", [])
        if rom_path in favs:
            favs.remove(rom_path)
        elif rom_path:
            favs.append(rom_path)
        st["favorites"] = favs
        save_state(st)
        print(json.dumps({"ok": True, "favorites": favs}))

    elif cmd in ("launch", "launch_standalone"):
        rom_path = os.path.realpath(sys.argv[2]) if len(sys.argv) > 2 else ""
        fullscreen = (len(sys.argv) > 3 and sys.argv[3] == "fullscreen")
        res = launch_standalone(rom_path, fullscreen=fullscreen)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "set_3ds_config":
        key = sys.argv[2] if len(sys.argv) > 2 else ""
        val = sys.argv[3] if len(sys.argv) > 3 else ""
        cfg3ds = st.get("3ds_config", {})
        if key in ("resolution_factor", "graphics_api", "layout_option"):
            cfg3ds[key] = int(val)
        elif key in ("auto_gamemode", "fullscreen"):
            cfg3ds[key] = (val.lower() in ("1", "true", "yes", "on"))
        st["3ds_config"] = cfg3ds
        save_state(st)
        apply_azahar_config(cfg3ds)
        print(json.dumps({"ok": True, "3ds_config": cfg3ds}))

    elif cmd == "set_ds_layout":
        layout = sys.argv[2] if len(sys.argv) > 2 else "Top/Bottom"
        st["ds_layout"] = layout
        save_state(st)
        print(json.dumps({"ok": True, "ds_layout": layout}))

    elif cmd == "download_homebrew":
        item_id = sys.argv[2] if len(sys.argv) > 2 else ""
        res = download_homebrew(item_id)
        print(json.dumps(res, ensure_ascii=False))

    elif cmd == "add_dir":
        new_dir = os.path.expanduser(sys.argv[2]) if len(sys.argv) > 2 else ""
        if os.path.isdir(new_dir):
            cdirs = st.get("custom_dirs", [])
            if new_dir not in cdirs:
                cdirs.append(new_dir)
            st["custom_dirs"] = cdirs
            save_state(st)
            print(json.dumps({"ok": True, "custom_dirs": cdirs}))
        else:
            print(json.dumps({"ok": False, "error": "Diretório inválido"}))

    elif cmd == "open_engine":
        eng = sys.argv[2] if len(sys.argv) > 2 else ""
        engines = get_engines_status()
        if eng in engines and engines[eng].get("bin"):
            if eng == "azahar":
                apply_azahar_config(st.get("3ds_config", {}))
            subprocess.Popen([engines[eng]["bin"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            print(json.dumps({"ok": True}))
        else:
            print(json.dumps({"ok": False, "error": "Executável não encontrado"}))


if __name__ == "__main__":
    main()
