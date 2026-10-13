#!/usr/bin/env python3
import os
import sys
import json
import time
import shutil
import socket
import subprocess
import urllib.request
import shlex

PULL_STATUS_FILE = "/tmp/zenith-docker-pull.json"
PULL_LOG_FILE = "/tmp/zenith-docker-pull.log"
BUILD_STATUS_FILE = "/tmp/zenith-docker-build.json"
BUILD_LOG_FILE = "/tmp/zenith-docker-build.log"
STATS_CACHE_FILE = "/tmp/zenith-docker-stats.json"

def get_cli():
    if shutil.which("docker"):
        return "docker"
    if shutil.which("podman"):
        return "podman"
    return None

def check_daemon(cli):
    if not cli:
        return False, "Docker / Podman não encontrado no sistema"

    # Fast check via UNIX domain socket for Docker
    if cli == "docker" and os.path.exists("/var/run/docker.sock"):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.2)
            s.connect("/var/run/docker.sock")
            s.sendall(b"GET /_ping HTTP/1.1\r\nHost: localhost\r\n\r\n")
            data = s.recv(256)
            s.close()
            if b"OK" in data or b"200" in data:
                return True, ""
        except PermissionError:
            is_nixos = os.path.exists("/etc/NIXOS") or os.path.exists("/etc/nixos/configuration.nix")
            if is_nixos:
                return False, "Permissão negada ao acessar o socket. No NixOS, adicione 'docker' aos extraGroups no /etc/nixos/configuration.nix e aplique com 'sudo nixos-rebuild switch'."
            return False, "Permissão negada ao acessar o socket. Adicione seu usuário ao grupo docker: sudo usermod -aG docker $USER"
        except Exception:
            pass

    # Fast CLI check using version instead of slow info
    try:
        res = subprocess.run([cli, "version", "--format", "{{.Server.Version}}"],
                             capture_output=True, text=True, timeout=2)
        if res.returncode == 0 and res.stdout.strip():
            return True, ""
        err = (res.stderr or res.stdout).strip().lower()
        if "permission denied" in err:
            is_nixos = os.path.exists("/etc/NIXOS") or os.path.exists("/etc/nixos/configuration.nix")
            if is_nixos:
                return False, "Permissão negada ao acessar o socket. Adicione 'docker' aos extraGroups do usuário no /etc/nixos/configuration.nix."
            return False, "Permissão negada ao acessar o socket. Adicione seu usuário ao grupo docker: sudo usermod -aG docker $USER"
        return False, "Daemon do Docker não está rodando (systemctl start docker)"
    except Exception as e:
        return False, str(e)

def get_stats_map(cli):
    stats_map = {}
    if os.path.exists(STATS_CACHE_FILE):
        try:
            with open(STATS_CACHE_FILE, "r") as f:
                stats_map = json.load(f)
        except Exception:
            pass

    # Trigger background stats refresh if older than 5s
    now = time.time()
    cache_mtime = os.path.getmtime(STATS_CACHE_FILE) if os.path.exists(STATS_CACHE_FILE) else 0
    if now - cache_mtime > 5:
        try:
            bg_code = (
                f"import subprocess, json\n"
                f"try:\n"
                f"    res = subprocess.run(['{cli}', 'stats', '--no-stream', '--format', '{{\"id\":\"{{{{.ID}}}}\",\"cpu\":\"{{{{.CPUPerc}}}}\",\"mem\":\"{{{{.MemUsage}}}}\"}}'], capture_output=True, text=True, timeout=6)\n"
                f"    sm = {{}}\n"
                f"    for line in res.stdout.strip().split('\\n'):\n"
                f"        if line.strip():\n"
                f"            try:\n"
                f"                item = json.loads(line)\n"
                f"                sm[item.get('id')] = item\n"
                f"            except: pass\n"
                f"    with open('{STATS_CACHE_FILE}', 'w') as f:\n"
                f"        json.dump(sm, f)\n"
                f"except: pass\n"
            )
            subprocess.Popen([sys.executable, "-c", bg_code], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    return stats_map

def get_status(cli=None):
    if not cli:
        cli = get_cli()
    if not cli:
        return {
            "installed": False,
            "running": False,
            "cli": "",
            "containers_count": 0,
            "images_count": 0,
            "error": "Docker não está instalado."
        }
    running, err = check_daemon(cli)
    if not running:
        return {
            "installed": True,
            "running": False,
            "cli": cli,
            "containers_count": 0,
            "images_count": 0,
            "error": err
        }
    
    containers_count = 0
    images_count = 0
    try:
        rc = subprocess.run([cli, "ps", "-q", "-a"], capture_output=True, text=True, timeout=1.5)
        containers_count = len([x for x in rc.stdout.strip().split("\n") if x])
        ri = subprocess.run([cli, "images", "-q"], capture_output=True, text=True, timeout=1.5)
        images_count = len([x for x in ri.stdout.strip().split("\n") if x])
    except Exception:
        pass

    return {
        "installed": True,
        "running": True,
        "cli": cli,
        "containers_count": containers_count,
        "images_count": images_count,
        "error": ""
    }

def get_containers(cli=None):
    if not cli:
        cli = get_cli()
    if not cli:
        return []

    containers = []
    try:
        res = subprocess.run(
            [cli, "ps", "-a", "--format", '{"id":"{{.ID}}","name":"{{.Names}}","image":"{{.Image}}","status":"{{.Status}}","state":"{{.State}}","ports":"{{.Ports}}","created":"{{.CreatedAt}}"}'],
            capture_output=True, text=True, timeout=3
        )
        for line in res.stdout.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            try:
                c = json.loads(line)
                containers.append(c)
            except Exception:
                pass
    except Exception:
        pass

    # Fast stats lookup: background cache + direct cgroups
    stats_map = get_stats_map(cli)
    for c in containers:
        sid = c.get("id", "")
        s = stats_map.get(sid, {})
        mem_val = s.get("mem", "")
        cpu_val = s.get("cpu", "")
        if not mem_val or mem_val == "-":
            try:
                import glob
                scopes = glob.glob(f"/sys/fs/cgroup/**/docker-{sid}*.scope", recursive=True)
                if scopes:
                    mem_file = os.path.join(scopes[0], "memory.current")
                    if os.path.exists(mem_file):
                        with open(mem_file) as mf:
                            mb = round(int(mf.read().strip()) / (1024 * 1024), 1)
                            mem_val = f"{mb}MB"
            except Exception:
                pass

        c["cpu"] = cpu_val if cpu_val else "0.00%"
        c["mem"] = mem_val if mem_val else "-"

    return containers

def get_images(cli=None):
    if not cli:
        cli = get_cli()
    if not cli:
        return []

    images = []
    try:
        res = subprocess.run(
            [cli, "images", "--format", '{"id":"{{.ID}}","repository":"{{.Repository}}","tag":"{{.Tag}}","size":"{{.Size}}","created":"{{.CreatedAt}}"}'],
            capture_output=True, text=True, timeout=3
        )
        for line in res.stdout.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            try:
                img = json.loads(line)
                images.append(img)
            except Exception:
                pass
    except Exception:
        pass
    return images

def search_images(query):
    cli = get_cli()
    if not cli or not query:
        return []
    try:
        res = subprocess.run([cli, "search", query, "--limit", "15", "--format", '{{json .}}'],
                             capture_output=True, text=True, timeout=12)
        results = []
        for line in res.stdout.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                results.append({
                    "name": d.get("Name", ""),
                    "description": d.get("Description", ""),
                    "stars": str(d.get("StarCount", "0")),
                    "official": str(d.get("IsOfficial", "false")).lower() in ("true", "1")
                })
            except Exception:
                pass
        return results
    except Exception:
        return []

def get_image_tags(name):
    if not name:
        return ["latest"]
    repo = f"library/{name}" if "/" not in name else name
    url = f"https://registry.hub.docker.com/v2/repositories/{repo}/tags?page_size=15"
    req = urllib.request.Request(url, headers={"User-Agent": "Zenith/1.0"})
    tags = []
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            tags = [t.get("name") for t in data.get("results", []) if t.get("name")]
    except Exception:
        pass

    if not tags:
        lname = name.lower()
        if "postgres" in lname:
            tags = ["latest", "16", "15", "14", "alpine", "16-alpine", "15-alpine"]
        elif "redis" in lname:
            tags = ["latest", "7.2", "7.0", "alpine", "7-alpine"]
        elif "node" in lname:
            tags = ["latest", "22", "20", "18", "alpine", "20-alpine"]
        elif "python" in lname:
            tags = ["latest", "3.12", "3.11", "slim", "alpine"]
        elif "nginx" in lname:
            tags = ["latest", "alpine", "mainline", "stable"]
        elif "mongo" in lname:
            tags = ["latest", "7.0", "6.0", "jammy"]
        elif "mysql" in lname:
            tags = ["latest", "8.0", "debian"]
        else:
            tags = ["latest", "alpine", "slim", "stable"]

    if "latest" not in tags:
        tags.insert(0, "latest")
    return tags

def start_pull(target):
    cli = get_cli()
    if not cli or not target:
        return {"success": False, "error": "Invalid target or docker missing"}
    
    try:
        log_f = open(PULL_LOG_FILE, "w")
        proc = subprocess.Popen([cli, "pull", target], stdout=log_f, stderr=subprocess.STDOUT)
        status_data = {
            "pid": proc.pid,
            "target": target,
            "status": "pulling",
            "start_time": int(time.time())
        }
        with open(PULL_STATUS_FILE, "w") as sf:
            json.dump(status_data, sf)
        return {"success": True, "target": target, "status": "pulling"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_pull_status():
    if not os.path.exists(PULL_STATUS_FILE):
        return {"running": False, "target": "", "status": "idle", "log": ""}
    try:
        with open(PULL_STATUS_FILE, "r") as sf:
            data = json.load(sf)
        pid = data.get("pid", 0)
        running = False
        if pid > 0:
            try:
                os.kill(pid, 0)
                running = True
            except OSError:
                running = False

        log_content = ""
        if os.path.exists(PULL_LOG_FILE):
            with open(PULL_LOG_FILE, "r") as lf:
                lines = lf.readlines()
                log_content = "".join(lines[-15:]).strip()

        if not running and data.get("status") == "pulling":
            success = "Digest:" in log_content or "Downloaded" in log_content or "up to date" in log_content
            data["status"] = "done" if success else "error"
            with open(PULL_STATUS_FILE, "w") as sf:
                json.dump(data, sf)

        return {
            "running": running,
            "target": data.get("target", ""),
            "status": data.get("status", "idle"),
            "log": log_content
        }
    except Exception as e:
        return {"running": False, "target": "", "status": "error", "log": str(e)}

def start_build(dockerfile_path, tag, context_dir=""):
    cli = get_cli()
    if not cli or not dockerfile_path or not tag:
        return {"success": False, "error": "Missing Dockerfile path or tag"}
    
    dockerfile_path = os.path.expanduser(dockerfile_path)
    if not os.path.exists(dockerfile_path):
        return {"success": False, "error": f"Dockerfile not found: {dockerfile_path}"}

    if not context_dir:
        context_dir = os.path.dirname(dockerfile_path)
    context_dir = os.path.expanduser(context_dir)

    try:
        log_f = open(BUILD_LOG_FILE, "w")
        cmd = [cli, "build", "-t", tag, "-f", dockerfile_path, context_dir]
        proc = subprocess.Popen(cmd, stdout=log_f, stderr=subprocess.STDOUT)
        status_data = {
            "pid": proc.pid,
            "target": tag,
            "dockerfile": dockerfile_path,
            "status": "building",
            "start_time": int(time.time())
        }
        with open(BUILD_STATUS_FILE, "w") as sf:
            json.dump(status_data, sf)
        return {"success": True, "target": tag, "status": "building"}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_build_status():
    if not os.path.exists(BUILD_STATUS_FILE):
        return {"running": False, "target": "", "status": "idle", "log": ""}
    try:
        with open(BUILD_STATUS_FILE, "r") as sf:
            data = json.load(sf)
        pid = data.get("pid", 0)
        running = False
        if pid > 0:
            try:
                os.kill(pid, 0)
                running = True
            except OSError:
                running = False

        log_content = ""
        if os.path.exists(BUILD_LOG_FILE):
            with open(BUILD_LOG_FILE, "r") as lf:
                lines = lf.readlines()
                log_content = "".join(lines[-15:]).strip()

        if not running and data.get("status") == "building":
            success = "Successfully tagged" in log_content or "naming to" in log_content or "writing image" in log_content
            data["status"] = "done" if success else "error"
            with open(BUILD_STATUS_FILE, "w") as sf:
                json.dump(data, sf)

        return {
            "running": running,
            "target": data.get("target", ""),
            "status": data.get("status", "idle"),
            "log": log_content
        }
    except Exception as e:
        return {"running": False, "target": "", "status": "error", "log": str(e)}

def scan_dockerfiles():
    home = os.path.expanduser("~")
    search_roots = [
        home,
        os.path.join(home, "dev"),
        os.path.join(home, "projects"),
        "/home/levandoski/Zenith"
    ]
    results = []
    seen = set()
    for root_dir in search_roots:
        if not os.path.isdir(root_dir):
            continue
        try:
            for root, dirs, files in os.walk(root_dir):
                dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("node_modules", "target", "vendor", "dist", "build")]
                depth = root[len(root_dir):].count(os.sep)
                if depth > 3:
                    continue
                for f in files:
                    if f == "Dockerfile" or f.lower().endswith(".dockerfile") or (f.startswith("Dockerfile.") and not f.endswith("~")):
                        p = os.path.join(root, f)
                        if p not in seen:
                            seen.add(p)
                            results.append({
                                "path": p,
                                "name": f,
                                "dir": root
                            })
        except Exception:
            pass
    return results[:25]

def action(act, target):
    cli = get_cli()
    if not cli:
        return {"success": False, "error": "Docker not installed"}
    
    cmd_map = {
        "start": [cli, "start", target],
        "stop": [cli, "stop", target],
        "restart": [cli, "restart", target],
        "rm": [cli, "rm", "-f", target],
        "rmi": [cli, "rmi", "-f", target],
        "pull": [cli, "pull", target]
    }
    
    if act not in cmd_map:
        return {"success": False, "error": f"Unknown action {act}"}
    
    try:
        timeout = 180 if act == "pull" else 30
        res = subprocess.run(cmd_map[act], capture_output=True, text=True, timeout=timeout)
        return {
            "success": res.returncode == 0,
            "output": res.stdout.strip(),
            "error": res.stderr.strip()
        }
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_logs(target, lines=100):
    cli = get_cli()
    if not cli:
        return ""
    try:
        res = subprocess.run([cli, "logs", "--tail", str(lines), target],
                             capture_output=True, text=True, timeout=5)
        return (res.stdout or "") + (res.stderr or "")
    except Exception as e:
        return str(e)

def prune():
    cli = get_cli()
    if not cli:
        return {"success": False, "error": "Docker not installed"}
    try:
        res = subprocess.run([cli, "system", "prune", "-f"], capture_output=True, text=True, timeout=30)
        return {"success": res.returncode == 0, "output": res.stdout.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def run_container(params):
    cli = get_cli()
    if not cli:
        return {"success": False, "error": "Docker / Podman não encontrado no sistema"}
    
    if isinstance(params, str):
        try:
            params = json.loads(params)
        except Exception as e:
            return {"success": False, "error": f"JSON inválido: {e}"}
            
    image = params.get("image", "").strip()
    if not image:
        return {"success": False, "error": "Nome da imagem não informado"}
        
    name = params.get("name", "").strip()
    ports = params.get("ports", "").strip()
    env_vars = params.get("env", "").strip()
    volumes = params.get("volumes", "").strip()
    restart = params.get("restart", "").strip()
    detached = params.get("detached", True)
    rm = params.get("rm", False)
    cmd_args = params.get("command", "").strip()

    cmd = [cli, "run"]
    if detached:
        cmd.append("-d")
    if rm and not detached:
        cmd.append("--rm")
    if name:
        cmd.extend(["--name", name])
    if restart and not rm:
        cmd.extend(["--restart", restart])
        
    if ports:
        for p in ports.replace(";", ",").split(","):
            p = p.strip()
            if p:
                cmd.extend(["-p", p])
            
    if env_vars:
        for e in env_vars.replace(";", ",").split(","):
            e = e.strip()
            if e:
                cmd.extend(["-e", e])
            
    if volumes:
        for v in volumes.replace(";", ",").split(","):
            v = v.strip()
            if v:
                cmd.extend(["-v", v])
            
    cmd.append(image)
    
    if cmd_args:
        try:
            cmd.extend(shlex.split(cmd_args))
        except Exception:
            cmd.extend(cmd_args.split())

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if res.returncode == 0:
            cid = res.stdout.strip()
            return {"success": True, "container_id": cid, "output": cid, "error": ""}
        else:
            err_msg = res.stderr.strip() or res.stdout.strip() or "Erro ao iniciar container"
            return {"success": False, "error": err_msg}
    except Exception as e:
        return {"success": False, "error": str(e)}

def main():
    if len(sys.argv) < 2:
        cmd = "all"
    else:
        cmd = sys.argv[1]

    cli = get_cli()

    if cmd == "status":
        print(json.dumps(get_status(cli)))
    elif cmd == "containers":
        print(json.dumps(get_containers(cli)))
    elif cmd == "images":
        print(json.dumps(get_images(cli)))
    elif cmd == "all":
        if not cli:
            status = {
                "installed": False,
                "running": False,
                "cli": "",
                "containers_count": 0,
                "images_count": 0,
                "error": "Docker não está instalado."
            }
            print(json.dumps({"status": status, "containers": [], "images": []}))
            return

        running, err = check_daemon(cli)
        if not running:
            status = {
                "installed": True,
                "running": False,
                "cli": cli,
                "containers_count": 0,
                "images_count": 0,
                "error": err
            }
            print(json.dumps({"status": status, "containers": [], "images": []}))
            return

        containers = get_containers(cli)
        images = get_images(cli)
        status = {
            "installed": True,
            "running": True,
            "cli": cli,
            "containers_count": len(containers),
            "images_count": len(images),
            "error": ""
        }
        print(json.dumps({
            "status": status,
            "containers": containers,
            "images": images
        }))
    elif cmd == "search":
        q = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(search_images(q)))
    elif cmd == "tags":
        name = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(get_image_tags(name)))
    elif cmd == "pull_async":
        target = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(start_pull(target)))
    elif cmd == "pull_status":
        print(json.dumps(get_pull_status()))
    elif cmd == "build_async":
        df = sys.argv[2] if len(sys.argv) > 2 else ""
        tag = sys.argv[3] if len(sys.argv) > 3 else ""
        ctx = sys.argv[4] if len(sys.argv) > 4 else ""
        print(json.dumps(start_build(df, tag, ctx)))
    elif cmd == "build_status":
        print(json.dumps(get_build_status()))
    elif cmd == "scan_dockerfiles":
        print(json.dumps(scan_dockerfiles()))
    elif cmd == "run_json":
        json_str = sys.argv[2] if len(sys.argv) > 2 else "{}"
        print(json.dumps(run_container(json_str)))
    elif cmd == "run":
        img = sys.argv[2] if len(sys.argv) > 2 else ""
        name = sys.argv[3] if len(sys.argv) > 3 else ""
        ports = sys.argv[4] if len(sys.argv) > 4 else ""
        env_val = sys.argv[5] if len(sys.argv) > 5 else ""
        print(json.dumps(run_container({"image": img, "name": name, "ports": ports, "env": env_val})))
    elif cmd in ("start", "stop", "restart", "rm", "rmi", "pull"):
        target = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(action(cmd, target)))
    elif cmd == "logs":
        target = sys.argv[2] if len(sys.argv) > 2 else ""
        lines = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 100
        print(get_logs(target, lines))
    elif cmd == "prune":
        print(json.dumps(prune()))
    else:
        print("Unknown command", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
