{
  pkgs,
  ...
}:

{
  users.users.niiixkz = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.fish;
  };
}
