# env-init

現在の git worktree 用に `.env` を生成する汎用エンジン。worktree 番号 N を計算し、リポジトリルートの
`.env.template`（bash として 1 回評価される）から `.env` を書き出す。プロジェクト非依存設計で、実行時依存は
`bash` / `git` / `gawk` / `gnused` + coreutils。

## 構成

```
package.nix        # env-init を makeWrapper で wrap する派生
env-init           # エンジン本体（単体実行可能な生スクリプト）
tests/             # bats テスト
```

## 利用側 repo での使い方

1. `devbox.json` の `packages` に flake 参照を足し、init_hook で起動する。

   ```jsonc
   {
     "packages": ["github:airs/devtools/<ref>#env-init"],
     "shell": { "init_hook": ["[ -f .env ] || env-init"] }
   }
   ```

   `<ref>` の選び方（メジャー追従／厳密 pin）はルート [README の「バージョニング」](../../README.md#バージョニング) を参照。

   本リポジトリ自身の `devbox.json` は、ローカル flake を dogfood するため `path:.#env-init` を使う点だけが利用側と
   異なる。Nix を使わない環境では `pkgs/env-init/env-init` を直接実行できる（生スクリプトは単体実行可能なまま）。

2. **利用側 repo がルートに `.env.template` を用意する**（中央には持ち込まない repo 固有ファイル）。各 worktree で
   `N` を参照し、ポートを `$((BASE + N))` でずらし、secret を `openssl rand` / `op read` 等で書く。書式は本リポジトリ
   ルートの [`.env.template`](../../.env.template) を参照（コピー用ではなく書式例）。
