#!/bin/sh
# Finn & Jake in the Land of Ooo (scene rendering lives in ooo.pl).
#   ooo.sh status <width>   one 1 fps frame for the tmux status line
#   ooo.sh toggle           open/close a smooth 8 fps scene pane along the bottom of the window
#   ooo.sh pane             run the smooth scene in the current pane

scene="$HOME/.config/tmux/scripts/ooo.pl"

case "$1" in
status)
	exec "$scene" status "${2:-48}"
	;;
pane)
	tmux select-pane -t "$TMUX_PANE" -T ooo
	exec "$scene" pane
	;;
toggle)
	p=$(tmux list-panes -F '#{pane_id} #{pane_title}' | awk '$2 == "ooo" { print $1; exit }')
	if [ -n "$p" ]; then
		tmux kill-pane -t "$p"
	else
		tmux split-window -fvd -l 3 "$HOME/.config/tmux/scripts/ooo.sh pane"
	fi
	;;
esac
