{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelParams = [
      "nvidia-drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    ];

    boot.resumeDevice = "/dev/disk/by-uuid/bbe769ab-4bd3-4c68-a7c8-fc176e0e1d2b";
  };

  homeModules =
    { config, ... }:
    {
    };
}
