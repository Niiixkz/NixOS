{ pkgs, inputs, ... }:

let
  hyprland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
in
{
  packages = [
  ];

  nixosModules = {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      package = hyprland;
    };
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."hypr".source = config.lib.file.mkOutOfStoreSymlink ./config;
    };
}
