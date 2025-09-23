#!/bin/bash

value=$(brightnessctl get)
max=$(brightnessctl max)
percent=$((value * 100 / max))

eww update light="${percent}"

if [ "$0" != "$BASH_SOURCE" ]; then
    return
fi

if [[ $(eww get monitor_panel_open) == "false" ]]; then
    eww update monitor_panel_open=true
fi

echo 3 >"/tmp/eww_monitor_panel_trigger/$$"
