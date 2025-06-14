{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "NixOS";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Taipei";

  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.dejavu-sans-mono
  ];

  services.power-profiles-daemon.enable = true;
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.mpd = {
    enable = true;
    musicDirectory = "/home/niiixkz/Music";
    extraConfig = ''
    audio_output {
        type "pipewire"
        name "My PipeWire Output"
    }

    audio_output {
      type "fifo"
      name "My FIFO"
      path "/tmp/mpd.fifo"
    }

    replaygain "track"

    '';
    user = "niiixkz";
    startWhenNeeded = true; # systemd feature: only start MPD service upon connection to its socket
  };

  systemd.services.mpd.environment = {
    XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  users.users.niiixkz = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = with pkgs; [
    vim
    unzip
    git
    gcc
    file
    home-manager
  ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  system.stateVersion = "25.05";
}

