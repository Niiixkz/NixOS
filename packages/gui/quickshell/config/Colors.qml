pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.platform

Singleton {
    signal colorsChanged()

    property color foreground: "#FFFFFF"
    property color midground: "#7F7F7F"
    property color background: "#000000"
    property color semiTransparentBackground: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.8)
    property color color0: "#000000"
    property color color1: "#000000"
    property color color2: "#000000"
    property color color3: "#000000"
    property color color4: "#000000"
    property color color5: "#000000"
    property color color6: "#000000"
    property color color7: "#000000"
    property color color8: "#000000"
    property color color9: "#000000"
    property color color10: "#000000"
    property color color11: "#000000"
    property color color12: "#000000"
    property color color13: "#000000"
    property color color14: "#000000"
    property color color15: "#000000"

    function updateInternalColor(themeJson) {
        foreground = themeJson["15"]
        background = themeJson["0"]
        midground = Qt.rgba(
            (foreground.r - background.r) / 2 + background.r,
            (foreground.g - background.g) / 2 + background.g,
            (foreground.b - background.b) / 2 + background.b,
            1
        )
        semiTransparentBackground = Qt.rgba(background.r, background.g, background.b, 0.8)
        color0 = themeJson["0"]
        color1 = themeJson["1"]
        color2 = themeJson["2"]
        color3 = themeJson["3"]
        color4 = themeJson["4"]
        color5 = themeJson["5"]
        color6 = themeJson["6"]
        color7 = themeJson["7"]
        color8 = themeJson["8"]
        color9 = themeJson["9"]
        color10 = themeJson["10"]
        color11 = themeJson["11"]
        color12 = themeJson["12"]
        color13 = themeJson["13"]
        color14 = themeJson["14"]
        color15 = themeJson["15"]

        colorsChanged()

        updateExternalColor(themeJson)
    }

    property var templates: `
            echo -n "]4;0;${color0}\\]4;1;${color1}\\]4;2;${color2}\\]4;3;${color3}\\]4;4;${color4}\\]4;5;${color5}\\]4;6;${color6}\\]4;7;${color7}\\]4;8;${color8}\\]4;9;${color9}\\]4;10;${color10}\\]4;11;${color11}\\]4;12;${color12}\\]4;13;${color13}\\]4;14;${color14}\\]4;15;${color15}\\]10;${color15}\\]11;${color0}\\]12;${color15}\\]13;${color15}\\]17;${color15}\\]19;${color0}\\]4;232;${color0}\\]4;256;${color15}\\]4;257;${color0}\\]708;${color0}" | tee /dev/pts/[0-9]* > /dev/null
            echo -n "[main]\npad=12x12 center\nfont=DejaVu Sans Mono:size=14\nresize-delay-ms=2500\ndpi-aware=no\nterm=\\"xterm-256color\\"\ntitle=Foot\ninitial-window-size-pixels=1000x520\n\n[scrollback]\nlines=5000\nmultiplier=2\nindicator-format=percentage\nindicator-position=fixed\n\n[url]\nosc8-underline=url-mode\nlaunch=xdg-open \\\${url}\n# protocols=https\n\n[cursor]\nstyle=block\nblink=yes\nbeam-thickness=1\n\n[mouse]\nhide-when-typing=no\n\n[colors]\nalpha=0.80\nbackground={color0}\nforeground={color15}\nselection-foreground={color0}\nselection-background={color15}\n\n############\n## COLORS ##\n############\n\n## Normal/regular colors (color palette 0-7)\n\nregular0={color0}\nregular1={color1}\nregular2={color2}\nregular3={color3}\nregular4={color4}\nregular5={color5}\nregular6={color6}\nregular7={color7}" > ~/.config/foot/foot.ini
            echo -n "\\\$color0 = 0xff{color0}\n\\\$color1 = 0xff{color1}\n\\\$color2 = 0xff{color2}\n\\\$color3 = 0xff{color3}\n\\\$color4 = 0xff{color4}\n\\\$color5 = 0xff{color5}\n\\\$color6 = 0xff{color6}\n\\\$color7 = 0xff{color7}\n\\\$color8 = 0xff{color8}\n\\\$color9 = 0xff{color9}\n\\\$color10 = 0xff{color10}\n\\\$color11 = 0xff{color11}\n\\\$color12 = 0xff{color12}\n\\\$color13 = 0xff{color13}\n\\\$color14 = 0xff{color14}\n\\\$color15 = 0xff{color15}\n" > /tmp/colors-hyprland
        `

    property var commands: ``

    function updateExternalColor(themeJson) {
        let noHashtagThemeJson = JSON.parse(JSON.stringify(themeJson).replace(/#/g, ""))

        commands = templates
        for (let i = 0; i <= 15; i++) {
            commands = commands.replace(
                new RegExp(`\\{color${i}\\}`, "g"),
                noHashtagThemeJson[i]
            )
        }

        updateFile.running = true
    }

    Process {
        id: updateFile
        running: false
        command: [
            "bash", "-c", commands
        ]
    }
}

