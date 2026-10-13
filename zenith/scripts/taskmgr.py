#!/usr/bin/env python3
import os
import sys
import json
import signal
import subprocess
import time

def get_sysinfo():
    # CPU
    cpu_pct = 0.0
    try:
        with open("/proc/stat", "r") as f:
            line1 = f.readline()
        t1 = [float(x) for x in line1.split()[1:8]]
        time.sleep(0.08)
        with open("/proc/stat", "r") as f:
            line2 = f.readline()
        t2 = [float(x) for x in line2.split()[1:8]]
        
        idle1 = t1[3] + t1[4]
        idle2 = t2[3] + t2[4]
        total1 = sum(t1)
        total2 = sum(t2)
        
        diff_idle = idle2 - idle1
        diff_total = total2 - total1
        if diff_total > 0:
            cpu_pct = round((1.0 - (diff_idle / diff_total)) * 100.0, 1)
    except Exception:
        pass

    # RAM
    mem_total = 0
    mem_avail = 0
    swap_total = 0
    swap_free = 0
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split()
                if not parts:
                    continue
                k = parts[0]
                if k == "MemTotal:":
                    mem_total = int(parts[1]) * 1024
                elif k == "MemAvailable:":
                    mem_avail = int(parts[1]) * 1024
                elif k == "SwapTotal:":
                    swap_total = int(parts[1]) * 1024
                elif k == "SwapFree:":
                    swap_free = int(parts[1]) * 1024
    except Exception:
        pass

    mem_used = max(0, mem_total - mem_avail)
    mem_pct = round((mem_used / mem_total * 100.0), 1) if mem_total > 0 else 0.0
    swap_used = max(0, swap_total - swap_free)
    swap_pct = round((swap_used / swap_total * 100.0), 1) if swap_total > 0 else 0.0

    cores = os.cpu_count() or 1

    return {
        "cpu_pct": cpu_pct,
        "cores": cores,
        "mem_total": mem_total,
        "mem_used": mem_used,
        "mem_avail": mem_avail,
        "mem_pct": mem_pct,
        "swap_total": swap_total,
        "swap_used": swap_used,
        "swap_pct": swap_pct
    }

def get_processes(sort_by="cpu", limit=100, query=""):
    query = query.strip().lower()
    procs = []
    
    try:
        cmd = ["ps", "-eo", "pid,user,%cpu,%mem,rss,stat,comm,args", "--no-headers"]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = res.stdout.strip().split("\n")
        
        for line in lines:
            parts = line.strip().split(None, 7)
            if len(parts) < 8:
                continue
            try:
                pid = int(parts[0])
                user = parts[1]
                cpu = float(parts[2].replace(",", "."))
                mem = float(parts[3].replace(",", "."))
                rss_bytes = int(parts[4]) * 1024
                stat = parts[5]
                comm = parts[6]
                args = parts[7]
            except Exception:
                continue

            if query:
                if (query not in comm.lower() and 
                    query not in args.lower() and 
                    query not in str(pid) and 
                    query not in user.lower()):
                    continue

            name = comm
            is_kernel = name.startswith("[") and name.endswith("]")

            procs.append({
                "pid": pid,
                "user": user,
                "cpu": cpu,
                "mem": mem,
                "rss": rss_bytes,
                "stat": stat,
                "name": name,
                "cmd": args,
                "kernel": is_kernel
            })
    except Exception as e:
        sys.stderr.write(f"Error getting processes: {e}\n")

    if sort_by == "mem":
        procs.sort(key=lambda x: x["rss"], reverse=True)
    elif sort_by == "name":
        procs.sort(key=lambda x: x["name"].lower())
    elif sort_by == "pid":
        procs.sort(key=lambda x: x["pid"])
    elif sort_by == "user":
        procs.sort(key=lambda x: x["user"].lower())
    else:
        procs.sort(key=lambda x: x["cpu"], reverse=True)

    if limit > 0:
        procs = procs[:limit]

    return procs

def main():
    if len(sys.argv) < 2:
        cmd = "all"
    else:
        cmd = sys.argv[1]

    if cmd == "sysinfo":
        print(json.dumps(get_sysinfo()))
    elif cmd == "processes" or cmd == "list":
        sort_by = sys.argv[2] if len(sys.argv) > 2 else "cpu"
        limit = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 80
        query = sys.argv[4] if len(sys.argv) > 4 else ""
        print(json.dumps(get_processes(sort_by, limit, query)))
    elif cmd == "all":
        sort_by = sys.argv[2] if len(sys.argv) > 2 else "cpu"
        limit = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 80
        query = sys.argv[4] if len(sys.argv) > 4 else ""
        data = {
            "sysinfo": get_sysinfo(),
            "processes": get_processes(sort_by, limit, query)
        }
        print(json.dumps(data))
    elif cmd == "kill":
        if len(sys.argv) > 2:
            pid = int(sys.argv[2])
            try:
                os.kill(pid, signal.SIGTERM)
                print(json.dumps({"success": True, "pid": pid}))
            except Exception as e:
                print(json.dumps({"success": False, "error": str(e)}))
    elif cmd == "kill9" or cmd == "forcekill":
        if len(sys.argv) > 2:
            pid = int(sys.argv[2])
            try:
                os.kill(pid, signal.SIGKILL)
                print(json.dumps({"success": True, "pid": pid}))
            except Exception as e:
                print(json.dumps({"success": False, "error": str(e)}))
    elif cmd == "stop" or cmd == "pause":
        if len(sys.argv) > 2:
            pid = int(sys.argv[2])
            try:
                os.kill(pid, signal.SIGSTOP)
                print(json.dumps({"success": True, "pid": pid}))
            except Exception as e:
                print(json.dumps({"success": False, "error": str(e)}))
    elif cmd == "cont" or cmd == "resume":
        if len(sys.argv) > 2:
            pid = int(sys.argv[2])
            try:
                os.kill(pid, signal.SIGCONT)
                print(json.dumps({"success": True, "pid": pid}))
            except Exception as e:
                print(json.dumps({"success": False, "error": str(e)}))
    else:
        print("Unknown command", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
