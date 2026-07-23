{ pkgs, inputs, ... }:

let
  helix = inputs.helix.packages.${pkgs.stdenv.hostPlatform.system}.helix;
  nixd = inputs.nixd.packages.${pkgs.stdenv.hostPlatform.system}.nixd;
  qml-language-server =
    inputs.qml-language-server.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  packages = [
    helix
    nixd
    pkgs.nixfmt
    qml-language-server
  ];

  nixosModules = {
  };

  homeModules =
    { config, lib, ... }:
    {
      programs.helix = {
        enable = true;
        package = helix;
        extraConfig = ''
          [editor]
          bufferline = "always"
          popup-border = "all"

          # [editor.clipboard-provider.custom]
          # yank = { command = "wl-copy" }
          # paste = { command = "wl-paste" }

          [editor.statusline]
          mode.normal = "NORMAL"
          mode.insert = "INSERT"
          mode.select = "SELECT"
        '';
        languages = {
          language-server = {
            qmlLSP = {
              command = "qml-language-server";
            };

            nixLSP = {
              command = "nixd";
            };
          };

          language = [
            {
              name = "nix";
              auto-format = true;
              formatter = {
                command = "nixfmt";
              };
              language-servers = [ "nixLSP" ];
            }
            {
              name = "qml";
              language-servers = [ "qmlLSP" ];
            }
          ];
        };
        settings.theme = "pywal";
        themes.pywal = {
          attribute = "magenta";
          keyword = "light-blue";
          "keyword.directive" = "magenta"; # -- preprocessor comments (#if in C)
          namespace = "magenta";
          punctuation = "light-magenta";
          "punctuation.delimiter" = "light-magenta";
          operator = "magenta";
          special = "yellow";
          "variable.other.member" = "white";
          variable = "light-magenta";
          # variable = "light-blue"; # TODO: metavariables only
          # "variable.parameter" = { fg = "light-magenta", modifiers = ["underlined"] }
          "variable.parameter" = {
            fg = "light-magenta";
          };
          "variable.builtin" = "green";
          type = "white";
          "type.builtin" = "white"; # TODO: distinguish?
          constructor = "magenta";
          function = "white";
          "function.macro" = "magenta";
          "function.builtin" = "white";
          tag = "light-blue";
          comment = "cyan";
          constant = "white";
          "constant.builtin" = "white";
          string = "light-gray";
          "constant.numeric" = "light-yellow";
          "constant.character.escape" = "yellow";
          # used for lifetimes;
          label = "yellow";
          tabstop = {
            modifiers = [ "italic" ];
            bg = "light-cyan";
          };
          "markup.heading" = "magenta";
          "markup.bold" = {
            modifiers = [ "bold" ];
          };
          "markup.italic" = {
            modifiers = [ "italic" ];
          };
          "markup.strikethrough" = {
            modifiers = [ "crossed_out" ];
          };
          "markup.link.url" = {
            fg = "light-gray";
            modifiers = [ "underlined" ];
          };
          "markup.link.text" = "light-blue";
          "markup.raw" = "light-blue";
          "diff.plus" = "#35bf86";
          "diff.minus" = "#f22c86";
          "diff.delta" = "#6f44f0";
          # TODO: differentiate doc comment
          # concat (ERROR) @error.syntax and "MISSING ;" selectors for errors
          "ui.background" = { };
          "ui.background.separator" = {
            fg = "light-red";
          };
          "ui.linenr" = {
            fg = "white";
          };
          "ui.linenr.selected" = {
            fg = "light-red";
          };
          "ui.statusline" = {
            fg = "magenta";
          };
          "ui.statusline.inactive" = {
            fg = "light-magenta";
          };
          "ui.window" = {
            fg = "white";
          };
          "ui.help" = {
            fg = "#171452";
          };
          "ui.text" = {
            fg = "white";
          };
          "ui.text.focus" = {
            fg = "white";
          };
          "ui.text.inactive" = "cyan";
          "ui.text.directory" = {
            fg = "magenta";
          };
          "ui.virtual" = {
            fg = "light-red";
          };
          "ui.virtual.ruler" = {
            bg = "light-cyan";
          };
          "ui.virtual.jump-label" = {
            fg = "red";
            modifiers = [ "bold" ];
          };
          "ui.virtual.indent-guide" = {
            fg = "light-red";
          };
          "ui.selection" = {
            fg = "black";
            bg = "white";
          };
          "ui.selection.primary" = {
            fg = "black";
            bg = "white";
          };
          # TODO: namespace ui.cursor as ui.selection.cursor?
          "ui.cursor.primary.select" = {
            fg = "black";
            bg = "red";
          };
          "ui.cursor.primary.insert" = {
            fg = "black";
            bg = "red";
          };
          "ui.cursor.match" = {
            fg = "red";
          };
          "ui.cursor" = {
            modifiers = [ "reversed" ];
          };
          "ui.cursorline.primary" = {
            bg = "light-cyan";
          };
          "ui.highlight" = {
            bg = "light-cyan";
          };
          "ui.debug" = {
            fg = "#634450";
          };
          "ui.debug.breakpoint" = {
            fg = "red";
          };
          "ui.menu" = {
            fg = "light-magenta";
          };
          "ui.menu.selected" = {
            fg = "black";
            bg = "white";
          };
          "ui.menu.scroll" = {
            fg = "light-magenta";
            bg = "light-red";
          };
          "diagnostic.hint" = {
            underline = {
              color = "light-gray";
              style = "curl";
            };
          };
          "diagnostic.info" = {
            underline = {
              color = "blue";
              style = "curl";
            };
          };
          "diagnostic.warning" = {
            underline = {
              color = "light-green";
              style = "curl";
            };
          };
          "diagnostic.error" = {
            underline = {
              color = "red";
              style = "curl";
            };
          };
          "diagnostic.unnecessary" = {
            modifiers = [ "dim" ];
          };
          "diagnostic.deprecated" = {
            modifiers = [ "crossed_out" ];
          };
          warning = "light-green";
          error = "red";
          info = "blue";
          hint = "light-gray";
        };
      };
    };
}
