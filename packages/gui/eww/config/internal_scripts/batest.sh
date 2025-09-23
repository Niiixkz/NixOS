#!/bin/bash

ENERGY_NOW=$(cat /sys/class/power_supply/BAT0/energy_now)
POWER_NOW=$(cat /sys/class/power_supply/BAT0/power_now)
POWER_NOW=${POWER_NOW#-}
ENERGY_FULL=$(cat /sys/class/power_supply/BAT0/energy_full)
STATUS=$(cat /sys/class/power_supply/BAT0/status)

if [ "$POWER_NOW" -ne 0 ]; then
    if [[ "$STATUS" == "Discharging" ]]; then
        MINUTES_LEFT=$((ENERGY_NOW * 60 / POWER_NOW))
        HOURS=$((MINUTES_LEFT / 60))
        MINS=$((MINUTES_LEFT % 60))
        printf "[%s] %02d h %02d min left\n" "$STATUS" "$HOURS" "$MINS"
    elif [[ "$STATUS" == "Charging" ]]; then
        DIFF=$((ENERGY_FULL - ENERGY_NOW))
        MINUTES_TO_FULL=$((DIFF * 60 / POWER_NOW))
        HOURS=$((MINUTES_TO_FULL / 60))
        MINS=$((MINUTES_TO_FULL % 60))
        printf "[%s] %02d h %02d min to full\n" "$STATUS" "$HOURS" "$MINS"
    else
        echo "0 h 0 min to full\n"
    fi
else
    printf "[%s] %s h %s min left\n" "$STATUS" "∞" "∞"
fi
