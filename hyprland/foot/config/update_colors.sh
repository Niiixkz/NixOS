#!/bin/bash

TEMPLATE="$HOME/.config/foot/template.ini"
CONFIG="$HOME/.config/foot/foot.ini"
COLORS="$HOME/.cache/wal/colors-kitty.conf"

config_content=$(<"$TEMPLATE")

replace() {
    local color_wal="$1"
    local color_foot="$2"

    color=$(grep "$color_wal" "$COLORS" | sed -E 's/.*#([0-9a-fA-F]{6}).*/\1/')
    config_content=$(echo "$config_content" | sed -E "s|^${color_foot}=.*|${color_foot}=${color}|")
}

replace "background" "background"
replace "foreground" "foreground"
replace "background" "selection-foreground"
replace "foreground" "selection-background"

replace "color0" "regular0"
replace "color1       " "regular1" # That space are because there 10 11 ... 
replace "color2" "regular2"
replace "color3" "regular3"
replace "color4" "regular4"
replace "color5" "regular5"
replace "color6" "regular6"
replace "color7" "regular7"
replace "color8" "regular8"
replace "color9" "regular9"
replace "color10" "regular10"
replace "color11" "regular11"
replace "color12" "regular12"
replace "color13" "regular13"
replace "color14" "regular14"
replace "color15" "regular15"

echo "$config_content" > "$CONFIG"
