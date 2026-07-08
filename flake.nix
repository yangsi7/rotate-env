{
  description = "Bulk-rotate a leaked API-key env var across every .env and .mcp.json file, safely";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        runtimeDeps = [ pkgs.fd pkgs.jq pkgs.gawk pkgs.coreutils ];
        rotate = pkgs.stdenvNoCC.mkDerivation {
          pname = "rotate";
          version = "0.1.3";
          src = ./.;
          nativeBuildInputs = [ pkgs.makeWrapper pkgs.bash ];
          dontConfigure = true;
          dontBuild = true;
          installPhase = ''
            runHook preInstall
            install -Dm755 rotate "$out/bin/rotate"
            patchShebangs "$out/bin/rotate"
            wrapProgram "$out/bin/rotate" \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
            runHook postInstall
          '';
          meta = with pkgs.lib; {
            description = "Bulk-rotate a leaked API-key env var across every .env and .mcp.json file, safely";
            homepage = "https://github.com/yangsi7/rotate-env";
            license = licenses.mit;
            mainProgram = "rotate";
            platforms = platforms.unix;
          };
        };
      in {
        packages.default = rotate;
        packages.rotate = rotate;
        apps.default = flake-utils.lib.mkApp { drv = rotate; name = "rotate"; };
        apps.rotate = flake-utils.lib.mkApp { drv = rotate; name = "rotate"; };
      });
}
