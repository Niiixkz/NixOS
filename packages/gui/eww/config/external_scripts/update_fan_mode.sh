#!/bin/bash

current=$(asusctl profile -p | grep -oE 'Quiet|Balanced|Performance')
eww update fan_mode="$current"

if [ "$0" != "$BASH_SOURCE" ]; then
    return
fi

if [[ $(eww get monitor_panel_open) == "false" ]]; then
    eww update monitor_panel_open=true
fi

echo 3 >"/tmp/eww_monitor_panel_trigger/$$"
