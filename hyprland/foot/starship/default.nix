{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    starship
  ];

  home.file.".config/starship.toml".source = ./config/starship.toml;
}
