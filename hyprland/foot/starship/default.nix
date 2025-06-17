{ config, pkgs, ... }:
let
  starshipPath = "${config.home.homeDirectory}/nixos/hyprland/foot/starship/config/starship.toml";
in
{
  home.packages = with pkgs; [
    starship
  ];

  xdg.configFile."starship.toml".source = config.lib.file.mkOutOfStoreSymlink starshipPath;
}
