{ pkgs, inputs, ... }:

let
  quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell.withModules (
    with pkgs;
    [
      kdePackages.qtpositioning
      kdePackages.qt5compat
      kdePackages.kimageformats
    ]
  );
in
{
  packages = [
    quickshell
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      xdg.configFile."quickshell".source = config.lib.file.mkOutOfStoreSymlink ./config;
    };
}
