#!/bin/bash
# kill existing if running
rm calla-0.3-2-x86_64.pkg.tar.zst
rm calla-debug-0.3-2-x86_64.pkg.tar.zst
makepkg -si
pkill -f "Xephyr :1" 2>/dev/null
Xephyr :1 -screen 1280x800 &
sleep 0.5
DISPLAY=:1 calla
# DISPLAY=:1 xrdb /usr/share/calla/Xresources
# DISPLAY=:1 awesome --config /usr/share/calla/desktop/rc.lua
