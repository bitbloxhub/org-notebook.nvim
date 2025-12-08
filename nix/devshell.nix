{
  inputs,
  ...
}:
{
  flake-file.inputs.make-shell = {
    url = "github:nicknovitski/make-shell";
    inputs.flake-compat.follows = "";
  };

  imports = [
    inputs.make-shell.flakeModules.default
  ];

  perSystem =
    {
      pkgs,
      inputs',
      ...
    }:
    {
      make-shells.default = {
        name = "org-notebook.nvim";
        packages = [
          pkgs.just
          pkgs.nixfmt
          pkgs.deadnix
          pkgs.statix
          inputs'.flint.packages.default
        ];
      };
    };
}
