#!/bin/sh
# tmux status segment: IPv4 of the wired LAN or of Wi-Fi.
#   net-ip.sh lan   -> "󰈀 lan 192.168.0.184"   (empty if no wired link)
#   net-ip.sh wifi  -> " 󰖩 wifi 192.168.0.7"   (empty if Wi-Fi is down)
# Colours are applied by the caller in tmux.conf.local, one per interface.

CACHE="${TMPDIR:-/tmp}/tmux-wifi-device"

# networksetup takes ~200ms and the Wi-Fi device name never changes, so cache it.
if [ ! -s "$CACHE" ] || [ -n "$(find "$CACHE" -mmin +60 2>/dev/null)" ]; then
	networksetup -listallhardwareports 2>/dev/null |
		awk '/^Hardware Port: Wi-Fi$/ { getline; print $2 }' >"$CACHE"
fi
wifi_dev=$(cat "$CACHE" 2>/dev/null)

case "$1" in
wifi)
	[ -n "$wifi_dev" ] || exit 0
	ip=$(ipconfig getifaddr "$wifi_dev" 2>/dev/null) || exit 0
	[ -n "$ip" ] && printf ' 󰖩 wifi %s' "$ip"
	;;
lan)
	for dev in $(ifconfig -l); do
		case "$dev" in
		en* | bridge*) ;;
		*) continue ;;
		esac
		[ "$dev" = "$wifi_dev" ] && continue
		ip=$(ipconfig getifaddr "$dev" 2>/dev/null) || continue
		if [ -n "$ip" ]; then
			printf '󰈀 lan %s' "$ip"
			exit 0
		fi
	done
	;;
esac
