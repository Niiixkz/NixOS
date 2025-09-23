{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/eww/config";
in
{
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
      nix-shell ${config.home.homeDirectory}/NixOS/shells/python3-eww.nix --run "python3 $@"
    '')
  ];

  xdg.configFile."eww".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
