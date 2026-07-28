{
  pkgs,
  inputs,
  root,
}:

let
  collectModules =
    evalDir: diskDir:
    let
      entries = builtins.readDir evalDir;

      nixFiles = builtins.filter (n: builtins.match "default\\.nix" n != null) (
        builtins.attrNames entries
      );

      nixFileAttrs = map (n: {
        evalPath = "${evalDir}/default.nix";
        diskDir = diskDir;
      }) nixFiles;

      subdirs = builtins.filter (n: entries.${n} == "directory") (builtins.attrNames entries);
    in
    nixFileAttrs
    ++ builtins.concatMap (
      subdir: collectModules "${evalDir}/${subdir}" "${diskDir}/${subdir}"
    ) subdirs;

  nixFileAttrs = collectModules ../modules "${root}/modules";

  mods = map (
    module:
    import module.evalPath {
      inherit pkgs inputs;
      inherit (module) diskDir;
    }
  ) nixFileAttrs;
in
{
  packages = builtins.concatLists (map (m: m.packages) mods);
  nixosModules = map (m: m.nixosModules) mods;
  homeModules = map (m: m.homeModules) mods;
}
