{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
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
        };
      };

      xdg.configFile."fcitx5".source = config.lib.file.mkOutOfStoreSymlink "${diskDir}/config";
      xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
        patch:
          ascii_composer:
            switch_key:
              Shift_L: noop
      '';
    };
}
