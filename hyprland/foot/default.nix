{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    foot
  ];

  imports = [
    ./starship/default.nix
  ];
}
