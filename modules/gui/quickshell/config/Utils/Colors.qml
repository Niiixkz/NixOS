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
            echo -n "local colors =\n{\n  background = \\\"${background}\\\",\n  foreground = \\\"${foreground}\\\",\n  color0 = \\\"${color0}\\\",\n  color1 = \\\"${color1}\\\",\n  color2 = \\\"${color2}\\\",\n  color3 = \\\"${color3}\\\",\n  color4 = \\\"${color4}\\\",\n  color5 = \\\"${color5}\\\",\n  color6 = \\\"${color6}\\\",\n  color7 = \\\"${color7}\\\",\n  color8 = \\\"${color8}\\\",\n  color9 = \\\"${color9}\\\",\n  color10 = \\\"${color10}\\\",\n  color11 = \\\"${color11}\\\",\n  color12 = \\\"${color12}\\\",\n  color13 = \\\"${color13}\\\",\n  color14 = \\\"${color14}\\\",\n  color15 = \\\"${color15}\\\"\n}\nreturn colors\n" > /tmp/colors-hyprland.lua

            mkdir -p /home/niiixkz/.local/share/fcitx5/themes/Pywal
            echo -n "[Metadata]\nName=macOS-dark\nVersion=0.1\nAuthor=niiixkz\nDescription=\\\"Pywal\\\"\nScaleWithDPI=True\n\n[InputPanel]\nNormalColor=${color15}\nHighlightCandidateColor=${color15}\nEnableBlur=True\n\n[InputPanel/Background]\nImage=panel.svg\n\n[InputPanel/Background/Margin]\nLeft=10\nRight=10\nTop=10\nBottom=10\n\n[InputPanel/Highlight]\nImage=highlight.svg\n\n[InputPanel/Highlight/Margin]\nLeft=20\nRight=20\nTop=8\nBottom=8\n\n[InputPanel/TextMargin]\nLeft=20\nRight=18\nTop=8\nBottom=8\n\n[InputPanel/PrevPage/ClickMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/Background]\nBorderWidth=0\nGravity=\\\"Top Left\\\"\nOverlayOffsetX=0\nOverlayOffsetY=0\nHideOverlayIfOversize=False\n\n[Menu/Background/Margin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/Background/OverlayClipMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/Highlight]\nBorderWidth=0\nGravity=\\\"Top Left\\\"\nOverlayOffsetX=0\nOverlayOffsetY=0\nHideOverlayIfOversize=False\n\n[Menu/Highlight/Margin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/Highlight/OverlayClipMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/Separator]\nBorderWidth=0\nGravity=\\\"Top Left\\\"\nOverlayOffsetX=0\nOverlayOffsetY=0\nHideOverlayIfOversize=False\n\n[Menu/Separator/Margin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/Separator/OverlayClipMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/CheckBox]\nBorderWidth=0\nGravity=\\\"Top Left\\\"\nOverlayOffsetX=0\nOverlayOffsetY=0\nHideOverlayIfOversize=False\n\n[Menu/CheckBox/Margin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/CheckBox/OverlayClipMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/SubMenu]\nBorderWidth=0\nGravity=\\\"Top Left\\\"\nOverlayOffsetX=0\nOverlayOffsetY=0\nHideOverlayIfOversize=False\n\n[Menu/SubMenu/Margin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/SubMenu/OverlayClipMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/ContentMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0\n\n[Menu/TextMargin]\nLeft=0\nRight=0\nTop=0\nBottom=0" > /home/niiixkz/.local/share/fcitx5/themes/Pywal/theme.conf
            echo -n "<svg xmlns=\\\"http://www.w3.org/2000/svg\\\" width=\\\"40\\\" height=\\\"40\\\">\n  <rect\n    id=\\\"svg_1\\\"\n    width=\\\"38\\\"\n    height=\\\"38\\\"\n    x=\\\"1\\\"\n    y=\\\"1\\\"\n    fill=\\\"${background}cc\\\"\n    stroke=\\\"${color5}\\\"\n    stroke-width=\\\"2\\\"\n    rx=\\\"12\\\"\n    ry=\\\"12\\\"\n  />\n</svg>" > /home/niiixkz/.local/share/fcitx5/themes/Pywal/panel.svg
            echo -n "<svg xmlns=\\\"http://www.w3.org/2000/svg\\\" width=\\\"40\\\" height=\\\"40\\\">\n  <rect\n    id=\\\"svg_1\\\"\n    width=\\\"38\\\"\n    height=\\\"38\\\"\n    x=\\\"1\\\"\n    y=\\\"1\\\"\n    fill=\\\"#00000000\\\"\n    stroke=\\\"${color5}\\\"\n    stroke-width=\\\"2\\\"\n    rx=\\\"12\\\"\n    ry=\\\"12\\\"\n  />\n</svg>" > /home/niiixkz/.local/share/fcitx5/themes/Pywal/highlight.svg
            qdbus org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1.ReloadAddonConfig classicui

            mkdir -p /home/niiixkz/.config/kitty
            echo -n "font_family DejaVu Sans Mono\nfont_size 14.0\nterm xterm-kitty\nwindow_padding_width 12\n\nscrollback_lines 5000\nscrollback_pager_history_size 5000\nwheel_scroll_multiplier 2.0\n\ncursor_shape block\ncursor_blink_interval 0.5\ncursor_stop_blinking_after 0\n\nenable_audio_bell no\n\nbackground_opacity 0.80\nbackground ${background}\nforeground ${foreground}\nselection_foreground ${background}\nselection_background ${foreground}\n\ncolor0 ${color0}\ncolor1 ${color1}\ncolor2 ${color2}\ncolor3 ${color3}\ncolor4 ${color4}\ncolor5 ${color5}\ncolor6 ${color6}\ncolor7 ${color7}\ncolor8 ${color8}\ncolor9 ${color9}\ncolor10 ${color10}\ncolor11 ${color11}\ncolor12 ${color12}\ncolor13 ${color13}\ncolor14 ${color14}\ncolor15 ${color15}" > /home/niiixkz/.config/kitty/kitty.conf
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

