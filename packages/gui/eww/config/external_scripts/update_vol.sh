#!/bin/bash

vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f\n", $2 * 100}')
eww update vol="$vol"

mute=0
if wpctl status | awk '/^Audio/,/^Video/' | awk '/Sinks:/, /Sources:/' | grep '\*' | grep -q 'MUTED'; then
    mute=1
fi

if [[ "${vol}" == 0 || "${mute}" == 1 ]]; then
    eww update volico="󰖁"
else
    eww update volico="󰕾"
fi

if [ "$0" != "$BASH_SOURCE" ]; then
    return
fi

if [[ $(eww get monitor_panel_open) == "false" ]]; then
    eww update monitor_panel_open=true
fi

echo 3 >"/tmp/eww_monitor_panel_trigger/$$"
