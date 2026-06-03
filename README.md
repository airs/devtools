# devtools

org 横断で共有する汎用 dev ツールの集約リポジトリ。各利用 repo はここを参照するだけにし、コピペを撲滅（DRY）してツールの版を固定する。

## 採用方式

Nix flake × devbox。言語非依存でツールを PATH へ配布し、`flake.lock` / `devbox.lock` で版とコンテナ build を再現可能に固定する。利用側 repo は同一の flake 参照を `devbox.json` の `packages` に足すだけでよい。

## 構成

```
flake.nix              # packages / checks (test・lint) / formatter を公開
devbox.json            # 開発環境（Nix の test/lint ツール）と自己 dogfooding
.env.template          # env-init 用テンプレートの書式例（本 repo の dogfood でも使用）
pkgs/
  env-init/
    package.nix        # env-init を makeWrapper で wrap する派生
    env-init           # エンジン本体（単体実行可能な生スクリプト）
    tests/             # bats テスト
```

## 開発

devbox 経由で開発する。

```sh
devbox shell        # 開発シェルに入る（初回は .env を自動生成し env-init を dogfood）
devbox run check    # nix flake check（shellcheck・bats・statix・deadnix・nixfmt）
devbox run build    # nix build .#env-init
devbox run fmt      # nix fmt（nixfmt-tree でツリー全体を整形）
```

## バージョニング

リリースはリポジトリ単位の [SemVer](https://semver.org/lang/ja/) タグ `vMAJOR.MINOR.PATCH`（例 `v1.0.0`）で行う。複数ツールが入るが**タグは共通の 1 本**で、ツールは flake output 名（`#env-init` 等）で区別する。利用側は `<ref>` にタグ（または commit SHA）をピンし、実際の再現性は利用側の lock が固定する。

安定版は [GitHub Releases](https://github.com/airs/devtools/releases) の最新（Latest）を参照し、その `vX.Y.Z` を `<ref>` に pin する。

SemVer は各ツールの CLI 契約（引数・出力・終了コード）で判断する。

- **MAJOR**: 破壊的変更（フラグ改名・出力フォーマット変更・終了コード変更・ツール削除）
- **MINOR**: 後方互換の追加（新ツール追加・新しい任意フラグ）
- **PATCH**: 挙動を変えないバグ修正

## ツール

### env-init

現在の git worktree 用に `.env` を生成する汎用エンジン。worktree 番号 N を計算し、リポジトリルートの
`.env.template`（bash として 1 回評価される）から `.env` を書き出す。プロジェクト非依存設計で、実行時依存は
`bash` / `git` / `gawk` / `gnused` + coreutils。

**利用側 repo での使い方**:

1. `devbox.json` の `packages` に flake 参照を足し、init_hook で起動する。

   ```jsonc
   {
     "packages": ["github:airs/devtools/<ref>#env-init"],
     "shell": { "init_hook": ["[ -f .env ] || env-init"] }
   }
   ```

   `<ref>` は tag / commit でピンする。本リポジトリ自身の `devbox.json` は、ローカル flake を dogfood するため
   `path:.#env-init` を使う点だけが利用側と異なる。Nix を使わない環境では `pkgs/env-init/env-init` を直接実行できる
   （生スクリプトは単体実行可能なまま）。

2. **利用側 repo がルートに `.env.template` を用意する**（中央には持ち込まない repo 固有ファイル）。各 worktree で
   `N` を参照し、ポートを `$((BASE + N))` でずらし、secret を `openssl rand` / `op read` 等で書く。書式は本リポジトリ
   ルートの [`.env.template`](.env.template) を参照（コピー用ではなく書式例）。
