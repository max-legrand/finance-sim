# Adapted from https://sixcodes.dev/blog/ocaml-nix-for-your-project/
{
  description = "Finance Sim with Nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    ocaml-overlay.url = "github:nix-ocaml/nix-overlays";
    ocaml-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, nix-filter, ocaml-overlay }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ ocaml-overlay.overlays.default ];
        };
        ocamlVersion = "ocamlPackages";
        ocamlPackages = pkgs.${ocamlVersion};

        projectName = "finance_sim";
        projectVersion = "0.1.0"; # Replace with actual version if available

        spiceSource = pkgs.fetchzip {
          url = "https://github.com/max-legrand/spice/archive/refs/heads/main.zip";
          sha256 = "sha256-sf0R6H1KoHi1kPayibdWY+rbuMohIock/2dUOgxBucU=";
        };

        # Filtered sources (prevents unecessary rebuilds)
        sources = {
          ocaml = nix-filter.lib {
            root = ./.;
            include = [
              ".ocamlformat"
              "dune-project"
              "dune"
              "finance_sim.opam"
              (nix-filter.lib.inDirectory "bin")
              (nix-filter.lib.inDirectory "lib")
            ];
          };

          nix = nix-filter.lib {
            root = ./.;
            include = [
              (nix-filter.lib.matchExt "nix")
            ];
          };
        };

        finalPackage = ocamlPackages.buildDunePackage {
          pname = projectName;
          version = projectVersion;
          duneVersion = "3";
          src = sources.ocaml;

          buildInputs = [
            ocamlPackages.base
            ocamlPackages.core
            ocamlPackages.lwt
            ocamlPackages.cmdliner
            ocamlPackages.ptime
            ocamlPackages.alcotest
            ocamlPackages.yojson
            ocamlPackages.ppx_yojson_conv
            ocamlPackages.domainslib

            ocamlPackages.ezgzip
            ocamlPackages.ppx_deriving
            ocamlPackages.async
            ocamlPackages.async_ssl
            ocamlPackages.yaml

            ocamlPackages.dream
            ocamlPackages.dream-html
            pkgs.libffi
            pkgs.curl
          ];

          nativeBuildInputs = [
            pkgs.git
            pkgs.pkg-config
          ];

          buildPhase = ''
            mkdir -p lib
            rm -rf lib/spice
            mkdir -p lib/spice
            cp -rL ${spiceSource}/lib/* lib/spice/
            cp -rL ${spiceSource}/dune-project lib/spice/
            chmod -R u+w lib/spice

            echo "=== New contents of lib/spice ==="
            ls -la lib/spice/

            dune build --release @install
          '';
        };
      in
      {
        packages = {
          default = finalPackage;
          ${projectName} = finalPackage;
        };

        apps.default = {
          type = "app";
          program = "${finalPackage}/bin/${projectName}";
        };

        devShells = {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = [
              ocamlPackages.ocaml-lsp
              ocamlPackages.ocamlformat
              pkgs.pkg-config
              pkgs.zlib
              pkgs.libffi
              pkgs.curl
            ];
          };
        };
      }
    );
}
