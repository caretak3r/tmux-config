#!/bin/sh
# tmux HUD line from live CPU, memory and network samples.
#   hud.sh          neon-hud row: CPU sparkline, memory gauge, net throughput, load
#   hud.sh signal   phosphor row: scope traces with decay, RX/TX lamps, bus hex, binary seconds
# Each call appends one sample to $STATE, so the 1s status refresh renders deltas.

mode=$1
STATE="${TMPDIR:-/tmp}/tmux-hud.state"

ncpu=$(sysctl -n hw.ncpu)
cpu=$(ps -A -o %cpu= | awk -v n="$ncpu" '{ s += $1 } END { v = s / n; print int(v > 100 ? 100 : v) }')
mem=$((100 - $(sysctl -n kern.memorystatus_level)))
load=$(sysctl -n vm.loadavg | awk '{ print $2 }')
iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
set -- $(netstat -ibn -I "${iface:-en0}" 2>/dev/null | awk 'NR == 2 { print $7, $10 }')

awk -v cpu="$cpu" -v mem="$mem" -v load="$load" -v rx="${1:-0}" -v tx="${2:-0}" \
	-v now="$(date +%s)" -v state="$STATE" -v mode="$mode" '
function heat(p) { return p < 50 ? "#00e5ff" : p < 80 ? "#ffb000" : "#ff2a6d" }
# phosphor decay: the newest samples glow, older ones fade out.
# ac=1 scales to the window min..max (like scope AC coupling) so small swings still move.
function trace(arr, from, to, scale, ac,   g, s, i, age, c, lo, v) {
	split("⎽ ⎼ ─ ⎻ ⎺", g, " ")
	lo = 0
	if (ac) {
		lo = arr[from]; scale = arr[from]
		for (i = from; i <= to; i++) { if (arr[i] < lo) lo = arr[i]; if (arr[i] > scale) scale = arr[i] }
		scale = scale - lo < 4 ? 4 : scale - lo
	}
	for (i = from; i <= to; i++) {
		age = to - i
		c = age < 2 ? "#ffb000" : age < 6 ? "#c98a00" : age < 11 ? "#6b4a00" : "#3d2a00"
		v = int((arr[i] - lo) * 4 / scale)
		s = s "#[fg=" c "]" g[(v > 4 ? 4 : v) + 1]
	}
	return s
}
function lamp(r) {
	return r >= 1048576 ? "#[fg=#ffb000,bold]◉#[nobold]" : r >= 10240 ? "#[fg=#c98a00]◉" : r > 0 ? "#[fg=#6b4a00]◉" : "#[fg=#3d2a00]○"
}
function signal(   lbl, b, sec, i) {
	lbl = "#[fg=#6b4a00]"
	printf "%sCPU %s %sNET %s ", lbl, trace(h, start, n, 0, 1), lbl, trace(nh, nstart, m, 4, 0)
	printf "%sRX%s %sTX%s ", lbl, lamp(drx), lbl, lamp(dtx)
	printf "%sBUS #[fg=#c98a00]%04X:%04X ", lbl, int(drx) % 65536, int(dtx) % 65536
	sec = now % 60
	for (i = 5; i >= 0; i--) b = b (int(sec / 2 ^ i) % 2 ? "#[fg=#ffb000]▮" : "#[fg=#3d2a00]▯")
	printf "%s", b
}
function human(b,   u, i) {
	split("B K M G", u, " "); i = 1
	while (b >= 1024 && i < 4) { b /= 1024; i++ }
	return sprintf(b < 10 && i > 1 ? "%.1f%s" : "%d%s", b, u[i])
}
BEGIN {
	while ((getline line < state) > 0) {
		split(line, f, " ")
		if (f[1] == "hist") hist = substr(line, 6)
		else if (f[1] == "neth") neth = substr(line, 6)
		else if (f[1] == "net") { pt = f[2]; prx = f[3]; ptx = f[4] }
		else if (f[1] == "rate") { lrx = f[2]; ltx = f[3] }
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
	# Same-second calls (several clients) reuse the last stored sample and rates.
	if (dt <= 0 && pt) { now = pt; rx = prx; tx = ptx; drx = lrx; dtx = ltx }

	# net history as a 0-4 level on a log scale (100B/s .. 100MB/s)
	lvl = drx + dtx > 100 ? int((log(drx + dtx) / log(10) - 2) * 5 / 6) : 0
	m = split(neth " " (lvl > 4 ? 4 : lvl), nh, " ")
	nstart = m > 16 ? m - 15 : 1
	nkeep = ""
	for (i = nstart; i <= m; i++) nkeep = nkeep " " nh[i]

	print "hist" keep > (state ".tmp")
	print "neth" nkeep > (state ".tmp")
	print "net", now, rx, tx > (state ".tmp")
	print "rate", drx, dtx > (state ".tmp")

	if (mode == "signal") { signal(); exit }

	dim = "#[fg=#4a5a70]"; sep = " #[fg=#1f2a3a]┃ "
	printf "%sCPU %s #[fg=%s,bold]%3d%%#[nobold]", dim, spark, heat(cpu), cpu
	printf "%s%sMEM #[fg=%s]%s %3d%%", sep, dim, heat(mem), gauge, mem
	printf "%s%sNET #[fg=#b6ff00]⇣%6s #[fg=#ff2bd6]⇡%6s", sep, dim, human(drx), human(dtx)
	printf "%s%sLOAD #[fg=#c0caf5]%s ", sep, dim, load
}' && mv -f "$STATE.tmp" "$STATE"
