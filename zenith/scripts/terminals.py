#!/usr/bin/env python3
import os
import sys
import json
import signal
import shutil
import subprocess
import time
import uuid

CONFIG_DIR = os.path.expanduser("~/.config/zenith")
TASKS_FILE = os.path.join(CONFIG_DIR, "terminals.json")
STATE_DIR = os.path.expanduser("~/.local/state/zenith/terminals")
SYSTEMD_USER_DIR = os.path.expanduser("~/.config/systemd/user")

os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(STATE_DIR, exist_ok=True)
os.makedirs(SYSTEMD_USER_DIR, exist_ok=True)

def unit_name_for(task_id):
    return f"zenith-svc-{task_id}.service"

def load_tasks():
    if not os.path.exists(TASKS_FILE):
        return []
    try:
        with open(TASKS_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return []

def save_tasks(tasks):
    with open(TASKS_FILE, "w") as f:
        json.dump(tasks, f, indent=2)

def is_pid_running(pid):
    if not pid or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False

def get_proc_stats(pid):
    if not is_pid_running(pid):
        return 0.0, 0.0
    cpu = 0.0
    mem_mb = 0.0
    try:
        res = subprocess.run(["ps", "-p", str(pid), "-o", "%cpu,rss", "--no-headers"],
                             capture_output=True, text=True, timeout=1)
        out = res.stdout.strip().split()
        if len(out) >= 2:
            cpu = float(out[0].replace(",", "."))
            mem_mb = round(int(out[1]) / 1024.0, 1)
    except Exception:
        pass
    return cpu, mem_mb

def get_task_status(task):
    task_id = task.get("id")
    pid_file = os.path.join(STATE_DIR, f"{task_id}.pid")
    log_file = os.path.join(STATE_DIR, f"{task_id}.log")
    time_file = os.path.join(STATE_DIR, f"{task_id}.time")

    pid = None
    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                pid = int(f.read().strip())
        except Exception:
            pid = None

    running = is_pid_running(pid)

    # Also check systemd status
    unit_name = unit_name_for(task_id)
    if shutil.which("systemctl"):
        try:
            res = subprocess.run(["systemctl", "--user", "show", unit_name,
                                  "--property=MainPID,ActiveState"],
                                 capture_output=True, text=True, timeout=1)
            props = dict(l.split("=", 1) for l in res.stdout.strip().split("\n") if "=" in l)
            if props.get("ActiveState") == "active":
                running = True
                s_pid = props.get("MainPID")
                if s_pid and s_pid.isdigit() and int(s_pid) > 0:
                    pid = int(s_pid)
            elif props.get("ActiveState") in ("inactive", "failed") and not is_pid_running(pid):
                running = False
                pid = None
        except Exception:
            pass

    cpu, mem_mb = (0.0, 0.0)
    uptime_sec = 0
    if running and pid:
        cpu, mem_mb = get_proc_stats(pid)
        if os.path.exists(time_file):
            try:
                with open(time_file, "r") as f:
                    start_t = float(f.read().strip())
                    uptime_sec = max(0, int(time.time() - start_t))
            except Exception:
                pass
        status = "running"
    else:
        status = "stopped"
        pid = None

    h = uptime_sec // 3600
    m = (uptime_sec % 3600) // 60
    s = uptime_sec % 60
    uptime_str = f"UP {h:02d}:{m:02d}:{s:02d}"

    # Last log line
    last_line = ""
    if os.path.exists(log_file):
        try:
            with open(log_file, "rb") as f:
                f.seek(0, os.SEEK_END)
                size = f.tell()
                read_size = min(size, 8192)
                f.seek(size - read_size, os.SEEK_SET)
                lines = [l.strip() for l in f.read().decode("utf-8", errors="replace").split("\n") if l.strip()]
                content_lines = [l for l in lines if not l.startswith("--- [")]
                if content_lines:
                    last_line = content_lines[-1]
                elif lines:
                    last_line = lines[-1]
        except Exception:
            pass

    return {
        "id": task_id,
        "name": task.get("name", "Task"),
        "dir": task.get("dir", os.path.expanduser("~")),
        "cmd": task.get("cmd", ""),
        "port": str(task.get("port", "")),
        "autostart": bool(task.get("autostart", False)),
        "autorestart": bool(task.get("autorestart", False)),
        "status": status,
        "pid": pid or 0,
        "cpu": cpu,
        "mem_mb": mem_mb,
        "uptime": uptime_sec,
        "uptime_str": uptime_str,
        "last_line": last_line
    }

def start_task(task_id):
    tasks = load_tasks()
    task = next((t for t in tasks if t.get("id") == task_id), None)
    if not task:
        return {"success": False, "error": "Task not found"}

    pid_file = os.path.join(STATE_DIR, f"{task_id}.pid")
    log_file = os.path.join(STATE_DIR, f"{task_id}.log")
    time_file = os.path.join(STATE_DIR, f"{task_id}.time")

    cwd = os.path.expanduser(task.get("dir") or "~")
    if not os.path.isdir(cwd):
        try:
            os.makedirs(cwd, exist_ok=True)
        except Exception:
            cwd = os.path.expanduser("~")

    cmd_str = task.get("cmd", "")
    if not cmd_str.strip():
        return {"success": False, "error": "Empty command"}

    name = task.get("name", "Task")
    port = str(task.get("port", "")).strip()
    env_prefix = f"export PORT='{port}'; " if port else ""
    full_cmd = f"{env_prefix}{cmd_str}"

    log_fd = open(log_file, "a")
    timestamp = time.strftime("[%Y-%m-%d %H:%M:%S]")
    log_fd.write(f"\n--- {timestamp} Starting: {full_cmd} (in {cwd}) ---\n")
    log_fd.flush()
    log_fd.close()

    unit_name = unit_name_for(task_id)
    unit_path = os.path.join(SYSTEMD_USER_DIR, unit_name)

    escaped_cmd = full_cmd.replace('"', '\\"')
    unit_content = f"""[Unit]
Description=Zenith Service {name}
After=network.target

[Service]
Type=simple
WorkingDirectory={cwd}
ExecStart=/bin/sh -c "{escaped_cmd}"
Restart={'always' if task.get('autorestart') else 'no'}
StandardOutput=append:{log_file}
StandardError=append:{log_file}

[Install]
WantedBy=default.target
"""
    has_systemctl = shutil.which("systemctl") is not None
    started_systemd = False
    pid = None

    if has_systemctl:
        try:
            with open(unit_path, "w") as f:
                f.write(unit_content)
            subprocess.run(["systemctl", "--user", "daemon-reload"], capture_output=True, timeout=3)
            res = subprocess.run(["systemctl", "--user", "restart", unit_name], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                started_systemd = True
                p_show = subprocess.run(["systemctl", "--user", "show", unit_name, "--property=MainPID,ActiveState"],
                                        capture_output=True, text=True, timeout=3)
                for line in p_show.stdout.strip().split("\n"):
                    if line.startswith("MainPID="):
                        val = line.split("=", 1)[1].strip()
                        if val.isdigit() and int(val) > 0:
                            pid = int(val)
        except Exception:
            started_systemd = False

    if not started_systemd or not pid:
        try:
            log_fd = open(log_file, "a")
            proc = subprocess.Popen(
                ["sh", "-c", full_cmd],
                cwd=cwd,
                stdout=log_fd,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
                start_new_session=True
            )
            pid = proc.pid
        except Exception as e:
            return {"success": False, "error": str(e)}

    if pid:
        with open(pid_file, "w") as f:
            f.write(str(pid))
        with open(time_file, "w") as f:
            f.write(str(time.time()))

    return {"success": True, "pid": pid or 0, "systemd": started_systemd}

def stop_task(task_id):
    unit_name = unit_name_for(task_id)
    if shutil.which("systemctl"):
        try:
            subprocess.run(["systemctl", "--user", "stop", unit_name], capture_output=True, timeout=5)
        except Exception:
            pass

    pid_file = os.path.join(STATE_DIR, f"{task_id}.pid")
    log_file = os.path.join(STATE_DIR, f"{task_id}.log")
    time_file = os.path.join(STATE_DIR, f"{task_id}.time")

    if os.path.exists(pid_file):
        try:
            with open(pid_file, "r") as f:
                pid = int(f.read().strip())
            if pid and is_pid_running(pid):
                try:
                    os.killpg(os.getpgid(pid), signal.SIGTERM)
                except Exception:
                    try:
                        os.kill(pid, signal.SIGTERM)
                    except Exception:
                        pass
                for _ in range(5):
                    if not is_pid_running(pid):
                        break
                    time.sleep(0.1)
                if is_pid_running(pid):
                    try:
                        os.killpg(os.getpgid(pid), signal.SIGKILL)
                    except Exception:
                        try:
                            os.kill(pid, signal.SIGKILL)
                        except Exception:
                            pass
        except Exception:
            pass

    try: os.remove(pid_file)
    except Exception: pass
    try: os.remove(time_file)
    except Exception: pass

    if os.path.exists(log_file):
        try:
            with open(log_file, "a") as f:
                f.write(f"\n--- [{time.strftime('%Y-%m-%d %H:%M:%S')}] Stopped ---\n")
        except Exception:
            pass

    return {"success": True, "status": "stopped"}

def get_logs(task_id, max_lines=200):
    log_file = os.path.join(STATE_DIR, f"{task_id}.log")
    if not os.path.exists(log_file):
        return ""
    try:
        res = subprocess.run(["tail", "-n", str(max_lines), log_file],
                             capture_output=True, text=True)
        return res.stdout
    except Exception as e:
        return f"Error reading logs: {e}"

def clear_logs(task_id):
    log_file = os.path.join(STATE_DIR, f"{task_id}.log")
    try:
        with open(log_file, "w") as f:
            f.truncate(0)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

def main():
    if len(sys.argv) < 2:
        cmd = "list"
    else:
        cmd = sys.argv[1]

    if cmd == "list":
        tasks = load_tasks()
        results = [get_task_status(t) for t in tasks]
        print(json.dumps(results))

    elif cmd == "start":
        if len(sys.argv) > 2:
            print(json.dumps(start_task(sys.argv[2])))
        else:
            print(json.dumps({"success": False, "error": "Missing task ID"}))

    elif cmd == "stop":
        if len(sys.argv) > 2:
            print(json.dumps(stop_task(sys.argv[2])))
        else:
            print(json.dumps({"success": False, "error": "Missing task ID"}))

    elif cmd == "restart":
        if len(sys.argv) > 2:
            task_id = sys.argv[2]
            stop_task(task_id)
            time.sleep(0.2)
            print(json.dumps(start_task(task_id)))
        else:
            print(json.dumps({"success": False, "error": "Missing task ID"}))

    elif cmd == "logs":
        if len(sys.argv) > 2:
            lines = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 200
            print(get_logs(sys.argv[2], lines))
        else:
            print("")

    elif cmd == "clear_logs":
        if len(sys.argv) > 2:
            print(json.dumps(clear_logs(sys.argv[2])))
        else:
            print(json.dumps({"success": False, "error": "Missing task ID"}))

    elif cmd == "add":
        # add <name> <dir> <cmd> [port] [autorestart] [autostart]
        name = sys.argv[2] if len(sys.argv) > 2 else "Task"
        wdir = sys.argv[3] if len(sys.argv) > 3 else "~"
        command = sys.argv[4] if len(sys.argv) > 4 else ""
        port = ""
        autorestart = False
        autostart = False

        if len(sys.argv) > 5:
            if sys.argv[5].isdigit():
                port = sys.argv[5]
                if len(sys.argv) > 6:
                    autorestart = sys.argv[6].lower() in ("true", "1")
                if len(sys.argv) > 7:
                    autostart = sys.argv[7].lower() in ("true", "1")
            else:
                autorestart = sys.argv[5].lower() in ("true", "1")
                if len(sys.argv) > 6:
                    autostart = sys.argv[6].lower() in ("true", "1")

        tasks = load_tasks()
        task_id = str(uuid.uuid4())[:8]
        new_task = {
            "id": task_id,
            "name": name,
            "dir": wdir,
            "cmd": command,
            "port": port,
            "autorestart": autorestart,
            "autostart": autostart
        }
        tasks.append(new_task)
        save_tasks(tasks)
        print(json.dumps({"success": True, "task": new_task}))

    elif cmd == "edit":
        if len(sys.argv) > 2:
            task_id = sys.argv[2]
            tasks = load_tasks()
            task = next((t for t in tasks if t.get("id") == task_id), None)
            if task:
                if len(sys.argv) > 3: task["name"] = sys.argv[3]
                if len(sys.argv) > 4: task["dir"] = sys.argv[4]
                if len(sys.argv) > 5: task["cmd"] = sys.argv[5]
                if len(sys.argv) > 6: task["port"] = sys.argv[6]
                save_tasks(tasks)
                print(json.dumps({"success": True, "task": task}))
            else:
                print(json.dumps({"success": False, "error": "Task not found"}))
        else:
            print(json.dumps({"success": False, "error": "Missing task ID"}))

    elif cmd == "delete":
        if len(sys.argv) > 2:
            task_id = sys.argv[2]
            stop_task(task_id)
            unit_path = os.path.join(SYSTEMD_USER_DIR, unit_name_for(task_id))
            if os.path.exists(unit_path):
                try: os.remove(unit_path)
                except Exception: pass
                if shutil.which("systemctl"):
                    try: subprocess.run(["systemctl", "--user", "daemon-reload"], capture_output=True, timeout=3)
                    except Exception: pass

            tasks = load_tasks()
            tasks = [t for t in tasks if t.get("id") != task_id]
            save_tasks(tasks)
            for f in [f"{task_id}.pid", f"{task_id}.log", f"{task_id}.time"]:
                try: os.remove(os.path.join(STATE_DIR, f))
                except Exception: pass
            print(json.dumps({"success": True, "deleted": task_id}))
        else:
            print(json.dumps({"success": False, "error": "Missing task ID"}))

    elif cmd == "autostart_all":
        tasks = load_tasks()
        started = []
        for t in tasks:
            if t.get("autostart"):
                res = start_task(t.get("id"))
                started.append({"id": t.get("id"), "res": res})
        print(json.dumps({"started": started}))

    elif cmd == "scan_scripts":
        home = os.path.expanduser("~")
        dirs = [
            home,
            os.path.join(home, "dev"),
            os.path.join(home, "projects"),
            os.path.join(home, "scripts"),
            os.path.join(home, "Zenith"),
            os.path.join(home, "Downloads")
        ]
        found = []
        seen = set()
        for d in dirs:
            if not os.path.isdir(d):
                continue
            try:
                for root, dirnames, files in os.walk(d):
                    dirnames[:] = [x for x in dirnames if not x.startswith(".") and x not in ("node_modules", "target", "dist", ".git")]
                    depth = root[len(d):].count(os.sep)
                    if depth > 2:
                        continue
                    for f in files:
                        if f.endswith(".sh"):
                            p = os.path.join(root, f)
                            if p not in seen:
                                seen.add(p)
                                found.append({
                                    "path": p,
                                    "name": f,
                                    "dir": root
                                })
            except Exception:
                pass
        print(json.dumps(found[:30]))

    else:
        print("Unknown command", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
