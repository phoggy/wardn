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
        # bitwarden-cli fails to build in Nix sandbox on macOS (needs xcodebuild
        # for native node modules). On macOS it falls through to system PATH.
        # On Linux the Nix-managed version is used for full reproducibility.
        runtimeDeps = [
          pkgs.bash
          rayvnPkg
          valtPkg
          pkgs.jq
          pkgs.rage
          pkgs.pdfcpu
          pkgs.curl
        ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
          pkgs.bitwarden-cli
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
            mkdir -p "$out/share/wardn/lib"
            cp lib/*.sh "$out/share/wardn/lib/"

            # Install etc/
            mkdir -p "$out/share/wardn/etc"
            cp -r etc/* "$out/share/wardn/etc/"

            # Install rayvn.pkg with version metadata
            sed '/^projectVersion=/d; /^projectReleaseDate=/d; /^projectFlake=/d; /^projectBuildRev=/d; /^projectNixpkgsRev=/d' \
                rayvn.pkg > "$out/share/wardn/rayvn.pkg"
            cat >> "$out/share/wardn/rayvn.pkg" <<EOF

# Version metadata (added by Nix build)
projectVersion='$version'
projectReleaseDate='$(date "+%Y-%m-%d %H:%M:%S %Z")'
projectFlake='github:phoggy/wardn/v$version'
projectBuildRev='${self.shortRev or "dev"}'
projectNixpkgsRev='${nixpkgs.shortRev}'
EOF

            # Wrap wardn with runtime dependencies on PATH.
            # Include $out/bin so rayvn.up can find 'rayvn.up' and 'wardn' via
            # PATH lookup for project root resolution.
            wrapProgram "$out/bin/wardn" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath runtimeDeps}"

            runHook postInstall
          '';

          # patchShebangs rewrites #!/usr/bin/env bash to the non-interactive
          # bash, which lacks builtins like compgen. Restore the shebangs so
          # they resolve via PATH, where the wrapper provides bash-interactive.
          postFixup = ''
            for f in "$out/bin/.wardn-wrapped" "$out/share/wardn/lib/"*.sh; do
              if [ -f "$f" ]; then
                sed -i "1s|^#\\!.*/bin/bash.*|#!/usr/bin/env bash|" "$f"
              fi
            done
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
            mkdir -p "$out/share/wardn/lib"
            cp lib/*.sh "$out/share/wardn/lib/"

            # Install etc/
            mkdir -p "$out/share/wardn/etc"
            cp -r etc/* "$out/share/wardn/etc/"

            # Install rayvn.pkg with version metadata
            sed '/^projectVersion=/d; /^projectReleaseDate=/d; /^projectFlake=/d; /^projectBuildRev=/d; /^projectNixpkgsRev=/d' \
                rayvn.pkg > "$out/share/wardn/rayvn.pkg"
            cat >> "$out/share/wardn/rayvn.pkg" <<EOF

# Version metadata (added by Nix build)
projectVersion='$version'
projectReleaseDate='$(date "+%Y-%m-%d %H:%M:%S %Z")'
projectFlake='github:phoggy/wardn/v$version'
projectBuildRev='${self.shortRev or "dev"}'
projectNixpkgsRev='${nixpkgs.shortRev}'
EOF

            # Wrap with restore-focused deps.
            # Include $out/bin for rayvn.up project root resolution.
            wrapProgram "$out/bin/wardn" \
              --prefix PATH : "$out/bin:${pkgs.lib.makeBinPath ([
                pkgs.bash rayvnPkg valtPkg pkgs.jq pkgs.rage pkgs.curl
              ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
                pkgs.bitwarden-cli
              ])}"

            runHook postInstall
          '';

          postFixup = ''
            for f in "$out/bin/.wardn-wrapped" "$out/share/wardn/lib/"*.sh; do
              if [ -f "$f" ]; then
                sed -i "1s|^#\\!.*/bin/bash.*|#!/usr/bin/env bash|" "$f"
              fi
            done
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
            [[ $- == *i* ]] && echo "wardn dev shell ready"
          '';
        };
      }
    );
}
