#!/bin/bash

second_line=$(mpc | sed -n '2p')

if [[ "$second_line" =~ ([0-9]+):([0-9]+)/ ]]; then
    mins=${BASH_REMATCH[1]}
    secs=${BASH_REMATCH[2]}
    pos_sec=$((10#$mins * 60 + 10#$secs))
    pos_str=$(printf "%d:%02d" "$((10#$mins))" "$((10#$secs))")
else
    pos_sec=""
    pos_str=""
fi

jq -n -c \
    --arg sec "$pos_sec" \
    --arg str "$pos_str" \
    '{sec: $sec, str: $str}'
