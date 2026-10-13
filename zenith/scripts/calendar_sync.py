#!/usr/bin/env python3
import os
import sys
import json
import re
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

CONFIG_DIR = os.path.expanduser("~/.config/zenith")
EVENTS_FILE = os.path.join(CONFIG_DIR, "calendar_events.json")
LINKS_FILE = os.path.join(CONFIG_DIR, "calendar_links.json")
SETTINGS_FILE = os.path.join(CONFIG_DIR, "settings.json")
DEFAULT_BACKUP_FILE = os.path.expanduser("~/zenith_calendar_backup.json")

def ensure_config_dir():
    os.makedirs(CONFIG_DIR, exist_ok=True)

def load_events():
    ensure_config_dir()
    if not os.path.exists(EVENTS_FILE):
        return []
    try:
        with open(EVENTS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading events: {e}", file=sys.stderr)
        return []

def save_events(events):
    ensure_config_dir()
    temp_file = EVENTS_FILE + ".tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(events, f, indent=2, ensure_ascii=False)
    os.replace(temp_file, EVENTS_FILE)

def load_links():
    ensure_config_dir()
    if os.path.exists(LINKS_FILE):
        try:
            with open(LINKS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass

    # Migrate from settings.json if calendar_links.json does not exist
    links = []
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                gurl = cfg.get("calGoogleUrl", "").strip()
                if gurl:
                    links.append({
                        "id": "link_default",
                        "name": "Google Agenda",
                        "url": gurl,
                        "enabled": True
                    })
                    save_links(links)
        except Exception:
            pass
    return links

def save_links(links):
    ensure_config_dir()
    temp_file = LINKS_FILE + ".tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(links, f, indent=2, ensure_ascii=False)
    os.replace(temp_file, LINKS_FILE)

def unescape_ics_text(text):
    if not text:
        return ""
    text = text.replace(r"\n", "\n").replace(r"\N", "\n")
    text = text.replace(r"\,", ",").replace(r"\;", ";").replace(r"\\", "\\")
    return text.strip()

def unfold_ics_lines(raw_text):
    lines = raw_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    unfolded = []
    for line in lines:
        if line.startswith((" ", "\t")) and unfolded:
            unfolded[-1] += line[1:]
        else:
            unfolded.append(line)
    return unfolded

def parse_ics_datetime(dt_str):
    """
    Parses DTSTART / DTEND string.
    Returns: (date_str "YYYY-MM-DD", time_str "HH:MM", is_all_day)
    """
    dt_str = dt_str.strip()
    if len(dt_str) == 8 and dt_str.isdigit():
        d = f"{dt_str[0:4]}-{dt_str[4:6]}-{dt_str[6:8]}"
        return d, "00:00", True

    if "T" in dt_str and dt_str.endswith("Z"):
        clean = dt_str[:-1]
        try:
            dt_utc = datetime.strptime(clean, "%Y%m%dT%H%M%S").replace(tzinfo=timezone.utc)
            local_dt = dt_utc.astimezone()
            return local_dt.strftime("%Y-%m-%d"), local_dt.strftime("%H:%M"), False
        except Exception:
            pass

    if "T" in dt_str:
        clean = dt_str.split("T")
        d_part = clean[0]
        t_part = clean[1][:6]
        try:
            d = f"{d_part[0:4]}-{d_part[4:6]}-{d_part[6:8]}"
            t = f"{t_part[0:2]}:{t_part[2:4]}"
            return d, t, False
        except Exception:
            pass

    return "", "", False

def expand_rrule(base_date, time_str, rrule_str, days_past=30, days_future=120):
    occurrences = []
    try:
        base_dt = datetime.strptime(base_date, "%Y-%m-%d")
    except Exception:
        return [base_date]

    now = datetime.now()
    start_window = now - timedelta(days=days_past)
    end_window = now + timedelta(days=days_future)

    parts = dict(p.split("=", 1) for p in rrule_str.split(";") if "=" in p)
    freq = parts.get("FREQ", "DAILY").upper()
    interval = int(parts.get("INTERVAL", 1))
    count = int(parts.get("COUNT", 999))
    until_str = parts.get("UNTIL", "")
    until_dt = None
    if until_str:
        u_d, _, _ = parse_ics_datetime(until_str)
        if u_d:
            try:
                until_dt = datetime.strptime(u_d, "%Y-%m-%d")
            except Exception:
                pass

    cur = base_dt
    generated = 0

    while generated < count and cur <= end_window:
        if until_dt and cur > until_dt:
            break
        generated += 1

        if freq == "DAILY":
            if cur >= start_window and cur <= end_window:
                occurrences.append(cur.strftime("%Y-%m-%d"))
            cur += timedelta(days=interval)
        elif freq == "WEEKLY":
            if cur >= start_window and cur <= end_window:
                occurrences.append(cur.strftime("%Y-%m-%d"))
            cur += timedelta(weeks=interval)
        elif freq == "MONTHLY":
            if cur >= start_window and cur <= end_window:
                occurrences.append(cur.strftime("%Y-%m-%d"))
            next_month = cur.month + interval
            next_year = cur.year + (next_month - 1) // 12
            next_month = ((next_month - 1) % 12) + 1
            try:
                cur = cur.replace(year=next_year, month=next_month)
            except ValueError:
                cur = cur.replace(year=next_year, month=next_month, day=28)
        else:
            if cur >= start_window and cur <= end_window:
                occurrences.append(cur.strftime("%Y-%m-%d"))
            break

    if not occurrences:
        occurrences.append(base_date)

    return sorted(list(set(occurrences)))

def parse_ics(ics_content, cal_id="default", cal_name="Google Agenda"):
    events = []
    lines = unfold_ics_lines(ics_content)
    cur = None

    for line in lines:
        line_clean = line.strip()
        if line_clean == "BEGIN:VEVENT":
            cur = {}
        elif line_clean == "END:VEVENT":
            if cur and "SUMMARY" in cur and ("DTSTART" in cur or any(k.startswith("DTSTART") for k in cur)):
                uid = cur.get("UID", f"{cal_id}_{int(time.time()*1000)}")
                # sanitize uid for ID
                safe_uid = re.sub(r'[^a-zA-Z0-9_-]', '_', uid)
                title = unescape_ics_text(cur.get("SUMMARY", ""))
                desc = unescape_ics_text(cur.get("DESCRIPTION", ""))
                loc = unescape_ics_text(cur.get("LOCATION", ""))
                if loc:
                    desc = (desc + f" ({loc})" if desc else loc)

                dtstart_raw = ""
                for k, v in cur.items():
                    if k == "DTSTART" or k.startswith("DTSTART;"):
                        dtstart_raw = v
                        break

                dtend_raw = ""
                for k, v in cur.items():
                    if k == "DTEND" or k.startswith("DTEND;"):
                        dtend_raw = v
                        break

                date_str, time_str, all_day = parse_ics_datetime(dtstart_raw)
                end_date_str, end_time_str, _ = parse_ics_datetime(dtend_raw)

                if date_str:
                    rrule = cur.get("RRULE", "")
                    if rrule:
                        occurrences = expand_rrule(date_str, time_str, rrule)
                        for occ_date in occurrences:
                            events.append({
                                "id": f"cal_{cal_id}_{safe_uid}_{occ_date}",
                                "calendarId": cal_id,
                                "calendarName": cal_name,
                                "title": title,
                                "date": occ_date,
                                "time": time_str,
                                "endTime": end_time_str if end_time_str else time_str,
                                "allDay": all_day,
                                "desc": desc,
                                "source": "google",
                                "notifiedCount": 0,
                                "lastNotified": 0
                            })
                    else:
                        events.append({
                            "id": f"cal_{cal_id}_{safe_uid}_{date_str}",
                            "calendarId": cal_id,
                            "calendarName": cal_name,
                            "title": title,
                            "date": date_str,
                            "time": time_str,
                            "endTime": end_time_str if end_time_str else time_str,
                            "allDay": all_day,
                            "desc": desc,
                            "source": "google",
                            "notifiedCount": 0,
                            "lastNotified": 0
                        })
            cur = None
        elif cur is not None:
            if ":" in line_clean:
                prop_key, prop_val = line_clean.split(":", 1)
                cur[prop_key] = prop_val
                base_prop = prop_key.split(";")[0].upper()
                if base_prop not in cur:
                    cur[base_prop] = prop_val

    return events

def fetch_ics_url(url):
    req = urllib.request.Request(url.strip(), headers={"User-Agent": "Mozilla/5.0 (Zenith Calendar Sync)"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.read().decode("utf-8", errors="replace")

def cmd_sync(single_url=None):
    links = load_links()

    if single_url and single_url.strip():
        sync_targets = [{
            "id": "single",
            "name": "Google Agenda",
            "url": single_url.strip(),
            "enabled": True
        }]
    else:
        sync_targets = [l for l in links if l.get("enabled", True) and l.get("url")]

    if not sync_targets:
        print(json.dumps({"status": "ok", "message": "Nenhum link configurado", "count": 0, "total": len(load_events())}))
        return

    current_events = load_events()
    local_events = [e for e in current_events if e.get("source") != "google"]
    existing_notif_states = {e["id"]: (e.get("notifiedCount", 0), e.get("lastNotified", 0))
                             for e in current_events if e.get("source") == "google"}

    all_fetched_events = []
    errors = []
    success_count = 0

    for item in sync_targets:
        cal_id = str(item.get("id", "default"))
        cal_name = str(item.get("name", "Google Agenda"))
        url = item.get("url", "").strip()
        if not url:
            continue
        try:
            content = fetch_ics_url(url)
            parsed = parse_ics(content, cal_id=cal_id, cal_name=cal_name)
            for ev in parsed:
                if ev["id"] in existing_notif_states:
                    ev["notifiedCount"], ev["lastNotified"] = existing_notif_states[ev["id"]]
            all_fetched_events.extend(parsed)
            success_count += 1
        except Exception as e:
            errors.append(f"{cal_name}: {str(e)}")

    # Merge
    merged = local_events + all_fetched_events
    merged.sort(key=lambda x: (x.get("date", ""), x.get("time", "")))
    save_events(merged)

    resp = {
        "status": "ok" if success_count > 0 or not errors else "error",
        "syncedCalendars": success_count,
        "count": len(all_fetched_events),
        "total": len(merged),
        "events": merged
    }
    if errors:
        resp["errors"] = errors
    print(json.dumps(resp, ensure_ascii=False))

def cmd_list():
    events = load_events()
    print(json.dumps({"status": "ok", "events": events}, ensure_ascii=False))

def cmd_add(title, date_str, time_str="00:00", end_time="", desc="", all_day=False):
    events = load_events()
    event_id = f"loc_{int(time.time()*1000)}"
    new_event = {
        "id": event_id,
        "title": title.strip(),
        "date": date_str.strip(),
        "time": time_str.strip(),
        "endTime": end_time.strip() if end_time else time_str.strip(),
        "allDay": bool(all_day),
        "desc": desc.strip(),
        "source": "local",
        "calendarName": "Manual",
        "notifiedCount": 0,
        "lastNotified": 0
    }
    events.append(new_event)
    events.sort(key=lambda x: (x.get("date", ""), x.get("time", "")))
    save_events(events)
    print(json.dumps({"status": "ok", "event": new_event, "events": events}, ensure_ascii=False))

def cmd_delete(event_id):
    events = load_events()
    initial_len = len(events)
    events = [e for e in events if e.get("id") != event_id]
    save_events(events)
    print(json.dumps({
        "status": "ok",
        "deleted": initial_len - len(events),
        "events": events
    }, ensure_ascii=False))

def cmd_update_notif(event_id, count, last_notified):
    events = load_events()
    for e in events:
        if e.get("id") == event_id:
            e["notifiedCount"] = int(count)
            e["lastNotified"] = int(last_notified)
            break
    save_events(events)
    print(json.dumps({"status": "ok"}))

# ----------------- LINKS MANAGEMENT -----------------
def cmd_links_list():
    links = load_links()
    print(json.dumps({"status": "ok", "links": links}, ensure_ascii=False))

def cmd_links_add(name, url):
    links = load_links()
    new_id = f"link_{int(time.time()*1000)}"
    new_link = {
        "id": new_id,
        "name": (name or "Minha Agenda").strip(),
        "url": url.strip(),
        "enabled": True
    }
    links.append(new_link)
    save_links(links)

    # Also keep first link in settings.json for backward compatibility
    try:
        if os.path.exists(SETTINGS_FILE):
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
            cfg["calGoogleUrl"] = url.strip()
            with open(SETTINGS_FILE, ".tmp", "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=4, ensure_ascii=False)
            os.replace(SETTINGS_FILE + ".tmp", SETTINGS_FILE)
    except Exception:
        pass

    # Trigger sync for the newly added link
    print(json.dumps({"status": "ok", "link": new_link, "links": links}, ensure_ascii=False))

def cmd_links_delete(link_id):
    links = load_links()
    links = [l for l in links if l.get("id") != link_id]
    save_links(links)

    # Remove events associated with this link
    events = load_events()
    events = [e for e in events if e.get("calendarId") != link_id]
    save_events(events)

    print(json.dumps({"status": "ok", "links": links}, ensure_ascii=False))

# ----------------- BACKUP EXPORT & IMPORT -----------------
def cmd_export(filepath=None):
    target_path = os.path.expanduser(filepath) if filepath else DEFAULT_BACKUP_FILE
    target_dir = os.path.dirname(target_path)
    if target_dir:
        os.makedirs(target_dir, exist_ok=True)

    events = load_events()
    links = load_links()

    settings_data = {}
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                settings_data = {
                    "calNotifyLead": cfg.get("calNotifyLead", 30),
                    "calNotifyCount": cfg.get("calNotifyCount", 2),
                    "calNotifyInterval": cfg.get("calNotifyInterval", 10),
                    "calGoogleUrl": cfg.get("calGoogleUrl", "")
                }
        except Exception:
            pass

    backup_payload = {
        "version": 1,
        "appName": "Zenith Calendar",
        "exportedAt": datetime.now().isoformat(),
        "settings": settings_data,
        "links": links,
        "events": events
    }

    tmp = target_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(backup_payload, f, indent=2, ensure_ascii=False)
    os.replace(tmp, target_path)

    print(json.dumps({
        "status": "ok",
        "path": target_path,
        "eventsCount": len(events),
        "linksCount": len(links),
        "message": f"Backup exportado para {target_path}"
    }, ensure_ascii=False))

def cmd_import(filepath=None):
    source_path = os.path.expanduser(filepath) if filepath else DEFAULT_BACKUP_FILE
    if not os.path.exists(source_path):
        print(json.dumps({"status": "error", "message": f"Arquivo não encontrado: {source_path}"}))
        return

    try:
        with open(source_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(json.dumps({"status": "error", "message": f"Erro ao ler arquivo: {e}"}))
        return

    imported_links = data.get("links", [])
    imported_events = data.get("events", [])
    imported_settings = data.get("settings", {})

    if imported_links:
        save_links(imported_links)

    if imported_events:
        save_events(imported_events)

    if imported_settings and os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
            for k, v in imported_settings.items():
                cfg[k] = v
            tmp_s = SETTINGS_FILE + ".tmp"
            with open(tmp_s, "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=4, ensure_ascii=False)
            os.replace(tmp_s, SETTINGS_FILE)
        except Exception:
            pass

    print(json.dumps({
        "status": "ok",
        "path": source_path,
        "eventsRestored": len(imported_events),
        "linksRestored": len(imported_links),
        "message": f"Backup restaurado com sucesso! ({len(imported_events)} eventos, {len(imported_links)} links)"
    }, ensure_ascii=False))

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Zenith Calendar Sync & Management")
    subparsers = parser.add_subparsers(dest="action")

    # list
    subparsers.add_parser("list")

    # sync
    sync_p = subparsers.add_parser("sync")
    sync_p.add_argument("--url", default="", help="Optional single URL to sync")

    # add
    add_p = subparsers.add_parser("add")
    add_p.add_argument("--title", required=True)
    add_p.add_argument("--date", required=True)
    add_p.add_argument("--time", default="00:00")
    add_p.add_argument("--end-time", default="")
    add_p.add_argument("--desc", default="")
    add_p.add_argument("--all-day", action="store_true")

    # delete
    del_p = subparsers.add_parser("delete")
    del_p.add_argument("--id", required=True)

    # update_notif
    upd_p = subparsers.add_parser("update_notif")
    upd_p.add_argument("--id", required=True)
    upd_p.add_argument("--count", type=int, required=True)
    upd_p.add_argument("--last-notified", type=int, required=True)

    # links_list
    subparsers.add_parser("links_list")

    # links_add
    la_p = subparsers.add_parser("links_add")
    la_p.add_argument("--name", default="Google Agenda")
    la_p.add_argument("--url", required=True)

    # links_delete
    ld_p = subparsers.add_parser("links_delete")
    ld_p.add_argument("--id", required=True)

    # export
    exp_p = subparsers.add_parser("export")
    exp_p.add_argument("--file", default="")

    # import
    imp_p = subparsers.add_parser("import")
    imp_p.add_argument("--file", default="")

    args = parser.parse_args()

    if args.action == "list" or not args.action:
        cmd_list()
    elif args.action == "sync":
        cmd_sync(args.url)
    elif args.action == "add":
        cmd_add(args.title, args.date, args.time, args.end_time, args.desc, args.all_day)
    elif args.action == "delete":
        cmd_delete(args.id)
    elif args.action == "update_notif":
        cmd_update_notif(args.id, args.count, args.last_notified)
    elif args.action == "links_list":
        cmd_links_list()
    elif args.action == "links_add":
        cmd_links_add(args.name, args.url)
    elif args.action == "links_delete":
        cmd_links_delete(args.id)
    elif args.action == "export":
        cmd_export(args.file)
    elif args.action == "import":
        cmd_import(args.file)
