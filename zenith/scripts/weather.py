#!/usr/bin/env python3
import sys
import os
import json
import time
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone, timedelta

def fail(err):
    print(f"err={err}")
    sys.exit(0)

if len(sys.argv) < 3:
    fail("no-args")

KEY = sys.argv[1].strip()
CITY = sys.argv[2].strip()
UNITS = sys.argv[3].strip() if len(sys.argv) > 3 and sys.argv[3].strip() else "metric"
LANG_ = sys.argv[4].strip() if len(sys.argv) > 4 and sys.argv[4].strip() else "en"

if not KEY:
    fail("no-key")
if not CITY:
    fail("no-city")

# Normalize language
lang_low = LANG_.lower()
if lang_low.startswith("pt"):
    LANG_API = "pt_br"
elif lang_low.startswith("ru"):
    LANG_API = "ru"
else:
    LANG_API = "en"

# Field parameter (city or zip)
if CITY[0].isdigit():
    if "," in CITY:
        field_param = {"zip": CITY}
    else:
        field_param = {"zip": f"{CITY},BR"}
else:
    field_param = {"q": CITY}

# Cache check (10 min cache)
safe_city = "".join(c for c in CITY if c.isalnum() or c in "_-")
cache_file = f"/tmp/zenith_weather_{KEY[:6]}_{safe_city}_{UNITS}_{LANG_API}.json"
cache_max_age = 600 # 10 minutes

force_refresh = "--force" in sys.argv
if not force_refresh and os.path.exists(cache_file):
    try:
        mtime = os.path.getmtime(cache_file)
        if time.time() - mtime < cache_max_age:
            with open(cache_file, "r", encoding="utf-8") as f:
                cached_data = json.load(f)
                if cached_data.get("output"):
                    print(cached_data["output"])
                    sys.exit(0)
    except Exception:
        pass

# Prepare query
base_params = {
    **field_param,
    "appid": KEY,
    "units": UNITS,
    "lang": LANG_API
}

encoded_params = urllib.parse.urlencode(base_params)
w_url = f"https://api.openweathermap.org/data/2.5/weather?{encoded_params}"
f_url = f"https://api.openweathermap.org/data/2.5/forecast?{encoded_params}"

headers = {"User-Agent": "Zenith/1.0"}

def fetch_json(url):
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            code = resp.getcode()
            if code != 200:
                return None, f"http-{code}"
            return json.loads(resp.read().decode("utf-8")), None
    except urllib.error.HTTPError as e:
        if e.code == 401: return None, "bad-key"
        if e.code == 404: return None, "no-such-city"
        if e.code == 429: return None, "rate-limit"
        return None, f"http-{e.code}"
    except urllib.error.URLError:
        return None, "network"
    except Exception as e:
        return None, "bad-answer"

curr_data, curr_err = fetch_json(w_url)
if curr_err:
    fail(curr_err)

forecast_data, _ = fetch_json(f_url)

# Parse current data
m = curr_data.get("main") or {}
w = (curr_data.get("weather") or [{}])[0]
wind = curr_data.get("wind") or {}
clouds = curr_data.get("clouds") or {}

temp = round(m.get("temp", 0))
feels = round(m.get("feels_like", 0))
humidity = round(m.get("humidity", 0))
pressure = round(m.get("pressure", 0))
wind_speed = round(wind.get("speed", 0) * 10) / 10
clouds_all = round(clouds.get("all", 0))
cond = w.get("main", "")
desc = w.get("description", "")
icon = w.get("icon", "")
city_name = curr_data.get("name", "")

# Parse forecast data
day_names_pt = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
day_names_long_pt = ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"]
day_names_en = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
day_names_long_en = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
day_names_ru = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
day_names_long_ru = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]

if LANG_API == "pt_br":
    d_names = day_names_pt
    d_long = day_names_long_pt
elif LANG_API == "ru":
    d_names = day_names_ru
    d_long = day_names_long_ru
else:
    d_names = day_names_en
    d_long = day_names_long_en

hourly_list = []
daily_list = []

if forecast_data and "list" in forecast_data:
    raw_list = forecast_data["list"]

    # Hourly: next 12 slots (36 hours)
    for it in raw_list[:12]:
        dt = datetime.fromtimestamp(it.get("dt", 0))
        it_m = it.get("main", {})
        it_w = (it.get("weather", [{}]))[0]
        it_wind = it.get("wind", {})
        it_pop = round((it.get("pop", 0) or 0) * 100)

        hourly_list.append({
            "time": dt.strftime("%H:%M"),
            "date": dt.strftime("%d/%m"),
            "temp": round(it_m.get("temp", 0)),
            "feels": round(it_m.get("feels_like", 0)),
            "pop": it_pop,
            "cond": it_w.get("main", ""),
            "desc": it_w.get("description", ""),
            "icon": it_w.get("icon", ""),
            "humidity": round(it_m.get("humidity", 0)),
            "wind": round((it_wind.get("speed", 0) or 0) * 10) / 10
        })

    # Group by calendar date for daily forecast
    by_day = {}
    for it in raw_list:
        dt = datetime.fromtimestamp(it.get("dt", 0))
        d_key = dt.strftime("%Y-%m-%d")
        if d_key not in by_day:
            by_day[d_key] = []
        by_day[d_key].append(it)

    today_str = datetime.now().strftime("%Y-%m-%d")

    for d_key in sorted(by_day.keys()):
        items = by_day[d_key]
        temps = [it.get("main", {}).get("temp", 0) for it in items]
        pops = [it.get("pop", 0) for it in items]

        # pick midday slot (closest to 13:00) for condition/icon/desc
        mid = sorted(items, key=lambda it: abs(datetime.fromtimestamp(it.get("dt", 0)).hour - 13))[0]
        mid_w = (mid.get("weather", [{}]))[0]
        dt = datetime.strptime(d_key, "%Y-%m-%d")
        weekday_idx = dt.weekday()

        daily_list.append({
            "date": dt.strftime("%d/%m"),
            "dateIso": d_key,
            "isToday": (d_key == today_str),
            "day": d_names[weekday_idx],
            "dayLong": d_long[weekday_idx],
            "min": round(min(temps)),
            "max": round(max(temps)),
            "pop": round(max(pops) * 100),
            "cond": mid_w.get("main", ""),
            "desc": mid_w.get("description", ""),
            "icon": mid_w.get("icon", "")
        })

forecast_obj = {
    "city": city_name,
    "updated": datetime.now().strftime("%H:%M"),
    "hourly": hourly_list,
    "daily": daily_list
}

forecast_json_str = json.dumps(forecast_obj, ensure_ascii=False)

output_lines = [
    f"temp={temp}",
    f"feels={feels}",
    f"humidity={humidity}",
    f"pressure={pressure}",
    f"wind={wind_speed}",
    f"clouds={clouds_all}",
    f"cond={cond}",
    f"desc={desc}",
    f"icon={icon}",
    f"city={city_name}",
    f"forecast_json={forecast_json_str}"
]

final_output = "\n".join(output_lines)
print(final_output)

# Cache result
try:
    with open(cache_file, "w", encoding="utf-8") as f:
        json.dump({"output": final_output, "time": time.time()}, f, ensure_ascii=False)
except Exception:
    pass
