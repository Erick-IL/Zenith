#!/usr/bin/env bash
# Collects information about installed AI agents into one JSON for the island.
#
# Why a separate script, and not parsing in QML: the data is in someone else’s files
# foreign format, and each agent stores them differently. Here it comes down to
# one form, and the view draws it, without knowing anything about who is holding what where.
#
# What is NOT displayed: email, account name, organization IDs and
# account. The window shows the load and tariff, and not whose account it is -
# The island is used when screen sharing is turned on.
#
# The limit signatures are not translated here: the stable key (kind) goes out, and
# the human name substitutes the view - otherwise changing the interface language will not
# would reach this window.
set -u

command -v jq >/dev/null 2>&1 || { printf '{"agents":[],"error":"jq"}\n'; exit 0; }

# ISO 8601 -> epoch milliseconds. Claude has six characters after resets_at
# comma; JS parses such fractional parts haphazardly in some places, so
# We count here where date(1) is and send the number out.
iso_ms() {
    [ -n "${1:-}" ] && [ "$1" != "null" ] || { echo "0"; return; }
    date -d "$1" +%s%3N 2>/dev/null || echo "0"
}

# ------------------------------------------------------------------ claude
claude_json() {
    local cfg="$HOME/.claude.json"
    local bin; bin="$(command -v claude 2>/dev/null)"
    [ -n "$bin" ] || [ -f "$cfg" ] || return 1

    local ver=""
    [ -n "$bin" ] && ver="$("$bin" --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')"

    local plan="" raw="" fetched=0
    if [ -f "$cfg" ]; then
        raw="$(jq -r '.oauthAccount.organizationType // ""' "$cfg" 2>/dev/null)"
        fetched="$(jq -r '.cachedUsageUtilization.fetchedAtMs // 0' "$cfg" 2>/dev/null)"
    fi

    # We translate the known values into what the tariff is called on the website.
    # We don’t hide or invent the unknown: “claude_max_40x” will turn into
    # "Claude Max 40x" and it will be clear that a tariff has appeared, which is still here
    # they don’t know - it’s more honest than empty space.
    case "$raw" in
        claude_pro)        plan="Claude Pro" ;;
        claude_max_5x)     plan="Claude Max 5x" ;;
        claude_max_20x)    plan="Claude Max 20x" ;;
        claude_team)       plan="Claude Team" ;;
        claude_enterprise) plan="Claude Enterprise" ;;
        "")                plan="" ;;
        *)                 plan="$(printf '%s' "$raw" | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')" ;;
    esac

    # The load cache belongs to a SPECIFIC account, and this is recorded in it
    # himself. When you change your account, Claude Code either erases the entire cache, or
    # The old one holds for some time - until the first request from the new one. Show
    # it as current would mean attributing to one account the expense of another,
    # Therefore, we check the accountUuid and if there is a discrepancy, we assume that there is no data.
    local acct cacheAcct
    acct="$(jq -r '.oauthAccount.accountUuid // ""' "$cfg" 2>/dev/null)"
    cacheAcct="$(jq -r '.cachedUsageUtilization.accountUuid // ""' "$cfg" 2>/dev/null)"

    local limits='[]'
    if [ -f "$cfg" ] && [ -n "$cacheAcct" ] && [ "$cacheAcct" = "$acct" ]; then
        # limits[] - a ready list, as the server sent it: and a five-hour
        # window, and weekly, and everything that will be added later. We take it whole, not
        # two previously known fields so that new limits appear on their own.
        #
        # The fallback is the same two fields: in older versions of Claude Code
        # there is no limits array yet, but five_hour and seven_day already exist.
        limits="$(jq -c '
            (.cachedUsageUtilization.utilization) as $u
            | if (($u.limits // []) | length) > 0 then
                [ $u.limits[]
                  | select(.percent != null)
                  | { kind: (.kind // "unknown"),
                      percent: (.percent | floor),
                      severity: (.severity // "normal"),
                      resetsAtIso: (.resets_at // "") } ]
              else
                [ { kind: "session",    v: $u.five_hour },
                  { kind: "weekly_all", v: $u.seven_day } ]
                | map(select(.v != null and .v.utilization != null))
                | map({ kind: .kind,
                        percent: (.v.utilization | floor),
                        severity: "normal",
                        resetsAtIso: (.v.resets_at // "") })
              end
        ' "$cfg" 2>/dev/null)" || limits='[]'
    fi
    [ -n "$limits" ] && [ "$limits" != "null" ] || limits='[]'

    # Why there are no limits is not an idle question: “the agent does not give them away” and “data
    # hasn’t arrived yet” look the same, but mean the opposite. First
    # forever, the second will go away on its own as soon as the agent works.
    local note=""
    [ "$limits" = "[]" ] && note="nodata"

    # We turn the date into a number here: in jq there is no parsing of fractional seconds.
    local out='[]' i=0 n
    n="$(printf '%s' "$limits" | jq 'length')"
    while [ "$i" -lt "${n:-0}" ]; do
        local one iso ms
        one="$(printf '%s' "$limits" | jq -c ".[$i]")"
        iso="$(printf '%s' "$one" | jq -r '.resetsAtIso')"
        ms="$(iso_ms "$iso")"
        out="$(printf '%s' "$out" | jq -c --argjson one "$one" --argjson ms "${ms:-0}" \
               '. + [ ($one | del(.resetsAtIso) | .resetsAt = $ms) ]')"
        i=$((i + 1))
    done

    jq -cn --arg name "Claude Code" --arg ver "$ver" --arg plan "$plan" \
           --arg note "$note" \
           --argjson fetched "${fetched:-0}" --argjson limits "$out" '
        { id: "claude", name: $name, version: $ver, plan: $plan,
          note: $note, fetchedAt: $fetched, limits: $limits }'
}

# -------------------------------------------------------------------- codex
# The Codex tariff lies in the OpenAI token: auth.json stores JWT, and inside it, in
# payload, there is chatgpt_plan_type. We only get this field - itself
# The token does not come out in any form.
codex_plan() {
    local auth="$HOME/.codex/auth.json"
    [ -f "$auth" ] || return 0
    local tok; tok="$(jq -r '.tokens.id_token // ""' "$auth" 2>/dev/null)"
    [ -n "$tok" ] && [ "$tok" != "null" ] || return 0

    # the middle part of the JWT is base64url without alignment, we finish the '=' ourselves
    local body; body="$(printf '%s' "$tok" | cut -d. -f2)"
    [ -n "$body" ] || return 0
    case $(( ${#body} % 4 )) in 2) body="$body==" ;; 3) body="$body=" ;; esac

    local raw; raw="$(printf '%s' "$body" | tr '_-' '/+' | base64 -d 2>/dev/null \
        | jq -r '.["https://api.openai.com/auth"].chatgpt_plan_type // ""' 2>/dev/null)"
    case "$raw" in
        plus)  echo "ChatGPT Plus" ;;
        pro)   echo "ChatGPT Pro" ;;
        team)  echo "ChatGPT Team" ;;
        enterprise) echo "ChatGPT Enterprise" ;;
        free)  echo "ChatGPT Free" ;;
        "")    ;;
        *)     printf 'ChatGPT %s\n' "$(printf '%s' "$raw" | sed 's/\b\(.\)/\u\1/g')" ;;
    esac
}

# ------------------------------------------------- other agents in the system
# The tariff is read where you can reach it; does not give out limits
# now no one except Claude. An empty list view draws as “no data” rather than
# as zero load - the difference is important: zero would mean that it is not consumed
# nothing, but in reality we just don’t know.
#
# The list is precisely an enumeration, and not “everything that looks like an agent”: under the general
# the template gets too many strangers, and it’s cheaper to miss the name,
# than showing a random binary in the window.
other_agent() {
    local bin="$1" name="$2" plan="${3:-}"
    command -v "$bin" >/dev/null 2>&1 || return 1
    local ver; ver="$("$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    jq -cn --arg id "$bin" --arg name "$name" --arg ver "$ver" --arg plan "$plan" '
        { id: $id, name: $name, version: $ver, plan: $plan,
          note: "unsupported", fetchedAt: 0, limits: [] }'
}

agents='[]'
add() {
    local one="$1"
    [ -n "$one" ] || return 0
    agents="$(printf '%s' "$agents" | jq -c --argjson one "$one" '. + [$one]')"
}

add "$(claude_json || true)"
add "$(other_agent codex        "Codex CLI"     "$(codex_plan)" || true)"
add "$(other_agent antigravity  "Antigravity"   || true)"
add "$(other_agent gemini       "Gemini CLI"    || true)"
add "$(other_agent opencode     "OpenCode"      || true)"
add "$(other_agent cursor-agent "Cursor Agent"  || true)"
add "$(other_agent windsurf     "Windsurf"      || true)"
add "$(other_agent copilot      "GitHub Copilot" || true)"
add "$(other_agent amp          "Amp"           || true)"
add "$(other_agent aider        "Aider"         || true)"
add "$(other_agent goose        "Goose"         || true)"
add "$(other_agent crush        "Crush"         || true)"
add "$(other_agent droid        "Droid"         || true)"
add "$(other_agent openhands    "OpenHands"     || true)"
add "$(other_agent qwen         "Qwen Code"     || true)"

printf '%s' "$agents" | jq -c --argjson now "$(date +%s%3N)" '{ now: $now, agents: . }'
