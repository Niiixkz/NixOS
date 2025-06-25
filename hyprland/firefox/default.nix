{
  config,
  pkgs,
  lib,
  ...
}:

let
  lock-false = {
    Value = false;
    Status = "locked";
  };
  lock-true = {
    Value = true;
    Status = "locked";
  };
in
{
  home.packages = with pkgs; [
    pywalfox-native
  ];

  home.activation.pywalfoxInstall = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.pywalfox-native}/bin/pywalfox install
  '';

  programs = {
    firefox = {
      enable = true;
      languagePacks = [ "en-US" ];

      # ---- POLICIES ----
      # Check about:policies#documentation for options.
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        DisablePocket = true;
        DisableFirefoxAccounts = true;
        DisableAccounts = true;
        DisableFirefoxScreenshots = true;
        OverrideFirstRunPage = "";
        OverridePostUpdatePage = "";
        DontCheckDefaultBrowser = true;
        DisplayBookmarksToolbar = "newtab"; # alternatives: "always" or "newtab"
        DisplayMenuBar = "default-off"; # alternatives: "always", "never" or "default-on"
        SearchBar = "unified"; # alternative: "separate"

        # ---- EXTENSIONS ----
        # Check about:support for extension/add-on ID strings.
        # Valid strings for installation_mode are "allowed", "blocked",
        # "force_installed" and "normal_installed".
        ExtensionSettings = {
          "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
          # Firefox Multi-Account Containers
          "@testpilot-containers" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
            installation_mode = "force_installed";
          };
          # uBlock Origin:
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
            private_browsing = true;
          };
          # Privacy Badger:
          "jid1-MnnxcxisBPnSXQ@jetpack" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
            installation_mode = "force_installed";
            private_browsing = true;
          };
          # Pywalfox:
          "pywalfox@frewacom.org" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/pywalfox/latest.xpi";
            installation_mode = "force_installed";
            private_browsing = true;
          };
          # YouTube 繁體自動翻譯修正
          "yuanchuang940@gmail.com" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-繁體自動翻譯修正/latest.xpi";
            installation_mode = "force_installed";
            private_browsing = true;
          };
          # youtube 找回留言區用戶名稱
          "yuanchuang940@gmail.com_return-yt-comment-usernames" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-找回留言區用戶名稱/latest.xpi";
            installation_mode = "force_installed";
            private_browsing = true;
          };
        };

        # ---- PREFERENCES ----
        # Check about:config for options.
        Preferences = {
          "browser.contentblocking.category" = {
            Value = "strict";
            Status = "locked";
          };
          "extensions.pocket.enabled" = lock-false;
          "extensions.screenshots.disabled" = lock-true;
          "browser.topsites.contile.enabled" = lock-false;
          "browser.formfill.enable" = lock-false;
          "browser.search.suggest.enabled" = lock-false;
          "browser.search.suggest.enabled.private" = lock-false;
          "browser.urlbar.suggest.searches" = lock-false;
          "browser.urlbar.showSearchSuggestionsFirst" = lock-false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = lock-false;
          "browser.newtabpage.activity-stream.feeds.snippets" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includePocket" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeBookmarks" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = lock-false;
          "browser.newtabpage.activity-stream.section.highlights.includeVisited" = lock-false;
          "browser.newtabpage.activity-stream.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.system.showSponsored" = lock-false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = lock-false;
        };

        # ---- BOOKMARKS ----
        Bookmarks = [
          {
            Folder = "Work";
            Title = "NixOS packages";
            URL = "https://search.nixos.org/packages";
            Placement = "toolbar";
          }
          {
            Folder = "Work";
            Title = "NixOS home-manager";
            URL = "https://nix-community.github.io/home-manager/options.xhtml";
            Placement = "toolbar";
          }
          {
            Folder = "Work";
            Title = "Github";
            URL = "https://github.com/";
            Placement = "toolbar";
          }
          {
            Folder = "Casual";
            Title = "Youtube";
            URL = "https://www.youtube.com";
            Placement = "toolbar";
          }
          {
            Folder = "Casual";
            Title = "Twitch";
            URL = "https://www.twitch.tv/";
            Placement = "toolbar";
          }
          {
            Folder = "Casual";
            Title = "Doujinstyle";
            URL = "https://doujinstyle.com";
            Placement = "toolbar";
          }
        ];
      };
    };
  };
}
