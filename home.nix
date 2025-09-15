{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  home.username = "niiixkz";
  home.homeDirectory = "/home/niiixkz";

  programs.git = {
    enable = true;
    userName = "Niiixkz";
    userEmail = "niiixkz@gmail.com";
  };

  programs.eww = {
    enable = true;
    package = inputs.eww.packages.${pkgs.system}.eww;
  };

  home.packages = with pkgs; [
    python313Packages.pygobject3
    python313Packages.dbus-python
    python313Packages.requests
    gdk-pixbuf
    gtk3

    (writeShellScriptBin "python3-eww" ''
      nix-shell /home/niiixkz/NixOS/shells/python3-eww.nix --run "python3 $@"
    '')

    python313Packages.opencv4
    python313Packages.numpy

    bc

    (writeShellScriptBin "python3-qs" ''
      nix-shell /home/niiixkz/NixOS/shells/python3-quickshell.nix --run "python3 $@"
    '')
  ];

  programs.quickshell = {
    enable = true;
    package = inputs.quickshell.packages.${pkgs.system}.quickshell.withModules (
      with pkgs;
      [
        kdePackages.qtpositioning
        kdePackages.qt5compat
      ]
    );
  };

  imports = [
    ./hyprland/default.nix
    ./tools/default.nix
    ./music/default.nix
    ./game/default.nix
  ];

  home.stateVersion = "25.05";
}
