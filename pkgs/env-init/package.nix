# env-init を makeWrapper で wrap する。生スクリプト (./env-init) は libexec にそのまま置き、
# 外側の wrapper で runtimeInputs を PATH 先頭に prefix して exec するだけ（中身は無改変）。
#
# writeShellApplication を使わない理由: あれはスクリプト本文の前にプリアンブル
# (shebang・set -o・PATH 設定) を挿入するため、env-init の `--help` が `$0` から読む
# 先頭ヘッダコメントが押し下げられて usage が空になる。makeWrapper なら wrapper が
# 生スクリプトを exec し `$0` が生スクリプトを指すため --help が正しく動く。
#
# PATH には bash も含める。生スクリプトの `#!/usr/bin/env bash` が wrapper の設定した
# PATH で bash を解決するため、決定的な bash を使わせる。runtimeInputs を prefix しても
# 既存 PATH は残る (suffix) ので、.env.template が呼ぶ openssl / op は消費側 PATH で解決できる。
{
  lib,
  runCommand,
  makeWrapper,
  bash,
  coreutils,
  git,
  gawk,
  gnused,
}:
runCommand "env-init"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "現在の git worktree 用に .env を生成する汎用エンジン";
      mainProgram = "env-init";
    };
  }
  ''
    install -Dm755 ${./env-init} "$out/libexec/env-init"
    makeWrapper "$out/libexec/env-init" "$out/bin/env-init" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          git
          gawk
          gnused
        ]
      }
  ''
