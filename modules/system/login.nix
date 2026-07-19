{ pkgs, inputs, ... }:

{
  packages = [
  ];

  nixosModules = {
    services.logind.settings.Login = {
      HandleSuspendKey = "ignore";
      HandleSuspendKeyLongPress = "ignore";
    };
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "start-hyprland";
          user = "niiixkz";
        };
      };
    };
  };

  homeModules =
    { config, ... }:
    {
    };
}
