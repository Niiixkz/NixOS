{
  config,
  pkgs,
  lib,
  ...
}:
{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-rime
        rime-data
        fcitx5-gtk
      ];
      settings = {
        globalOptions = {
          Hotkey = {
            EnumerateWithTriggerKeys = "True";
            EnumerateSkipFirst = "False";
            ModifierOnlyKeyTimeout = 250;
          };

          "Hotkey/AltTriggerKeys"."0" = "Shift+Shift_R";

          Behavior = {
            ActiveByDefault = "True";
            resetStateWhenFocusIn = "No";
            ShareInputState = "All";
            PreeditEnabledByDefault = "True";
            ShowInputMethodInformation = "True";
            showInputMethodInformationWhenFocusIn = "True";
            CompactInputMethodInformation = "True";
            ShowFirstInputMethodInformation = "True";
            DefaultPageSize = 10;
            OverrideXkbOption = "False";
            PreloadInputMethod = "True";
            AllowInputMethodForPassword = "False";
            ShowPreeditForPassword = "False";
            AutoSavePeriod = 30;
          };
        };

        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "rime";
          };
          "Groups/0/Items/0".Name = "rime";
        };

        addons = {
          classicui.globalSection = {
            "Vertical Candidate List" = "True";
            WheelForPaging = "True";
            Font = "Sans 10";
            MenuFont = "Sans 10";
            TrayFont = "Sans Bold 10";
            TrayOutlineColor = "#000000";
            TrayTextColor = "#ffffff";
            PreferTextIcon = "False";
            ShowLayoutNameInIcon = "True";
            UseInputMethodLanguageToDisplayText = "True";
            Theme = "default-dark";
            DarkTheme = "default-dark";
            UseDarkTheme = "False";
            UseAccentColor = "True";
            PerScreenDPI = "False";
            ForceWaylandDPI = 0;
            EnableFractionalScale = "True";
          };
        };
      };
    };
  };
}
