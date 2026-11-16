#!/bin/sh
# System section of every theme's info row: CPU, memory, GPU, network, load.
#   hud.sh                         neon palette: CPU sparkline, memory gauge, heat colours
#   hud.sh signal                  phosphor: scope traces with decay, RX/TX lamps, bus hex, binary seconds
#   hud.sh pal LBL VAL SEP HOT     any theme: labels, values, separators, hot (>=80%) as hex without '#'
# Each call appends one sample to $STATE, so the 1s status refresh renders deltas.

mode=${1:-neon}
STATE="${TMPDIR:-/tmp}/tmux-hud.state"

ncpu=$(sysctl -n hw.ncpu)
cpu=$(ps -A -o %cpu= | awk -v n="$ncpu" '{ s += $1 } END { v = s / n; print int(v > 100 ? 100 : v) }')
mem=$((100 - $(sysctl -n kern.memorystatus_level)))
gpu=$(ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null | sed -n 's/.*"Device Utilization %"=\([0-9]*\).*/\1/p' | head -1)
load=$(sysctl -n vm.loadavg | awk '{ print $2 }')
iface=$(route -n get default 2>/dev/null | awk '/interface:/ { print $2 }')
net=$(netstat -ibn -I "${iface:-en0}" 2>/dev/null | awk 'NR == 2 { print $7, $10 }')

awk -v cpu="$cpu" -v mem="$mem" -v gpu="${gpu:-0}" -v load="$load" -v net="$net" \
	-v now="$(date +%s)" -v state="$STATE" -v mode="$mode" -v pl="$2" -v pv="$3" -v ps="$4" -v ph="$5" '
function c(x) { return "#[fg=#" x "]" }
function heat(p) { return p < 50 ? V : p < 80 ? M : H }
# phosphor decay: the newest samples glow, older ones fade out.
# ac=1 scales to the window min..max (like scope AC coupling) so small swings still move.
function trace(arr, from, to, scale, ac,   g, s, i, age, col, lo, v) {
	split("⎽ ⎼ ─ ⎻ ⎺", g, " ")
	lo = 0
	if (ac) {
		lo = arr[from]; scale = arr[from]
		for (i = from; i <= to; i++) { if (arr[i] < lo) lo = arr[i]; if (arr[i] > scale) scale = arr[i] }
		scale = scale - lo < 4 ? 4 : scale - lo
	}
	for (i = from; i <= to; i++) {
		age = to - i
		col = age < 2 ? "ffb000" : age < 6 ? "c98a00" : age < 11 ? "6b4a00" : "3d2a00"
		v = int((arr[i] - lo) * 4 / scale)
		s = s c(col) g[(v > 4 ? 4 : v) + 1]
	}
	return s
}
function lamp(r) {
	return r >= 1048576 ? "#[fg=#ffb000,bold]◉#[nobold]" : r >= 10240 ? c("c98a00") "◉" : r > 0 ? c("6b4a00") "◉" : c("3d2a00") "○"
}
function signal(   lbl, b, sec, i) {
	lbl = c("6b4a00")
	printf "%sCPU %s %sMEM %s%d%% %sGPU %s%d%% ", lbl, trace(h, start, n, 0, 1), lbl, c("c98a00"), mem, lbl, c("c98a00"), gpu
	printf "%sNET %s %sRX%s %sTX%s ", lbl, trace(nh, nstart, m, 4, 0), lbl, lamp(drx), lbl, lamp(dtx)
	printf "%sLD %s%s %sBUS %s%04X:%04X ", lbl, c("c98a00"), load, lbl, c("c98a00"), int(drx) % 65536, int(dtx) % 65536
	sec = now % 60
	for (i = 5; i >= 0; i--) b = b (int(sec / 2 ^ i) % 2 ? c("ffb000") "▮" : c("3d2a00") "▯")
	printf "%s", b
}
function human(b,   u, i) {
	split("B K M G", u, " "); i = 1
	while (b >= 1024 && i < 4) { b /= 1024; i++ }
	return sprintf(b < 10 && i > 1 ? "%.1f%s" : "%d%s", b, u[i])
}
BEGIN {
	if (mode == "pal") { L = pl; V = pv; M = pv; S = ps; H = ph; ND = pv; NU = pv; LD = pv }
	else { L = "4a5a70"; V = "00e5ff"; M = "ffb000"; S = "1f2a3a"; H = "ff2a6d"; ND = "b6ff00"; NU = "ff2bd6"; LD = "c0caf5" }
	split(net, nb, " "); rx = nb[1] + 0; tx = nb[2] + 0

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
		spark = spark c(heat(h[i])) bar[int(h[i] * 7 / top) + 1]
		keep = keep " " h[i]
	}

	gauge = ""
	for (i = 1; i <= 10; i++) gauge = gauge (i * 10 <= mem + 5 ? "▰" : "▱")

	dt = now - pt
	drx = (pt && dt > 0 && rx >= prx) ? (rx - prx) / dt : 0
	dtx = (pt && dt > 0 && tx >= ptx) ? (tx - ptx) / dt : 0
	# Same-second calls (several clients or rows) reuse the last stored sample and rates.
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

	sep = " " c(S) "┃ "
	printf "%sCPU %s #[bold]%s%3d%%#[nobold]", c(L), spark, c(heat(cpu)), cpu
	printf "%s%sMEM %s%s %3d%%", sep, c(L), c(heat(mem)), gauge, mem
	printf "%s%sGPU %s%3d%%", sep, c(L), c(heat(gpu)), gpu
	printf "%s%sNET %s⇣%6s %s⇡%6s", sep, c(L), c(ND), human(drx), c(NU), human(dtx)
	printf "%s%sLOAD %s%s ", sep, c(L), c(LD), load
}' && mv -f "$STATE.tmp" "$STATE"
