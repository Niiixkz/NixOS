{
  config,
  pkgs,
  lib,
  ...
}:

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
}
