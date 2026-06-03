# env-init を makeWrapper で wrap する。生スクリプト (./env-init) は libexec にそのまま置き、
# 外側の wrapper で runtimeInputs を PATH 先頭に prefix して exec するだけ（中身は無改変）。
#
# writeShellApplication を使わない理由: あれはスクリプト本文の前にプリアンブル
# (shebang・set -o・PATH 設定) を挿入するため、env-init の `--help` が `$0` から読む
# 先頭ヘッダコメントが押し下げられて usage が空になる。makeWrapper なら wrapper が
# 生スクリプトを exec し `$0` が生スクリプトを指すため --help が正しく動く。
#
# shebang の書き換え: 生スクリプトの `#!/usr/bin/env bash` は Linux の hermetic な nix ビルド
# サンドボックス (/usr/bin/env が無い) で bad interpreter になる。インストールした libexec の
# コピーだけ shebang を nix store のプレーン bash に固定する (リポジトリ上の原本は #!/usr/bin/env
# bash のまま＝非 Nix 利用者向けに可搬)。patchShebangs はビルド環境次第で bash-interactive を
# 拾い closure を太らせるため、明示の bash に決定的に置換する。runtimeInputs を prefix しても
# 既存 PATH は残る (suffix) ので、.env.template が呼ぶ openssl / op は消費側 PATH で解決できる。
{
  lib,
  runCommand,
  makeWrapper,
  bashNonInteractive,
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
    substituteInPlace "$out/libexec/env-init" \
      --replace-fail '#!/usr/bin/env bash' '#!${bashNonInteractive}/bin/bash'
    makeWrapper "$out/libexec/env-init" "$out/bin/env-init" \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          git
          gawk
          gnused
        ]
      }
  ''
