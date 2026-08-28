{
  pkgs,
  inputs,
  diskDir,
  ...
}:

{
  packages = [
    pkgs.starship
  ];

  nixosModules = {
  };

  homeModules =
    { config, ... }:
    {
      programs.starship = {
        enable = true;
        enableFishIntegration = true;

        settings = {
          format = "[](fg:blue)$os[](bg:blue fg:red)$username[](bg:red fg:green)$directory[ ](fg:green)$git_branch$git_status$all$character";
          username = {
            show_always = true;
            format = "[$user ](bg:red fg:black)";
            disabled = false;
          };

          os = {
            disabled = false;
            style = "bg:blue fg:black";
            symbols = {
              Alpaquita = " ";
              Alpine = " ";
              AlmaLinux = " ";
              Amazon = " ";
              Android = " ";
              Arch = " ";
              Artix = " ";
              CachyOS = " ";
              CentOS = " ";
              Debian = " ";
              DragonFly = " ";
              Emscripten = " ";
              EndeavourOS = " ";
              Fedora = " ";
              FreeBSD = " ";
              Garuda = "󰛓 ";
              Gentoo = " ";
              HardenedBSD = "󰞌 ";
              Illumos = "󰈸 ";
              Kali = " ";
              Linux = " ";
              Mabox = " ";
              Macos = " ";
              Manjaro = " ";
              Mariner = " ";
              MidnightBSD = " ";
              Mint = " ";
              NetBSD = " ";
              NixOS = " ";
              Nobara = " ";
              OpenBSD = "󰈺 ";
              openSUSE = " ";
              OracleLinux = "󰌷 ";
              Pop = " ";
              Raspbian = " ";
              Redhat = " ";
              RedHatEnterprise = " ";
              RockyLinux = " ";
              Redox = "󰀘 ";
              Solus = "󰠳 ";
              SUSE = " ";
              Ubuntu = " ";
              Unknown = " ";
              Void = " ";
              Windows = "󰍲 ";
            };
          };

          cmd_duration.format = "[$duration](fg:red)";

          directory = {
            format = "[$path](bg:green fg:black)";
            truncation_length = 8;
            truncation_symbol = "…/";

            substitutions = {
              Documents = "󰈙 ";
              Downloads = " ";
              Music = "󰝚 ";
              Pictures = " ";
              Scripts = "󰲋 ";
            };
          };

          character = {
            success_symbol = "[](bold blue)";
            error_symbol = "[✗](bold red)";
            disabled = false;
          };

          fossil_branch = {
            symbol = "  ";
            format = "[$symbol($version)]($style)";
          };

          git_branch = {
            symbol = "  ";
            format = "[$symbol($branch) ($version)]($style)";
          };

          git_commit = {
            tag_symbol = "  ";
            format = "[$symbol($version)]($style)";
          };

          aws.symbol = "   ";
          aws.format = "[$symbol($version)]($style)";

          buf.symbol = "  ";
          buf.format = "[$symbol($version)]($style)";

          c.symbol = "  ";
          c.format = "[$symbol($version)]($style)";

          cmake.symbol = "  ";
          cmake.format = "[$symbol($version)]($style)";

          conda.symbol = "  ";
          conda.format = "[$symbol($version)]($style)";

          crystal.symbol = "  ";
          crystal.format = "[$symbol($version)]($style)";

          dart.symbol = "  ";
          dart.format = "[$symbol($version)]($style)";

          docker_context.symbol = "  ";
          docker_context.format = "[$symbol($version)]($style)";

          elixir.symbol = "  ";
          elixir.format = "[$symbol($version)]($style)";

          elm.symbol = "  ";
          elm.format = "[$symbol($version)]($style)";

          fennel.symbol = "  ";
          fennel.format = "[$symbol($version)]($style)";

          golang.symbol = "  ";
          golang.format = "[$symbol($version)]($style)";

          guix_shell.symbol = "   ";
          guix_shell.format = "[$symbol($version)]($style)";

          haskell.symbol = "  ";
          haskell.format = "[$symbol($version)]($style)";

          haxe.symbol = "  ";
          haxe.format = "[$symbol($version)]($style)";

          hg_branch.symbol = "  ";
          hg_branch.format = "[$symbol($version)]($style)";

          hostname = {
            ssh_symbol = "  ";
            format = "[$symbol($version)]($style)";
          };

          java.symbol = "  ";
          java.format = "[$symbol($version)]($style)";

          julia.symbol = "  ";
          julia.format = "[$symbol($version)]($style)";

          kotlin.symbol = "  ";
          kotlin.format = "[$symbol($version)]($style)";

          lua.symbol = "  ";
          lua.format = "[$symbol($version)]($style)";

          memory_usage.symbol = " 󰍛 ";
          memory_usage.format = "[$symbol($version)]($style)";

          meson.symbol = " 󰔷 ";
          meson.format = "[$symbol($version)]($style)";

          nim.symbol = " 󰆥 ";
          nim.format = "[$symbol($version)]($style)";

          nix_shell.symbol = "  ";
          nix_shell.format = "[$symbol($version)]($style)";

          nodejs.symbol = "  ";
          nodejs.format = "[$symbol($version)]($style)";

          ocaml.symbol = "  ";
          ocaml.format = "[$symbol($version)]($style)";

          package.symbol = " 󰏗 ";
          package.format = "[$symbol($version)]($style)";

          perl.symbol = "  ";
          perl.format = "[$symbol($version)]($style)";

          php.symbol = "  ";
          php.format = "[$symbol($version)]($style)";

          pijul_channel.symbol = "  ";
          pijul_channel.format = "[$symbol($version)]($style)";

          python.symbol = "  ";
          python.format = "[$symbol($version)]($style)";

          rlang.symbol = " 󰟔 ";
          rlang.format = "[$symbol($version)]($style)";

          ruby.symbol = "  ";
          ruby.format = "[$symbol($version)]($style)";

          rust.symbol = " 󱘗 ";
          rust.format = "[$symbol($version)]($style)";

          scala.symbol = "  ";
          scala.format = "[$symbol($version)]($style)";

          swift.symbol = "  ";
          swift.format = "[$symbol($version)]($style)";

          zig.symbol = "  ";
          zig.format = "[$symbol($version)]($style)";

          gradle.symbol = "  ";
          gradle.format = "[$symbol($version)]($style)";
        };
      };
    };
}
