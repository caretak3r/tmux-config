#!/bin/sh

df -k / 2>/dev/null |
	awk 'NR == 2 && $2 > 0 {
		free_pct = int(($4 / $2) * 100 + 0.5)
		total = $2 * 1024
		split("B KB MB GB TB PB", unit, " ")
		i = 1
		while (total >= 1000 && i < 6) {
			total /= 1000
			i++
		}
		size = total >= 10 || i == 1 ? sprintf("%.0f%s", total, unit[i]) : sprintf("%.1f%s", total, unit[i])
		printf "󰋊 %d%% - %s", free_pct, size
	}'
