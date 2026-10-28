#!/usr/bin/env python3
"""
Panacea Equalizer Service
Manages an 8-band graphic equalizer using PipeWire's builtin biquad filters.
Provides instantaneous real-time gain adjustments via pw-cli SPA props.
"""

import sys
import os
import time
import json
import signal
import re
import subprocess

CONFIG_DIR = os.path.expanduser("~/.config/zenith")
CONF_PATH = os.path.join(CONFIG_DIR, "eq.conf")
PID_PATH = os.path.join(CONFIG_DIR, "eq.pid")
PREV_SINK_PATH = os.path.join(CONFIG_DIR, "eq_prev_sink.txt")
STATE_PATH = os.path.join(CONFIG_DIR, "eq_state.json")

FREQS = [60.0, 150.0, 400.0, 1000.0, 2400.0, 6000.0, 12000.0, 16000.0]
PRESETS = {
    "Flat": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "Bass Boost": [6.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0],
    "Treble Boost": [0.0, 0.0, 0.0, 1.0, 2.0, 4.0, 6.0, 7.0],
    "Vocal": [-2.0, -1.0, 2.0, 4.0, 3.0, 1.0, 0.0, -1.0],
    "Rock": [5.0, 3.0, -1.0, -2.0, 1.0, 3.0, 5.0, 5.0],
    "Pop": [1.0, 2.0, 4.0, 3.0, 0.0, 2.0, 3.0, 2.0],
    "Electronic": [6.0, 5.0, 2.0, 0.0, 1.0, 3.0, 5.0, 6.0],
    "Acoustic": [3.0, 2.0, 1.0, 2.0, 3.0, 3.0, 2.0, 1.0]
}

def find_matching_preset(gains):
    for pname, pvals in PRESETS.items():
        if all(abs(float(g) - float(pv)) < 0.05 for g, pv in zip(gains, pvals)):
            return pname
    return "Custom"

def get_state():
    state = {}
    if os.path.exists(STATE_PATH):
        try:
            with open(STATE_PATH, "r") as f:
                state = json.load(f)
        except Exception:
            pass
    if not state.get("gains") and os.path.exists(CONF_PATH):
        try:
            with open(CONF_PATH, "r") as f:
                content = f.read()
            gains = []
            for m in re.finditer(r'"Gain"\s*=\s*([-+]?\d*\.?\d+)', content):
                gains.append(float(m.group(1)))
            if len(gains) == 8:
                state["gains"] = gains
                state["preset"] = find_matching_preset(gains)
        except Exception:
            pass
    return state

def clean_gain_values(gains):
    clean = []
    for i in range(8):
        try:
            val = float(gains[i])
        except (IndexError, TypeError, ValueError):
            val = 0.0
        clean.append(max(-12.0, min(12.0, val)))
    return clean

def generate_conf(gains):
    clean_gains = clean_gain_values(gains)
    nodes = []
    links = []
    for i, freq in enumerate(FREQS):
        name = f"eq_band_{i+1}"
        if i == 0:
            label = "bq_lowshelf"
        elif i == len(FREQS) - 1:
            label = "bq_highshelf"
        else:
            label = "bq_peaking"

        gain = clean_gains[i]
        nodes.append(f'                    {{ type = builtin name = {name} label = {label} control = {{ "Freq" = {freq} "Q" = 1.0 "Gain" = {gain:.2f} }} }}')
        if i > 0:
            prev_name = f"eq_band_{i}"
            links.append(f'                    {{ output = "{prev_name}:Out" input = "{name}:In" }}')

    nodes_str = "\n".join(nodes)
    links_str = "\n".join(links)

    return f"""context.modules = [
    {{ name = libpipewire-module-protocol-native }}
    {{ name = libpipewire-module-client-node }}
    {{ name = libpipewire-module-adapter }}
    {{ name = libpipewire-module-filter-chain
        args = {{
            node.description = "Panacea Equalizer"
            media.name       = "Panacea Equalizer"
            filter.graph = {{
                nodes = [
{nodes_str}
                ]
                links = [
{links_str}
                ]
            }}
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {{
                node.name        = "effect_input.panacea_eq"
                node.description = "Panacea Equalizer"
                media.class      = Audio/Sink
            }}
            playback.props = {{
                node.name        = "effect_output.panacea_eq"
                node.passive     = true
            }}
        }}
    }}
]
"""

def get_default_hw_sink():
    try:
        out = subprocess.check_output(["wpctl", "status"], text=True, timeout=1.0)
    except Exception:
        return None
    lines = out.splitlines()
    in_audio = False
    in_sinks = False
    def_sink = None
    first_sink = None
    for line in lines:
        if line.strip() == "Audio":
            in_audio = True
            continue
        if in_audio:
            if line.strip() == "Video":
                break
            if "Sinks:" in line:
                in_sinks = True
                continue
            if in_sinks:
                if "Sources:" in line or "Filters:" in line:
                    break
                m = re.search(r'(\d+)\.\s+(.+?)(?:\[|$)', line)
                if m:
                    nid = m.group(1)
                    name = m.group(2).strip()
                    if "panacea_eq" not in name.lower() and "equalizer" not in name.lower():
                        if "*" in line:
                            def_sink = nid
                        if not first_sink:
                            first_sink = nid
    return def_sink or first_sink

def find_eq_node():
    try:
        out = subprocess.check_output(["pw-dump", "Node"], text=True, timeout=1.0)
        nodes = json.loads(out)
        for n in nodes:
            props = n.get("info", {}).get("props", {})
            if props.get("node.name") == "effect_input.panacea_eq":
                return str(n.get("id"))
    except Exception:
        pass
    return None

def is_running():
    if not os.path.exists(PID_PATH):
        return False
    try:
        with open(PID_PATH, "r") as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)
        return pid
    except Exception:
        if os.path.exists(PID_PATH):
            try: os.remove(PID_PATH)
            except OSError: pass
        return False

def link_active_streams():
    """Ensure active audio playback applications are connected to Panacea Equalizer"""
    try:
        out = subprocess.check_output(["pw-link", "-o"], text=True, timeout=1.0)
        for line in out.splitlines():
            line = line.strip()
            if ":output_FL" in line and "panacea_eq" not in line and "alsa" not in line and "cava" not in line:
                app_prefix = line.split(":output_FL")[0]
                subprocess.run(["pw-link", f"{app_prefix}:output_FL", "effect_input.panacea_eq:playback_FL"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.5)
                subprocess.run(["pw-link", f"{app_prefix}:output_FR", "effect_input.panacea_eq:playback_FR"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.5)
    except Exception:
        pass

def stop_eq():
    pid = is_running()
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
            time.sleep(0.05)
        except OSError:
            pass
    if os.path.exists(PID_PATH):
        try: os.remove(PID_PATH)
        except OSError: pass

    # Restore default hardware sink
    saved_sink = None
    if os.path.exists(PREV_SINK_PATH):
        try:
            with open(PREV_SINK_PATH, "r") as f:
                saved_sink = f.read().strip()
            os.remove(PREV_SINK_PATH)
        except OSError:
            pass

    restore_id = saved_sink or get_default_hw_sink()
    if restore_id:
        try:
            subprocess.run(["wpctl", "set-default", str(restore_id)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.0)
        except Exception:
            pass

    print(json.dumps({"status": "stopped"}))

def apply_eq(gains, preset="Custom"):
    os.makedirs(CONFIG_DIR, exist_ok=True)
    clean_gains = clean_gain_values(gains)

    # Determine preset if Custom
    actual_preset = preset
    if actual_preset == "Custom" or not actual_preset:
        actual_preset = find_matching_preset(clean_gains)

    # Save state to eq_state.json
    try:
        with open(STATE_PATH, "w") as f:
            json.dump({"gains": clean_gains, "preset": actual_preset}, f)
    except OSError:
        pass

    # Save previous hardware sink before activating equalizer
    if not os.path.exists(PREV_SINK_PATH):
        hw_sink = get_default_hw_sink()
        if hw_sink:
            try:
                with open(PREV_SINK_PATH, "w") as f:
                    f.write(str(hw_sink))
            except OSError:
                pass

    conf_content = generate_conf(clean_gains)
    with open(CONF_PATH, "w") as f:
        f.write(conf_content)

    pid = is_running()
    eq_node_id = find_eq_node() if pid else None

    # FAST REAL-TIME PATH: If equalizer is already active, adjust biquad gains via pw-cli (<10ms)
    if pid and eq_node_id:
        params_items = []
        for i, g in enumerate(clean_gains):
            params_items.append(f'"eq_band_{i+1}:Gain" {g:.2f}')
        params_str = " ".join(params_items)
        try:
            subprocess.run(
                ["pw-cli", "s", eq_node_id, "Props", f"{{ params = [ {params_str} ] }}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=0.5
            )
            # Ensure it is default sink
            subprocess.run(["wpctl", "set-default", str(eq_node_id)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.5)
            link_active_streams()
            print(json.dumps({"status": "applied", "runtime": True, "pid": pid, "node": eq_node_id, "preset": actual_preset}))
            return
        except Exception:
            pass # Fall back to full launch if pw-cli failed

    # COLD START PATH: Launch pipewire client with filter-chain
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
            time.sleep(0.04)
        except OSError:
            pass

    proc = subprocess.Popen(
        ["pipewire", "-c", CONF_PATH],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    with open(PID_PATH, "w") as f:
        f.write(str(proc.pid))

    # Fast polling for node (using pw-dump Node, ~15ms per check)
    start = time.time()
    eq_node_id = None
    while time.time() - start < 1.5:
        eq_node_id = find_eq_node()
        if eq_node_id:
            break
        time.sleep(0.02)

    if eq_node_id:
        try:
            subprocess.run(["wpctl", "set-default", str(eq_node_id)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=0.8)
        except Exception:
            pass
        link_active_streams()

    print(json.dumps({"status": "applied", "runtime": False, "pid": proc.pid, "node": eq_node_id, "preset": actual_preset}))

def main():
    if len(sys.argv) < 2:
        print("Usage: equalizer.py apply '<json_gains>' [preset] | stop | status | presets")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "stop":
        stop_eq()
    elif cmd == "status":
        pid = is_running()
        node = find_eq_node() if pid else None
        running = bool(pid and node)
        state = get_state()
        res = {
            "running": running,
            "pid": pid if pid else None,
            "node": node,
            "gains": state.get("gains", [0.0] * 8),
            "preset": state.get("preset", "Flat")
        }
        print(json.dumps(res))
    elif cmd == "presets":
        print(json.dumps(PRESETS))
    elif cmd == "apply":
        gains = [0.0] * 8
        preset = "Custom"
        if len(sys.argv) > 2:
            try:
                gains = json.loads(sys.argv[2])
            except Exception:
                pass
        if len(sys.argv) > 3:
            preset = sys.argv[3]
        apply_eq(gains, preset)
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)

if __name__ == "__main__":
    main()
