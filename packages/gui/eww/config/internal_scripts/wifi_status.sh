#!/bin/bash

update_wifi_status() {
    wifi_info=$(nmcli -t -f active,ssid dev wifi | grep '^yes')
    ssid=$(echo "$wifi_info" | cut -d: -f2)

    echo "{\"icon\": \" \", \"ssid\": \"${ssid^^}\", \"strength\": 1}"
}

update_wifi_status

nmcli monitor | while read -r line; do
    if [[ "$line" == *"Networkmanager is now in the '"@(connected|disconnected)"' state"* ]]; then
        if [[ "$line" == *"dis"* ]]; then
            echo '{"icon": " ", "ssid": "Disconnected", "strength": 0}'
        else
            update_wifi_status
        fi
    fi
done
