#!/bin/sh
# Status-line animation frames keyed to the epoch second (status-interval 1).
# Colours are hex without '#' (tmux would read '#x' inside #() as a format).
#   anim.sh scan <width> <hot> <dim>    KITT scanner bouncing across <width> cells
#   anim.sh pulse <on> <off> [glyph]    glyph alternating between two colours
#   anim.sh spin <colour>               braille spinner
#   anim.sh train <width> <colour>      logic-analyzer square wave scrolling left
#   anim.sh rainbow <text> <colours..>  text with a colour band sliding through it
#   anim.sh cycle <secs> <items..>      show the next item every <secs> seconds

# tmux jobs may run without a UTF-8 locale; awk then counts bytes instead of characters.
# Multibyte sprites live in ooo.pl instead: this awk mangles them even with the locale set.
export LC_ALL=en_US.UTF-8
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
train)
	awk -v t="$t" -v w="${2:-16}" -v c="$3" 'BEGIN {
		p = "0011010001110100101100011010"; n = length(p)
		printf "#[fg=#%s]", c
		for (i = 0; i < w; i++) printf "%s", (substr(p, (t + i) % n + 1, 1) == "1" ? "⎺" : "⎽")
	}'
	;;
rainbow)
	text=$2; shift 2
	awk -v t="$t" -v s="$text" -v cols="$*" 'BEGIN {
		n = split(cols, c, " ")
		for (i = 1; i <= length(s); i++) printf "#[fg=#%s]%s", c[((i - t) % n + n) % n + 1], substr(s, i, 1)
	}'
	;;
cycle)
	p=$2; shift 2
	i=$((t / p % $# + 1))
	eval "s=\${$i}"
	printf '%s' "$s"
	;;
esac
