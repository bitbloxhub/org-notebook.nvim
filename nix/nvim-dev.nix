{
  inputs,
  ...
}:
{
  flake-file.inputs = {
    nixcats.url = "github:BirdeeHub/nixCats-nvim";
    crane.url = "github:ipetkov/crane";
    jupyter-api-nvim = {
      url = "github:bitbloxhub/jupyter-api.nvim";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        flake-file.follows = "flake-file";
        import-tree.follows = "import-tree";
        flint.follows = "flint";
        git-hooks.follows = "git-hooks";
        actions-nix.follows = "actions-nix";
        nix-auto-ci.follows = "nix-auto-ci";
        nixcats.follows = "nixcats";
        treefmt-nix.follows = "treefmt-nix";
        make-shell.follows = "make-shell";
      };
    };
  };

  perSystem =
    {
      pkgs,
      inputs',
      self',
      ...
    }:
    let
      categoryDefinitions = _: {
        startupPlugins = {
          general = with pkgs.vimPlugins; [
            mini-test
            orgmode
            inputs'.jupyter-api-nvim.packages.jupyter-api-nvim
          ];
          dev = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
            catppuccin-nvim
            neorepl-nvim
            self'.packages.org-notebook-nvim
          ];
        };
      };
      packageDefinitions = {
        nvim-deps = _: {
          settings = {
            wrapRc = true;
            configDirName = "nvim-deps";
            suffix-path = false;
          };
          categories = {
            general = true;
            dev = false;
          };
        };
        nvim-dev = _: {
          settings = {
            wrapRc = true;
            configDirName = "nvim-dev";
            suffix-path = false;
          };
          categories = {
            general = true;
            dev = true;
          };
        };
      };
      depsPackDir = builtins.head (
        builtins.match "^.*= '/nix/store/(.*-vim-pack-dir)'.*$" self'.packages.nvim-deps.setupLua
      );
      devPackDir = builtins.head (
        builtins.match "^.*= '/nix/store/(.*-vim-pack-dir)'.*$" self'.packages.nvim-dev.setupLua
      );
    in
    {
      packages.nvim-deps = inputs.nixcats.utils.baseBuilder ../nvim-dev-config {
        inherit pkgs;
      } categoryDefinitions packageDefinitions "nvim-deps";
      packages.nvim-dev = inputs.nixcats.utils.baseBuilder ../nvim-dev-config {
        inherit pkgs;
      } categoryDefinitions packageDefinitions "nvim-dev";
      make-shells.default = {
        packages = [
          self'.packages.nvim-dev
          # Force building the pack dir
          self'.packages.nvim-deps
          pkgs.stylua
          pkgs.lua-language-server
          pkgs.ts_query_ls
        ];
        shellHook = ''
          export NIXCATS_DEPS_PACK_DIR=/nix/store/${depsPackDir}
          export NIXCATS_DEV_PACK_DIR=/nix/store/${devPackDir}
        '';
      };
      treefmt.programs.stylua.enable = true;
    };
}
