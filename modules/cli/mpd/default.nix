{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
  ];

  nixosModules = {
    services.mpd = {
      enable = true;
      settings = {
        music_directory = "/home/niiixkz/Music";
        bind_to_address = "/run/mpd/socket";

        audio_output = [
          {
            type = "pipewire";
            name = "Default Output";
          }

          {
            type = "pipewire";
            name = "nix-visualizer Output";
            target = "nix-visualizer_sink";
          }
        ];

        replaygain = "track";
      };
      user = "niiixkz";
    };

    systemd.services.mpd.environment = {
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
  };

  homeModules =
    { config, ... }:
    {
      home.sessionVariables = {
        MPD_HOST = "/run/mpd/socket";
      };
    };
}
