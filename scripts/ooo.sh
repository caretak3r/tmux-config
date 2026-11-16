#!/bin/sh
# Land of Ooo stage (pixel art rendered by ooo.pl), part of the adventure theme.
#   ooo.sh toggle   open/close a 9-row stage pane along the bottom of the window
#   ooo.sh pane     run the stage in the current pane
#   ooo.sh sync     close every stage pane unless adventure is the active theme

stages() { tmux list-panes -a -F '#{pane_id} #{pane_title}' | awk '$2 == "ooo" { print $1 }'; }

case "$1" in
pane)
	tmux select-pane -t "$TMUX_PANE" -T ooo
	exec "$HOME/.config/tmux/scripts/ooo.pl"
	;;
toggle)
	p=$(tmux list-panes -F '#{pane_id} #{pane_title}' | awk '$2 == "ooo" { print $1; exit }')
	if [ -n "$p" ]; then
		tmux kill-pane -t "$p"
	else
		tmux split-window -fvd -l 9 "$HOME/.config/tmux/scripts/ooo.sh pane"
	fi
	;;
sync)
	[ "$(readlink "$HOME/.config/tmux/themes/current.conf")" = adventure.conf ] && exit 0
	for p in $(stages); do tmux kill-pane -t "$p"; done
	;;
esac
