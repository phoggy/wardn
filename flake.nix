{
  description = "wardn - Encrypted Bitwarden vault backup and restore";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rayvn.url = "github:phoggy/rayvn";
    valt.url = "github:phoggy/valt";
  };

  outputs = { self, nixpkgs, flake-utils, rayvn, valt }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        rayvnPkg = rayvn.packages.${system}.default;
        valtPkg = valt.packages.${system}.default;

        # Runtime dependencies
        runtimeDeps = [
          pkgs.bash
          rayvnPkg
          valtPkg
          pkgs.bitwarden-cli
          pkgs.jq
          pkgs.rage
          pkgs.pdfcpu
          pkgs.curl
        ];

        wardn = pkgs.stdenv.mkDerivation {
          pname = "wardn";
          version = "0.1.0";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/wardn "$out/bin/wardn"

            # Install lib/
            mkdir -p "$out/lib"
            cp lib/*.sh "$out/lib/"

            # Install etc/
            mkdir -p "$out/etc"
            cp -r etc/* "$out/etc/"

            # Install rayvn.pkg
            cp rayvn.pkg "$out/"

            # Wrap wardn with runtime dependencies on PATH
            wrapProgram "$out/bin/wardn" \
              --prefix PATH : "${pkgs.lib.makeBinPath runtimeDeps}"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Encrypted Bitwarden vault backup and restore using Age encryption";
            homepage = "https://github.com/phoggy/wardn";
            license = licenses.gpl3Only;
            platforms = platforms.unix;
          };
        };

        # Minimal restore package
        wardnRestore = pkgs.stdenv.mkDerivation {
          pname = "wardn-restore";
          version = "0.1.0";
          src = self;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            # Install bin/
            install -Dm755 bin/wardn "$out/bin/wardn"

            # Install lib/
            mkdir -p "$out/lib"
            cp lib/*.sh "$out/lib/"

            # Install etc/
            mkdir -p "$out/etc"
            cp -r etc/* "$out/etc/"

            cp rayvn.pkg "$out/"

            # Wrap with restore-focused deps
            wrapProgram "$out/bin/wardn" \
              --prefix PATH : "${pkgs.lib.makeBinPath [
                pkgs.bash rayvnPkg valtPkg pkgs.bitwarden-cli pkgs.jq pkgs.rage pkgs.curl
              ]}"

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "wardn restore tool - vault recovery support";
            homepage = "https://github.com/phoggy/wardn";
            license = licenses.gpl3Only;
            platforms = platforms.unix;
          };
        };
      in
      {
        packages = {
          default = wardn;
          wardn = wardn;
          restore = wardnRestore;
        };

        apps = {
          default = {
            type = "app";
            program = "${wardn}/bin/wardn";
          };
          wardn = {
            type = "app";
            program = "${wardn}/bin/wardn";
          };
          restore = {
            type = "app";
            program = "${wardnRestore}/bin/wardn";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [
            pkgs.shellcheck
          ];
          shellHook = ''
            export PATH="${self}/bin:$PATH"
            echo "wardn dev shell ready"
          '';
        };
      }
    );
}
