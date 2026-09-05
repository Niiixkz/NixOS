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
            name = "My PipeWire Output";
          }

          {
            type = "fifo";
            name = "My FIFO";
            path = "/tmp/mpd.fifo";
            format = "44100:16:2";
          }
        ];

        replaygain = "track";
      };
      user = "niiixkz";
    };

    systemd.services.mpd.environment = {
      XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
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
