#!/bin/bash

eww open-many bar_panel launcher_panel wallpaper_panel wifi_panel monitor_panel info_panel notifications_popup_panel clipboard_panel

if [ "$0" != "$BASH_SOURCE" ]; then
    return
fi

cd "$HOME"/.config/eww/background_scripts

bash ./panel_backend.sh launcher &
bash ./panel_backend.sh clipboard &
bash ./panel_backend.sh wifi &
bash ./panel_backend.sh monitor &

bash ./workspace_backend.sh &

bash ./wallpaper_backend.sh &

python3-eww notifications.py &
python3-eww weather.py &

cd "$HOME"/.config/eww/external_scripts

bash ./update_fan_mode.sh
bash ./update_light.sh
bash ./update_vol.sh
