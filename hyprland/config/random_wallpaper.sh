#!/bin/bash
WALLPAPER_DIR="$HOME/.config/hypr/wallpapers"

# -ge 3 because original, current and grep process
if [ $(ps aux | grep bash | grep random_wallpaper.sh | wc -l) -ge 3 ]; then
    exit 1
fi

while true; do
	selected_wallpaper=$(
		find -L "${WALLPAPER_DIR}" -type f | shuf -n 1
	)

	swww img "$selected_wallpaper" --transition-type fade --transition-fps 60 --transition-duration 5

	sleep 2

	wal -i "$selected_wallpaper" -n 

	swaync-client --reload-css
	# cat ~/.cache/wal/colors-kitty.conf > ~/.config/kitty/current-theme.conf
	# pywalfox update

	sleep 300
done
