{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    users.users.niiixkz = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
      shell = pkgs.fish;
    };
  };

  homeModules =
    { config, ... }:
    {
    };
}
