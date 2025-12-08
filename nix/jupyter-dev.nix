{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      kernelSpecs = {
        deno = {
          argv = [
            "${pkgs.deno}/bin/deno"
            "jupyter"
            "--kernel"
            "--conn"
            "{connection_file}"
          ];
          displayName = "Deno";
          language = "typescript";
          logo32 = null;
          logo64 = null;
        };
      };
    in
    {
      make-shells.default = {
        packages = [
          pkgs.deno
        ];
        shellHook = ''
          export JUPYTER_PATH=${pkgs.jupyter-kernel.create { definitions = kernelSpecs; }}
        '';
      };
    };
}
