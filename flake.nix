{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pre-commit-hooks,
    }@inputs:

    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        checks.pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixfmt-rfc-style.enable = true;
            trim-trailing-whitespace.enable = true;
            end-of-file-fixer.enable = true;
            check-yaml.enable = true;
            check-added-large-files.enable = true;
          };
        };

        devShells.default = pkgs.mkShell {

          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;

          packages = with pkgs; [
            delta
            duckdb
            gnused
            just
            openconnect
            pwgen
            uv
          ];

          shellHook = ''
            ${self.checks.${system}.pre-commit-check.shellHook}
          '';
        };

      }
    );
}
