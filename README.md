# devtools

org 横断で共有する汎用 dev ツールの集約リポジトリ。各利用 repo はここを参照するだけにし、コピペを撲滅（DRY）してツールの版を固定する。

## 参照用 Good Practice

本リポジトリは汎用ツールの集約に加え、設定・運用の実例を**他プロジェクトが Good Practice として参照する場所**でもある。言語・ツールに依存しない汎用ルールをここで枯らし、各プロジェクトは下敷きにして固有の参照ドキュメントを足して使う。

- [`.github/copilot-instructions.md`](.github/copilot-instructions.md) — GitHub Copilot のレビュー用カスタムインストラクション。YAGNI / DRY の徹底、重箱の隅をつつかない、初回レビューでの網羅と圧縮を中心に、レビューの収束を早める汎用ルール。

## 採用方式

Nix flake × devbox。言語非依存でツールを PATH へ配布し、`flake.lock` / `devbox.lock` で版とコンテナ build を再現可能に固定する。利用側 repo は同一の flake 参照を `devbox.json` の `packages` に足すだけでよい。

## 構成

```
flake.nix              # packages / checks (test・lint) / formatter を公開
devbox.json            # 開発環境（Nix の test/lint ツール）と自己 dogfooding
.env.template          # env-init 用テンプレートの書式例（本 repo の dogfood でも使用）
.github/ghas.yml       # ghas-setup 用ポリシー（本 repo の dogfood 兼・書式例）
.github/copilot-instructions.md  # Copilot レビュー用カスタムインストラクション（汎用 Good Practice）
pkgs/
  env-init/            # 各 pkg の構成は pkg 内 README を参照
  ghas-setup/
```

各パッケージの内部構成は [ツール](#ツール) の各 README を参照。

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

各リリースでは不変タグ `vX.Y.Z` に加え、同メジャーの移動タグ `vX` を最新へ追従させる。利用側は厳密 pin（`vX.Y.Z`）と
メジャー追従（`vX`）を `<ref>` で選べる。Nix flake の `<ref>` はワイルドカード／セムバー範囲を取れないため、メジャー追従は
このサーバ側の移動タグで実現する。

SemVer は各ツールの CLI 契約（引数・出力・終了コード）で判断する。

- **MAJOR**: 破壊的変更（フラグ改名・出力フォーマット変更・終了コード変更・ツール削除）
- **MINOR**: 後方互換の追加（新ツール追加・新しい任意フラグ）
- **PATCH**: 挙動を変えないバグ修正

配布物（env-init 等）は実行時ツール（bash・git・gawk・gnused・coreutils）を `flake.lock` の nixpkgs から同梱する。
このため `flake.lock` の更新は同梱ツールの版を変え、利用側へ届けるには release が必要になる。`flake.lock` を更新したら
SemVer を上げて release する。CLI 契約を変えない依存更新は **PATCH**、挙動が変わる場合は上の基準で MINOR / MAJOR に上げる。

## ツール

各ツールの使い方・前提・設定書式は各パッケージの README を参照。

- [env-init](pkgs/env-init/README.md) — 現在の git worktree 用に `.env` を生成する汎用エンジン。
- [ghas-setup](pkgs/ghas-setup/README.md) — GitHub org の GHAS / セキュリティ設定を `gh api` で一括適用する汎用エンジン。

利用側は `devbox.json` の `packages` に flake 参照（`github:airs/devtools/<ref>#<tool>`）を足す。`<ref>` の選び方は
[バージョニング](#バージョニング)を参照。本リポジトリ自身は dogfood のため `path:.#<tool>` を使う。Nix を使わない環境では
`pkgs/<tool>/<tool>` を直接実行できる（生スクリプトは単体実行可能なまま）。
