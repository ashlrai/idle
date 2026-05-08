#!/bin/zsh
# Lightweight earnings + activity rollup. Run anytime from Terminal:
#   ~/Desktop/passive\ income/earnings_summary.sh
#
# Pulls what we can read locally (Verus on-chain balance, app process state,
# active network connections). Web-dashboard balances stay in their respective
# WKWebViews — open Idle → Earnings for those.

set -u

VERUS_CLI="$HOME/Downloads/verus-cli/verus"
EARNINGS_LOG="$HOME/Library/Application Support/Idle/earnings.jsonl"

bold()  { printf "\033[1m%s\033[0m\n" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }
yellow(){ printf "\033[33m%s\033[0m" "$1"; }
red()   { printf "\033[31m%s\033[0m" "$1"; }
gray()  { printf "\033[90m%s\033[0m" "$1"; }

now="$(date '+%Y-%m-%d %H:%M:%S')"

bold "Idle earnings rollup — $now"
echo

# -------------------------------------------------------------------
# DePIN bandwidth apps — connection state as proxy for "earning right now"
# -------------------------------------------------------------------
bold "DePIN bandwidth apps"
for entry in \
    "Pawns:pawns" \
    "Grass:Grass" \
    "Honeygain:Honeygain" \
    "EarnApp:earnapp" \
    "MystNodes:myst" \
    "Nodepay:Nodepay"
do
    name="${entry%%:*}"
    pat="${entry##*:}"
    count=$(lsof -i -n -P 2>/dev/null | grep -i "$pat" | grep -c ESTABLISHED)
    proc=$(pgrep -lf "$pat" 2>/dev/null | grep -v grep | wc -l | tr -d ' ')
    if [[ $count -gt 0 ]]; then
        printf "  %-12s %s active conns · %s procs\n" "$name" "$(green "$count")" "$proc"
    elif [[ $proc -gt 0 ]]; then
        printf "  %-12s %s 0 active conns · %s procs (sparse/idle, normal)\n" "$name" "$(yellow "")" "$proc"
    else
        printf "  %-12s %s not running\n" "$name" "$(red "✗")"
    fi
done
echo

# -------------------------------------------------------------------
# Verus mining + wallet balance
# -------------------------------------------------------------------
bold "Verus mining"
if pgrep -x verusd > /dev/null 2>&1; then
    if [[ -x "$VERUS_CLI" ]]; then
        info=$("$VERUS_CLI" getmininginfo 2>/dev/null)
        balance=$("$VERUS_CLI" getbalance 2>/dev/null)
        unconfirmed=$("$VERUS_CLI" getunconfirmedbalance 2>/dev/null)
        immature=$("$VERUS_CLI" getwalletinfo 2>/dev/null | grep immature_balance | awk -F: '{gsub(/[ ,]/,"",$2); print $2}')

        hashps=$(echo "$info" | grep '"localhashps"' | awk -F: '{gsub(/[ ,]/,"",$2); print $2}')
        netps=$(echo "$info" | grep '"networkhashps"' | awk -F: '{gsub(/[ ,]/,"",$2); print $2}')
        gen=$(echo "$info" | grep '"generate"' | awk -F: '{gsub(/[ ,]/,"",$2); print $2}')
        blocks=$(echo "$info" | grep '"blocks"' | head -1 | awk -F: '{gsub(/[ ,]/,"",$2); print $2}')

        if [[ -n "$hashps" && "$hashps" != "0" ]]; then
            printf "  hashrate    %s Mh/s\n" "$(green "$(awk -v h="$hashps" 'BEGIN{printf "%.2f", h/1e6}')")"
            printf "  network     %s GH/s\n" "$(awk -v n="$netps" 'BEGIN{printf "%.1f", n/1e9}')"
            printf "  share       %s%% of network\n" "$(awk -v h="$hashps" -v n="$netps" 'BEGIN{printf "%.5f", (h/n)*100}')"
        fi
        printf "  generate    %s\n" "$gen"
        printf "  chain       block %s\n" "$blocks"
        printf "  balance     %s VRSC confirmed · %s immature · %s unconfirmed\n" \
               "$(green "${balance:-0}")" "${immature:-0}" "${unconfirmed:-0}"
    else
        printf "  %s verusd running but verus CLI missing\n" "$(yellow "?")"
    fi
else
    printf "  %s verusd not running\n" "$(red "✗")"
    printf "  %s start with: %s\n" "$(gray ' →')" "~/Downloads/verus-cli/verusd -daemon"
fi
echo

# -------------------------------------------------------------------
# Idle running state + earnings log
# -------------------------------------------------------------------
bold "Idle"
if pgrep -f "/Applications/Idle.app/Contents/MacOS/Idle" > /dev/null 2>&1; then
    ver=$(defaults read /Applications/Idle.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null)
    printf "  status      %s running · v%s\n" "$(green "✓")" "$ver"
else
    printf "  status      %s not running\n" "$(red "✗")"
fi

if [[ -f "$EARNINGS_LOG" ]]; then
    lines=$(wc -l < "$EARNINGS_LOG" | tr -d ' ')
    printf "  history     %s readings logged at %s\n" "$lines" "$EARNINGS_LOG"
else
    printf "  history     %s empty — open Idle → Dashboards once to start scraping\n" "$(yellow "—")"
fi
echo

# -------------------------------------------------------------------
# Mac sleep prevention
# -------------------------------------------------------------------
bold "Sleep prevention"
if pmset -g assertions 2>/dev/null | grep -q 'PreventUserIdleSystemSleep.*caffeinate'; then
    uptime=$(pmset -g assertions 2>/dev/null | awk '/caffeinate/{print $4; exit}')
    printf "  %s caffeinate active · %s\n" "$(green "✓")" "${uptime:-uptime unknown}"
else
    printf "  %s caffeinate not asserting — Mac may sleep and stop earning\n" "$(red "✗")"
fi
echo

# -------------------------------------------------------------------
# Public IP check (residential ISP confirms still real)
# -------------------------------------------------------------------
bold "Public IP"
if ip_info=$(curl -s --max-time 5 https://ipapi.co/json/ 2>/dev/null); then
    ip=$(echo "$ip_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ip','?'))" 2>/dev/null)
    org=$(echo "$ip_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('org','?'))" 2>/dev/null)
    city=$(echo "$ip_info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('city','?'))" 2>/dev/null)
    printf "  %s · %s, %s\n" "$ip" "$city" "$org"
else
    printf "  %s ipapi.co unreachable\n" "$(yellow "—")"
fi

echo
gray "Web-dashboard balances are auth-gated. Click Idle in menu bar → Earnings"
gray "to see Pawns / Grass / Honeygain / EarnApp / MystNodes / Nodepay USD totals."
echo
