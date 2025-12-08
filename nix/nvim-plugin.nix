{
  perSystem =
    {
      pkgs,
      inputs',
      ...
    }:
    {
      packages.org-notebook-nvim = pkgs.vimUtils.buildVimPlugin {
        name = "org-notebook.nvim";
        src = ../.;
        dependencies = with pkgs.vimPlugins; [
          mini-test
          orgmode
          inputs'.jupyter-api-nvim.packages.jupyter-api-nvim
        ];
        nvimSkipModules = [
          "org-notebook.test"
        ];
      };
    };
}
