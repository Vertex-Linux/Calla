#!/bin/bash
set -e

# Dev mode: copy source files directly instead of going through makepkg/pacman,
# which fails because sudo needs a TTY that makepkg's subshell doesn't have.
sudo cp -rT src/usr/share/calla /usr/share/calla
sudo install -Dm644 src/etc/pam.d/awesome /etc/pam.d/awesome

pkill -f "Xephyr :1" 2>/dev/null || true
Xephyr :1 -screen 1280x800 &
sleep 0.5
DISPLAY=:1 calla
