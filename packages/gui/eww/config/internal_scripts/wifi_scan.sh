#!/bin/bash

declare -A AUTO=()
while read -r conn_name; do
    ssid=$(nmcli -g 802-11-wireless.ssid connection show "$conn_name" 2>/dev/null)
    [[ -z "$ssid" ]] && continue
    AUTO["$ssid"]=$(nmcli -g connection.autoconnect connection show "$conn_name" 2>/dev/null)
done < <(nmcli -t -f NAME connection show)

declare -A SEEN=()
wifi_list=()
while IFS=: read -r inuse ssid; do
    [[ -z "$ssid" || -n "${SEEN[$ssid]}" ]] && continue
    SEEN["$ssid"]=1

    in_use=false
    [[ "$inuse" == "*" ]] && in_use=true

    autoconnect=false
    [[ "${AUTO[$ssid]}" == "yes" ]] && autoconnect=true

    wifi_list+=("$(jq -nc \
        --arg ssid "$ssid" \
        --argjson in_use "$in_use" \
        --argjson autoconnect "$autoconnect" \
        '{ssid:$ssid, in_use:$in_use, autoconnect:$autoconnect}')")
done < <(nmcli -t -f IN-USE,SSID dev wifi list)

jq -nc --argjson arr "$(printf '[%s]' "$(
    IFS=,
    echo "${wifi_list[*]}"
)")" '$arr'
