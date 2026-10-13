#!/usr/bin/env bash
# Brightness keys. All work is in ~/.config/zenith/scripts/brightness.sh:
# the choice of method lives there (internal matrix or monitor via DDC/CI),
# step with acceleration while holding and pill notification.
#
# The separate file remains here because it is referenced by keybindings.lua
# and it is located in ~/.local/bin, that is, in PATH; brightness settings
# belong to the shell, not the system, and duplicate logic in two places
# would mean repairing it twice.
exec "${XDG_CONFIG_HOME:-$HOME/.config}/zenith/scripts/brightness.sh" "$@"
