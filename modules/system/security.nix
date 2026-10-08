{
  security.sudo.extraRules = [
    {
      users = [ "niiixkz" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/chattr";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
