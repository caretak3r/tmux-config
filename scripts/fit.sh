#!/bin/sh
# fit.sh [client columns]: run by the client-attached/client-resized hooks with
# the client's width, and with no argument on every config load (then it asks
# tmux for the most recent client's width; with no client attached it does nothing).
# Records the width the status bar spans (the client's, not the window's) and,
# when it crosses 220 columns, re-sources only themes/_info.conf, which switches
# between one info row (wide) and two (narrow). A full config reload here would
# start a second oh-my-tmux plugin update that races the first one's git calls.
w=${1:-$(tmux display -p '#{client_width}' 2>/dev/null)}
[ "${w:-0}" -gt 0 ] 2>/dev/null || exit 0
tmux set -g @cols "$w"
[ "$w" -ge 220 ] && want=wide || want=narrow
[ "$want" = "$(tmux show -gv @layout 2>/dev/null)" ] || tmux source-file ~/.config/tmux/themes/_info.conf
