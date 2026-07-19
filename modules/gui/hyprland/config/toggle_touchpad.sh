#!/bin/bash

DEVICE="elan1201:00-04f3:3098-touchpad"
VAR="device[$DEVICE]:enabled"
STATE_FILE="$HOME/.cache/touchpad_state"

last="$(cat "$STATE_FILE" 2>/dev/null || echo "true")"

if [ "$1" = "init" ]; then
    echo "$last" >"$STATE_FILE"
    hyprctl keyword "$VAR" "$last"
    exit 0
fi

if [ "$last" = "true" ]; then
    hyprctl keyword "$VAR" false
    echo "false" >"$STATE_FILE"
    notify-send "Touchpad disabled"
else
    hyprctl keyword "$VAR" true
    echo "true" >"$STATE_FILE"
    notify-send "Touchpad enabled"
fi
