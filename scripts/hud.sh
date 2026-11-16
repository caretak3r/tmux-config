#!/bin/sh
# tmux HUD line: CPU sparkline, memory gauge, net throughput, load average.
# Each call appends one sample to $STATE, so the 1s status refresh renders deltas.

STATE="${TMPDIR:-/tmp}/tmux-hud.state"

ncpu=$(sysctl -n hw.ncpu)
cpu=$(ps -A -o %cpu= | awk -v n="$ncpu" '{ s += $1 } END { v = s / n; print int(v > 100 ? 100 : v) }')
mem=$((100 - $(sysctl -n kern.memorystatus_level)))
load=$(sysctl -n vm.loadavg | awk '{ print $2 }')
iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
set -- $(netstat -ibn -I "${iface:-en0}" 2>/dev/null | awk 'NR == 2 { print $7, $10 }')

awk -v cpu="$cpu" -v mem="$mem" -v load="$load" -v rx="${1:-0}" -v tx="${2:-0}" \
	-v now="$(date +%s)" -v state="$STATE" '
function heat(p) { return p < 50 ? "#00e5ff" : p < 80 ? "#ffb000" : "#ff2a6d" }
function human(b,   u, i) {
	split("B K M G", u, " "); i = 1
	while (b >= 1024 && i < 4) { b /= 1024; i++ }
	return sprintf(b < 10 && i > 1 ? "%.1f%s" : "%d%s", b, u[i])
}
BEGIN {
	while ((getline line < state) > 0) {
		split(line, f, " ")
		if (f[1] == "hist") hist = substr(line, 6)
		else if (f[1] == "net") { pt = f[2]; prx = f[3]; ptx = f[4] }
	}
	n = split(hist " " cpu, h, " ")
	start = n > 16 ? n - 15 : 1
	# Autoscale to the window peak (floor 20%) so a mostly idle 32-core box still shows shape.
	top = 20
	for (i = start; i <= n; i++) if (h[i] > top) top = h[i]
	split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", bar, " ")
	spark = ""; keep = ""
	for (i = start; i <= n; i++) {
		spark = spark "#[fg=" heat(h[i]) "]" bar[int(h[i] * 7 / top) + 1]
		keep = keep " " h[i]
	}

	gauge = ""
	for (i = 1; i <= 10; i++) gauge = gauge (i * 10 <= mem + 5 ? "▰" : "▱")

	dt = now - pt
	drx = (pt && dt > 0 && rx >= prx) ? (rx - prx) / dt : 0
	dtx = (pt && dt > 0 && tx >= ptx) ? (tx - ptx) / dt : 0
	# Same-second calls (several clients) reuse the last stored sample.
	if (dt <= 0 && pt) { now = pt; rx = prx; tx = ptx }

	print "hist" keep > (state ".tmp")
	print "net", now, rx, tx > (state ".tmp")

	dim = "#[fg=#4a5a70]"; sep = " #[fg=#1f2a3a]┃ "
	printf "%sCPU %s #[fg=%s,bold]%3d%%#[nobold]", dim, spark, heat(cpu), cpu
	printf "%s%sMEM #[fg=%s]%s %3d%%", sep, dim, heat(mem), gauge, mem
	printf "%s%sNET #[fg=#b6ff00]⇣%6s #[fg=#ff2bd6]⇡%6s", sep, dim, human(drx), human(dtx)
	printf "%s%sLOAD #[fg=#c0caf5]%s ", sep, dim, load
}' && mv -f "$STATE.tmp" "$STATE"
