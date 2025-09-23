#!/bin/bash

if [[ $# -eq 0 ]]; then
    exit 1
fi

MONITOR_DIR="/tmp/eww_${1}_panel_trigger"

[ -d "$MONITOR_DIR" ] || mkdir -p "$MONITOR_DIR"
rm -f "$MONITOR_DIR"/*

duration=0

while file=$(inotifywait -e close_write --format '%f' "$MONITOR_DIR"); do
    duration=$(cat "$MONITOR_DIR/$file")

    if (("$duration" == 0)); then
        continue
    fi

    eww update "${1}_panel_keep_open=true"

    while file=$(inotifywait -t "$duration" -e close_write --format '%f' "$MONITOR_DIR"); do
        new_duration=$(cat "$MONITOR_DIR/$file")
        if (("$new_duration" > "$duration")); then
            duration="$new_duration"
        elif (("$new_duration" == 0)); then
            break
        fi
    done

    eww update "${1}_panel_keep_open=false"

    rm -f "$MONITOR_DIR"/*

    if [[ $(eww get "${1}_panel_hover") == "true" ]]; then
        continue
    fi

    eww update "${1}_panel_open=false"
done
