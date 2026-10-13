#!/usr/bin/env bash
# Weather for desktop widgets and Dynamic Island.
# Supports OpenWeatherMap with automatic fallback to Open-Meteo (no API key required).
#
#   weather.sh KEY CITY UNITS LANG
#
#   UNITS  metric | imperial
#   LANG   pt | en | ru

KEY="$1"
CITY="$2"
UNITS="${3:-metric}"
LANG_="${4:-pt}"

fail() { printf 'err=%s\n' "$1"; exit 0; }

command -v curl >/dev/null 2>&1 || fail "no-curl"
command -v jq   >/dev/null 2>&1 || fail "no-jq"

lat=""
lon=""

# Se cidade não foi fornecida, detecta automaticamente por GeoIP
if [ -z "$CITY" ]; then
    geo_ip=$(curl -s --connect-timeout 4 --max-time 6 "http://ip-api.com/json" 2>/dev/null)
    CITY=$(printf '%s' "$geo_ip" | jq -r '.city // empty' 2>/dev/null)
    lat=$(printf '%s' "$geo_ip" | jq -r '.lat // empty' 2>/dev/null)
    lon=$(printf '%s' "$geo_ip" | jq -r '.lon // empty' 2>/dev/null)
fi

[ -n "$CITY" ] || fail "no-city"

# Função fallback: Open-Meteo (Gratuito, sem necessidade de API Key)
fallback_open_meteo() {
    if [ -z "$lat" ] || [ -z "$lon" ]; then
        city_clean="${CITY%%,*}"
        geo=$(curl -s --connect-timeout 4 --max-time 8 --get \
            --data-urlencode "name=$city_clean" \
            --data-urlencode "count=1" \
            --data-urlencode "language=$LANG_" \
            --data-urlencode "format=json" \
            "https://geocoding-api.open-meteo.com/v1/search" 2>/dev/null)
        lat=$(printf '%s' "$geo" | jq -r '.results[0].latitude // empty' 2>/dev/null)
        lon=$(printf '%s' "$geo" | jq -r '.results[0].longitude // empty' 2>/dev/null)
    fi

    [ -n "$lat" ] && [ -n "$lon" ] || fail "no-such-city"

    temp_unit=""
    [ "$UNITS" = "imperial" ] && temp_unit="&temperature_unit=fahrenheit&wind_speed_unit=mph"

    raw=$(curl -s --connect-timeout 4 --max-time 10 \
        "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure,wind_speed_10m,cloud_cover&timezone=auto$temp_unit" 2>/dev/null)

    [ -n "$raw" ] || fail "network"

    printf '%s' "$raw" | jq -r --arg city "$CITY" --arg lang "$LANG_" '
        def wmo_cond(c):
            if c == 0 then "Clear"
            elif c <= 3 then "Clouds"
            elif c <= 48 then "Fog"
            elif c <= 67 or (c >= 80 and c <= 82) then "Rain"
            elif (c >= 71 and c <= 77) or (c >= 85 and c <= 86) then "Snow"
            elif c >= 95 then "Thunderstorm"
            else "Clouds"
            end;
        def wmo_desc(c):
            if c == 0 then (if $lang == "pt" then "Céu limpo" elif $lang == "ru" then "Ясно" else "Clear sky" end)
            elif c == 1 then (if $lang == "pt" then "Predominantemente limpo" elif $lang == "ru" then "В основном ясно" else "Mainly clear" end)
            elif c == 2 then (if $lang == "pt" then "Parcialmente nublado" elif $lang == "ru" then "Переменная облачность" else "Partly cloudy" end)
            elif c == 3 then (if $lang == "pt" then "Nublado" elif $lang == "ru" then "Пасмурно" else "Overcast" end)
            elif c <= 48 then (if $lang == "pt" then "Nevoeiro" elif $lang == "ru" then "Туман" else "Fog" end)
            elif c <= 55 then (if $lang == "pt" then "Garoa" elif $lang == "ru" then "Морось" else "Drizzle" end)
            elif c <= 67 then (if $lang == "pt" then "Chuva" elif $lang == "ru" then "Дождь" else "Rain" end)
            elif c <= 77 then (if $lang == "pt" then "Neve" elif $lang == "ru" then "Снег" else "Snow" end)
            elif c <= 82 then (if $lang == "pt" then "Pancadas de chuva" elif $lang == "ru" then "Ливень" else "Rain showers" end)
            elif c >= 95 then (if $lang == "pt" then "Tempestade" elif $lang == "ru" then "Гроза" else "Thunderstorm" end)
            else (if $lang == "pt" then "Nublado" elif $lang == "ru" then "Пасмурно" else "Cloudy" end)
            end;
        def wmo_icon(c):
            if c == 0 then "01d"
            elif c <= 2 then "02d"
            elif c == 3 then "04d"
            elif c <= 48 then "50d"
            elif c <= 67 or (c >= 80 and c <= 82) then "10d"
            elif (c >= 71 and c <= 77) or (c >= 85 and c <= 86) then "13d"
            elif c >= 95 then "11d"
            else "03d"
            end;

        "temp="     + ((.current.temperature_2m // 0) | round | tostring),
        "feels="    + ((.current.apparent_temperature // 0) | round | tostring),
        "humidity=" + ((.current.relative_humidity_2m // 0) | round | tostring),
        "pressure=" + ((.current.surface_pressure // 0) | round | tostring),
        "wind="     + ((.current.wind_speed_10m // 0) * 10 | round / 10 | tostring),
        "clouds="   + ((.current.cloud_cover // 0) | round | tostring),
        "cond="     + wmo_cond(.current.weather_code // 0),
        "desc="     + wmo_desc(.current.weather_code // 0),
        "icon="     + wmo_icon(.current.weather_code // 0),
        "city="     + $city
    ' 2>/dev/null || fail "bad-answer"
    exit 0
}

# 1. Se tem KEY, tenta OpenWeatherMap
if [ -n "$KEY" ]; then
    case "$CITY" in
        [0-9]*)
            case "$CITY" in
                *,*) FIELD="zip=$CITY" ;;
                *)   FIELD="zip=$CITY,BR" ;;
            esac
            ;;
        *) FIELD="q=$CITY" ;;
    esac

    body=$(curl -sS --connect-timeout 4 --max-time 8 --get \
        --data-urlencode "$FIELD" \
        --data-urlencode "appid=$KEY" \
        --data-urlencode "units=$UNITS" \
        --data-urlencode "lang=$LANG_" \
        "https://api.openweathermap.org/data/2.5/weather" 2>/dev/null)

    code=$(printf '%s' "$body" | jq -r '.cod // empty' 2>/dev/null)
    if [ "$code" = "200" ]; then
        printf '%s' "$body" | jq -r '
            "temp="     + ((.main.temp        // 0) | round | tostring),
            "feels="    + ((.main.feels_like  // 0) | round | tostring),
            "humidity=" + ((.main.humidity    // 0) | round | tostring),
            "pressure=" + ((.main.pressure    // 0) | round | tostring),
            "wind="     + ((.wind.speed       // 0) * 10 | round / 10 | tostring),
            "clouds="   + ((.clouds.all       // 0) | round | tostring),
            "cond="     + (.weather[0].main        // ""),
            "desc="     + (.weather[0].description // ""),
            "icon="     + (.weather[0].icon        // ""),
            "city="     + (.name                   // "")
        ' 2>/dev/null && exit 0
    fi
fi

# 2. Se não tem KEY ou OpenWeatherMap falhou, usa Open-Meteo automaticamente
fallback_open_meteo
