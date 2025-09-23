#!/usr/bin/python

###################################################
###################################################
#####__        __         _   _               #####
#####\ \      / /__  __ _| |_| |__   ___ _ __ #####
##### \ \ /\ / / _ \/ _` | __| '_ \ / _ \ '__|#####
#####  \ V  V /  __/ (_| | |_| | | |  __/ |   #####
#####   \_/\_/ \___|\__,_|\__|_| |_|\___|_|   #####
###################################################
###################################################  

import json, sys, time, os
from datetime import datetime

API_TOKEN = json.load(open("/home/niiixkz/.apikeys.json", "r", encoding="utf-8"))["weatherapi"]

######## CHANGE CITY AND COUNTRY #########
CITY = "Pingtung"
##########################################

EXCLUDE = "hourly"
AQI = "no"
DAYS = 7

URL = f"http://api.weatherapi.com/v1/forecast.json?key={API_TOKEN}&q={CITY}&aqi={AQI}&days={DAYS}"

def get_icon(code):
    return {
        1000: "",
        1003: "",
        1006: "󰖐",
        1009: "",
        1030: "",
        1063: "",
        1066: "",
        1069: "",
        1072: "󰙿",
        1087: "",
        1114: "",
        1117: "",
        1135: "󰖑",
        1147: "󰖑",
        1150: "󰙿",
        1153: "󰙿",
        1168: "󰙿",
        1171: "󰙿",
        1180: "",
        1183: "",
        1186: "",
        1189: "",
        1192: "",
        1195: "",
        1198: "󰙿",
        1201: "󰙿",
        1204: "󰙿",
        1207: "󰙿",
        1210: "󰖘",
        1213: "󰖘",
        1216: "󰖘",
        1219: "󰖘",
        1222: "󰼶",
        1225: "󰼶",
        1237: "󰖒",
        1240: "",
        1243: "",
        1246: "",
        1249: "󰙿",
        1252: "󰙿",
        1255: "󰖘",
        1258: "󰖘",
        1261: "󰙿",
        1264: "󰙿",
        1273: "",
        1276: "",
        1279: "",
        1282: ""
    }[code]

def expand_to_288(values):
    result = []
    for i in range(len(values) - 1):
        v1 = values[i] / 100
        v2 = values[i + 1] / 100
        for j in range(12):
            t = j / 12
            result.append(v1 * (1 - t) + v2 * t)
    result.append(values[-1] / 100)
    return result

def main():
    # response = requests.get(URL).json()
    response = json.loads(open("/home/niiixkz/response", "r", encoding="utf-8").read())

    # hourly = []
    # for day in response['forecast']['forecastday'][:2]:
    #     for hour in day['hour']:
    #         hourly.append({
    #             "time": hour['time'][-5:-2],
    #             "temp": f"{round(hour['temp_c'])}",
    #             "cloud": f"{round(hour['cloud'])}",
    #             "chance_of_rain": f"{round(hour['chance_of_rain'])}",
    #             "icon": get_icon(f"{hour['condition']['code']}")
    #         })
    #
    # for hour in hourly:
    #     if hour['time'] == f"{datetime.now().strftime('%H')}:00":
    #         hourly = hourly[hourly.index(hour):]
    
    print(response)

    current_hour = int(datetime.now().strftime('%H'))

    hourly = [{
            "time": hour['time'][-5:-3],
            "temp": str(round(hour['temp_c'])),
            "cloud": str(round(hour['cloud'])),
            "chance_of_rain": str(round(hour['chance_of_rain'])),
            "icon": get_icon(hour['condition']['code'])
        }
        for day in response['forecast']['forecastday'][:2]
        for hour in day['hour']
    ][current_hour:current_hour+24]
 
    chance_list = [int(h['chance_of_rain']) for h in hourly]
    result_288 = expand_to_288([int(h['chance_of_rain']) for h in hourly])
    result_288 = [f"{v:.2f}" for v in result_288]
    print(result_288)

    # hourly = hourly[:4]
    # data = {
    #     "location": response["location"]["name"],
    #     "maxtemp": f"{round(response['forecast']['forecastday'][0]['day']['maxtemp_c'])}°",
    #     "mintemp": f"{round(response['forecast']['forecastday'][0]['day']['mintemp_c'])}°",
    #     "current": {
    #         "temp": f"{round(response['current']['temp_c'])}°",
    #         "text": response['current']['condition']['text'],
    #         "icon": get_icon(f"{response['current']['condition']['code']}_{response['current']['is_day']}"),
    #     },
    #     "hourly": hourly
    # }
    #
    # return data

if __name__ == "__main__":
    try:
        # sys.stdout.write(json.dumps(main()) + "\n")
        # sys.stdout.flush()
        # os.system(f"eww update weather='{json.dumps(main())}'")
        main()
    except KeyboardInterrupt:
        exit(0)
