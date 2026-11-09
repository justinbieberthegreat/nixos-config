#!/usr/bin/env bash

loginctl lock-session
sleep 10

if pgrep -x hyprlock >/dev/null 2>&1; then
    niri msg action power-off-monitors
fi
