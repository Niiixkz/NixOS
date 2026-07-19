{ pkgs, inputs, ... }:

{
  packages = [
    pkgs.git
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "Niiixkz";
            email = "niiixkz@gmail.com";
          };
        };
      };
    };
}
