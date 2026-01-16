{
  config,
  lib,
  pkgs,
  ...
}:

let
  pixel_sakura-sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "pixel_sakura";
  };

  arcade-classic-fonts = pkgs.callPackage ./fonts { inherit pkgs; };

  nixfmt-tree-withConfig = pkgs.nixfmt-tree.override {

    runtimeInputs = [ pkgs.nixfmt-rfc-style ];

    settings = {
      on-unmatched = "info";

      formatter.nixfmt = {

        command = "nixfmt";
        include = [ "*.nix" ];
      };
    };
  };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  boot.resumeDevice = "/dev/disk/by-uuid/bbe769ab-4bd3-4c68-a7c8-fc176e0e1d2b";

  services.logind.settings.Login = {
    HandleSuspendKey = "ignore";
    HandleSuspendKeyLongPress = "ignore";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    dynamicBoost.enable = false;
  };

  networking.hostName = "NixOS";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Taipei";

  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    nerd-fonts.dejavu-sans-mono
    arcade-classic-fonts
    material-symbols
  ];
  fonts.fontDir.enable = true;
  fonts.enableGhostscriptFonts = true;

  services.power-profiles-daemon.enable = true;
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.mpd = {
    enable = true;
    settings = {
      music_directory = "/home/niiixkz/Music";

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
    startWhenNeeded = true; # systemd feature: only start MPD service upon connection to its socket
  };

  systemd.services.mpd.environment = {
    XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;

    settings = {
      General = {
        GreeterEnvironment = "QT_FONT_DPI=96";
        CursorTheme = "miku-cursor";
      };
    };

    extraPackages = with pkgs; [
      pixel_sakura-sddm-astronaut
    ];

    theme = "sddm-astronaut-theme";
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  users.users.niiixkz = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.fish;
  };

  environment.systemPackages = with pkgs; [
    vim
    unzip
    git
    gcc
    file
    home-manager
    pixel_sakura-sddm-astronaut
    nixfmt-tree-withConfig
    rar
  ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.fish = {
    enable = true;
  };

  system.stateVersion = "25.05";
}
