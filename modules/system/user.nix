{
  pkgs,
  ...
}:

{
  users.users = {
    niiixkz = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$FYajR1x8omnZB/dhnJk1o/$2kxp.LmE2ZIo5CKsamC8NJPcxusoDtXmybVJ1H8/5T2";
      shell = pkgs.fish;

      extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };

    root = {
      hashedPassword = "!";
    };
  };
}
