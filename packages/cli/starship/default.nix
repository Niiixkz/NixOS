{ config, pkgs, ... }:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/cli/starship/config/starship.toml";
in
{
  home.packages = with pkgs; [
    starship
  ];

  xdg.configFile."starship.toml".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
