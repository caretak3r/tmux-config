#!/bin/sh

CACHE="${TMUX_PUBLIC_IP_CACHE:-${TMPDIR:-/tmp}/tmux-public-ip}"
TTL="${TMUX_PUBLIC_IP_TTL:-300}"
URL="${TMUX_PUBLIC_IP_URL:-https://ifconfig.co/}"

now=$(date +%s)
mtime=$(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE" 2>/dev/null || printf 0)

if [ -s "$CACHE" ] && [ "$((now - mtime))" -lt "$TTL" ]; then
	ip=$(cat "$CACHE" 2>/dev/null)
else
	ip=$(curl -fsS --max-time 2 "$URL" 2>/dev/null | tr -d '\r\n' | awk 'NF { print $1; exit }')
	[ -n "$ip" ] && printf '%s\n' "$ip" >"$CACHE"
fi

[ -n "$ip" ] && printf ' 󰖟 wan %s' "$ip"
