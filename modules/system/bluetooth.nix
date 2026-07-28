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
    services.blueman.enable = true;
    hardware.bluetooth.enable = true;
  };

  homeModules =
    { config, ... }:
    {
    };
}
