{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink ./config;
    };
}
