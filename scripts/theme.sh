#!/bin/sh
# Theme switcher. Themes are themes/<name>.conf; the active one is the
# themes/current.conf symlink, so the choice survives a server restart.
#   theme.sh menu [client]   pop up a picker (keys 1-9)
#   theme.sh next            cycle to the next theme
#   theme.sh <name>          switch to <name>

dir="$HOME/.config/tmux/themes"
self="$HOME/.config/tmux/scripts/theme.sh"
themes=$(ls "$dir" | sed -n 's/^\([^_].*\)\.conf$/\1/p' | grep -vx current)
current=$(basename "$(readlink "$dir/current.conf")" .conf)

case "$1" in
menu)
	client=$2
	set --
	for t in $themes; do
		i=$((i + 1))
		mark=" "; [ "$t" = "$current" ] && mark="●"
		set -- "$@" "$mark $t" "$i" "run-shell '$self $t'"
	done
	exec tmux display-menu ${client:+-c "$client"} -T "#[align=centre] themes " "$@"
	;;
next)
	t=$(printf '%s\n' $themes | grep -A1 -x "$current" | sed -n 2p)
	exec "$self" "${t:-$(printf '%s\n' $themes | head -1)}"
	;;
"")
	echo "usage: theme.sh menu|next|<name>   (themes: $(echo $themes))" >&2
	exit 2
	;;
*)
	if [ ! -f "$dir/$1.conf" ]; then
		tmux display "theme: no such theme '$1'"
		exit 1
	fi
	ln -sfn "$1.conf" "$dir/current.conf"
	tmux source-file "$HOME/.config/tmux/tmux.conf" \; display "theme: $1"
	;;
esac
