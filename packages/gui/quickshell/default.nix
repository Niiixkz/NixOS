{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  configPath = "${config.home.homeDirectory}/NixOS/packages/gui/quickshell/config";
in
{
  programs.quickshell = {
    enable = true;
    package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell.withModules (
      with pkgs;
      [
        kdePackages.qtpositioning
        kdePackages.qt5compat
        kdePackages.kimageformats
      ]
    );
  };

  home.packages = with pkgs; [
    python313

    (writeShellScriptBin "python3-qs" ''
      nix-shell ${config.home.homeDirectory}/NixOS/shells/python3-quickshell.nix --run "python3 $@"
    '')
  ];

  xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink configPath;
}
