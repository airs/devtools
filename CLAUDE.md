# CLAUDE.md

このファイルは Claude Code（claude.ai/code）が本リポジトリを扱う際のガイダンス。人間向けの一次情報は README.md にあり、重複は避けて README を参照する。

## 位置づけ

org 横断で共有する汎用 dev ツールの集約先。ツールはまず各利用 repo で実運用に揉んで枯らし、repo 非依存（特定のポート名・secret 名・repo 固有パスを知らない）になったものから本リポジトリへ移設する。

## 構成と開発の前提

- パッケージは `pkgs/<name>/` に `package.nix` と生スクリプトを同居させる。生スクリプトは `#!/usr/bin/env bash`
  始まりで単体実行可能なまま保ち、wrap は外側に被せるだけで中身を書き換えない（env-init は `runCommand` + `makeWrapper`
  で PATH を被せ、shebang のみビルド時に絶対 bash へ固定する）。`writeShellApplication` はスクリプト本文前に
  プリアンブルを差し込み `$0` 依存の挙動を壊しうるため、本文を保ちたいツールでは避ける。
- test / lint の真実は `flake.nix` の `checks`（shellcheck・bats・statix・deadnix・nixfmt）に一元化する。
  `devbox.json` の scripts はそれへの薄い委譲。
- 開発環境は devbox（`devbox run check` など）。ツール一覧の二重管理を避けるため flake の devShell は設けない。

## 公開リポジトリの制約

本リポジトリは public 公開する。成果物（ドキュメント・コード・コミット等）に、プライベートリポジトリや非公開 Issue への言及を入れない。設計の背景が非公開リソースにある場合でも、公開成果物は自己完結した記述にする。
