{
  description = "org 横断で共有する汎用 dev ツールの集約 flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # 複数ツールが入るため default は設けない。利用側は常に `#<tool>` を明示する。
      packages = forAllSystems (pkgs: {
        env-init = pkgs.callPackage ./pkgs/env-init/package.nix { };
        ghas-setup = pkgs.callPackage ./pkgs/ghas-setup/package.nix { };
      });

      # test / lint の単一ソース。`nix flake check` で全て走る。
      checks = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          # パッケージ build が通ること。
          env-init = self.packages.${system}.env-init;
          ghas-setup = self.packages.${system}.ghas-setup;

          shellcheck = pkgs.runCommand "shellcheck" { nativeBuildInputs = [ pkgs.shellcheck ]; } ''
            shellcheck ${./pkgs/env-init/env-init} ${./pkgs/ghas-setup/ghas-setup}
            touch "$out"
          '';

          # env-init を PATH に載せて bats フルセットを実行。
          bats =
            pkgs.runCommand "env-init-bats"
              {
                nativeBuildInputs = [
                  pkgs.bats
                  pkgs.bash
                  pkgs.git
                  pkgs.gawk
                  pkgs.gnused
                  pkgs.coreutils
                  self.packages.${system}.env-init
                ];
              }
              ''
                cp -r ${./pkgs/env-init/tests} tests
                export HOME="$TMPDIR"
                bats tests
                touch "$out"
              '';

          # ghas-setup を PATH に載せて bats を実行（gh api を叩く本適用パスは認証が要るため
          # 検証せず、引数パース・pre-flight・--dry-run のみ。gh は不要）。
          ghas-setup-bats =
            pkgs.runCommand "ghas-setup-bats"
              {
                nativeBuildInputs = [
                  pkgs.bats
                  pkgs.bash
                  pkgs.git
                  pkgs.coreutils
                  pkgs.yq-go
                  self.packages.${system}.ghas-setup
                ];
              }
              ''
                cp -r ${./pkgs/ghas-setup/tests} tests
                export HOME="$TMPDIR"
                bats tests
                touch "$out"
              '';

          statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
            statix check ${./.}
            touch "$out"
          '';

          deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
            deadnix --fail ${./.}
            touch "$out"
          '';

          nixfmt = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            nixfmt --check ${./flake.nix} ${./pkgs/env-init/package.nix} ${./pkgs/ghas-setup/package.nix}
            touch "$out"
          '';
        }
      );

      # nixfmt-tree (treefmt + nixfmt) を formatter にすることで `nix fmt`（引数なし）が
      # ツリー全体を再帰整形できる（素の nixfmt は引数なしだと stdin 待ちでハングする）。
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
