{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  homeModules =
    { config, ... }:
    {
    };
}
