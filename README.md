# devtools

org 横断で共有する汎用 dev ツールの集約リポジトリ。各利用 repo はここを参照するだけにし、コピペを撲滅（DRY）してツールの版を固定する。

## 採用方式

Nix flake × devbox。言語非依存でツールを PATH へ配布し、`flake.lock` / `devbox.lock` で版とコンテナ build を再現可能に固定する。利用側 repo は同一の flake 参照を `devbox.json` の `packages` に足すだけでよい。

## 状態

初期化フェーズ。worktree 用の `.env` 生成エンジン `env-init` の移設を先頭バッチに、repo 非依存に枯れたツールから順次集約していく。
