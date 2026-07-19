{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      dynamicBoost.enable = false;
    };
  };

  homeModules =
    { config, ... }:
    {
    };
}
