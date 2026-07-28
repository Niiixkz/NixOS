{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
  ];

  nixosModules = {
    services.power-profiles-daemon.enable = true;
  };

  homeModules =
    { config, ... }:
    {
    };
}
