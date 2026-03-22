#!/bin/sh
# export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
exec /etc/profiles/per-user/$USER/bin/fish --login
