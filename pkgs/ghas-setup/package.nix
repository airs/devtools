# ghas-setup を makeWrapper で wrap する。生スクリプト (./ghas-setup) は libexec にそのまま置き、
# 外側の wrapper で runtimeInputs を PATH 先頭に prefix して exec するだけ（中身は無改変）。
# 設計の理由は pkgs/env-init/package.nix のコメントを参照（writeShellApplication を避ける理由・
# shebang を nix store の bash に固定する理由・PATH prefix で既存 PATH を suffix に残す理由は同じ）。
#
# 同梱する runtimeInputs: スクリプトが使う git (rev-parse) / gh (api) / yq (yq-go, config 読み) /
# coreutils。gh は closure が重いが、利用側の ~/.config/gh 認証状態を読むため動作上の問題はない。
{
  lib,
  runCommand,
  makeWrapper,
  bashNonInteractive,
  coreutils,
  git,
  gh,
  yq-go,
}:
runCommand "ghas-setup"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "GitHub org の GHAS / セキュリティ設定を gh api で一括適用する汎用エンジン";
      mainProgram = "ghas-setup";
    };
  }
  ''
    install -Dm755 ${./ghas-setup} "$out/libexec/ghas-setup"
    substituteInPlace "$out/libexec/ghas-setup" \
      --replace-fail '#!/usr/bin/env bash' '#!${bashNonInteractive}/bin/bash'
    makeWrapper "$out/libexec/ghas-setup" "$out/bin/ghas-setup" \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          git
          gh
          yq-go
        ]
      }
  ''
