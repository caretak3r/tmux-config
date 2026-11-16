#!/bin/sh
# Status-line animation frames keyed to the epoch second (status-interval 1).
# Colours are hex without '#' (tmux would read '#x' inside #() as a format).
#   anim.sh scan <width> <hot> <dim>    KITT scanner bouncing across <width> cells
#   anim.sh pulse <on> <off> [glyph]    glyph alternating between two colours
#   anim.sh spin <colour>               braille spinner

t=$(date +%s)
case "$1" in
scan)
	awk -v t="$t" -v w="${2:-8}" -v hot="$3" -v dim="$4" 'BEGIN {
		p = t % (2 * w - 2); if (p >= w) p = 2 * w - 2 - p
		split("█ ▓ ▒", shade, " ")
		for (i = 0; i < w; i++) {
			d = i - p; if (d < 0) d = -d
			printf "#[fg=#%s]%s", (d < 2 ? hot : dim), (d < 3 ? shade[d + 1] : "░")
		}
	}'
	;;
pulse)
	[ $((t % 2)) -eq 0 ] && c=$2 || c=$3
	printf '#[fg=#%s]%s' "$c" "${4:-●}"
	;;
spin)
	set -- "$2" ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
	c=$1; shift
	eval "f=\${$((t % 10 + 1))}"
	printf '#[fg=#%s]%s' "$c" "$f"
	;;
esac
