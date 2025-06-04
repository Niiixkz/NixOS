{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    foot
  ];

  home.file.".config/foot/update_colors.sh" = {
    source = ./config/update_colors.sh;
    executable = true;
  };
  home.file.".config/foot/template.ini".source = ./config/template.ini;

  imports = [
    ./starship/default.nix
  ];
}
