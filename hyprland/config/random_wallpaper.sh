#!/bin/bash
WALLPAPER_DIR="$HOME/wallpapers/walls"

# if ps aux | grep "swww-daemon & bash /home/niiixkz/.config/hypr/random_wallpaper.sh" | grep -v grep > /dev/null; then
#     exit 1
# fi

if [ $(ps aux | grep "swww-daemon & bash /home/niiixkz/.config/hypr/random_wallpaper.sh" | grep -v grep | wc -l) -ge 2 ]; then
    exit 1
fi

while true; do
	selected_wallpaper=$(
		find "${WALLPAPER_DIR}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | shuf -n 1
	)

	swww img "$selected_wallpaper" --transition-type any --transition-fps 60 --transition-duration .5

	wal -i "$selected_wallpaper" -n 

	# swaync-client --reload-css
	# cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf
	# pywalfox update

	sleep 600
done
