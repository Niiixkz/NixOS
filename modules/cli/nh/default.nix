{
  pkgs,
  inputs,
  diskDir,
  ...
}:

let
  nh = inputs.nh.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  packages = [
    nh
  ];

  nixosModules = {
    programs.nh = {
      enable = true;
      package = nh;
      clean = {
        enable = true;
        dates = "daily";
        extraArgs = "--keep 3";
      };
    };
  };

  homeModules =
    { config, ... }:
    {
    };
}
