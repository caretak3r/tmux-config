#!/bin/sh
# fzf window jumper across every session, with a live preview of the target window.
target=$(tmux list-windows -a -F '#{session_name}:#{window_index}	#{window_name}	#{pane_current_command}	#{b:pane_current_path}' |
	fzf --reverse --delimiter='\t' --tabstop=4 --prompt='jump ❯ ' \
		--preview 'tmux capture-pane -ep -t {1}' --preview-window=right,60% |
	cut -f1)
[ -n "$target" ] && tmux switch-client -t "$target"
