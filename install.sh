#!/bin/sh
# Install this tmux setup on a Mac:
#   git clone https://github.com/caretak3r/tmux-config ~/.config/tmux && ~/.config/tmux/install.sh
# Env: TMUX_THEME=<name> picks the first theme (default adventure); SKIP_BREW=1 skips Homebrew.
set -eu

conf="$HOME/.config/tmux"
omt="$HOME/.local/share/tmux/oh-my-tmux"
omt_rev=af33f07134b76134acca9d01eacbdecca9c9cda6 # oh-my-tmux commit this config is tested against

[ "$(cd "$(dirname "$0")" && pwd -P)" = "$(cd "$conf" 2>/dev/null && pwd -P)" ] || {
	echo "clone this repo to $conf first" >&2
	exit 1
}

if [ "${SKIP_BREW:-}" != 1 ]; then
	command -v brew >/dev/null || { echo "install Homebrew first: https://brew.sh" >&2; exit 1; }
	brew install tmux fzf btop git
	brew install --cask font-agave-nerd-font
fi

if [ ! -d "$omt/.git" ]; then
	git clone -q https://github.com/gpakosz/.tmux.git "$omt"
fi
git -C "$omt" fetch -q origin "$omt_rev" 2>/dev/null || true
git -C "$omt" checkout -q "$omt_rev"
ln -sfn "$omt/.tmux.conf" "$conf/tmux.conf"

# tmux reads ~/.tmux.conf before ~/.config/tmux/tmux.conf, so move an old one aside
if [ -e "$HOME/.tmux.conf" ] || [ -L "$HOME/.tmux.conf" ]; then
	mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak-$(date +%Y%m%d%H%M%S)"
	echo "moved old ~/.tmux.conf aside"
fi

theme="${TMUX_THEME:-adventure}"
[ -f "$conf/themes/$theme.conf" ] || { echo "no theme '$theme' in $conf/themes" >&2; exit 1; }
[ -e "$conf/themes/current.conf" ] || ln -s "$theme.conf" "$conf/themes/current.conf"

echo "done: start tmux; plugins install on first launch (prefix is C-a, themes on C-a C-t)"
