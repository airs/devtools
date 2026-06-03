# ghas-setup

GitHub **org 単位**で GHAS / Actions セキュリティ設定を `gh api`（code-security-configurations）で一括適用する汎用エンジン。
適用対象は repo 単位ではなく org 全体で、`default_for_new_repos` / `attach_existing_repos` により新規・既存 repo の両方へ反映される。
engine（本スクリプト）はロジックだけを持ち、org 名・scanner・enforcement・Actions 権限などのポリシー値はすべて config（`.github/ghas.yml`）由来。

## 構成

```
package.nix        # ghas-setup を makeWrapper で wrap する派生
ghas-setup         # エンジン本体（単体実行可能な生スクリプト）
tests/             # bats テスト
```

## 前提

- 対象 org で **GitHub Advanced Security (GHAS) が有効**であること。GHAS が有効でないと `advanced_security` 等の scanner 適用が失敗する。
- gh CLI が認証済みで **`admin:org` scope** を持つこと（org レベル設定の変更に必要）。

  ```sh
  gh auth login
  gh auth refresh -h github.com -s admin:org
  ```
- `yq`（mikefarah 版 = yq-go）。本パッケージは PATH に同梱する。

## 使い方

1. `devbox.json` の `packages` に flake 参照を足す。

   ```jsonc
   { "packages": ["github:airs/devtools/<ref>#ghas-setup"] }
   ```

   `<ref>` の選び方（メジャー追従／厳密 pin）はルート [README の「バージョニング」](../../README.md#バージョニング) を参照。

2. **利用側 repo がルートに `.github/ghas.yml` を用意する**（ポリシーの単一ソース。書式は下記）。

3. 適用する。org を変更する前に必ず `--dry-run` で解決値と叩く API を確認する。

   ```sh
   ghas-setup --dry-run          # org を変更せず適用予定を表示
   ghas-setup                    # .github/ghas.yml を org へ適用
   ghas-setup --config <path>    # 別の yaml を渡す（複数 org 用）
   ```

   config は呼び出した git worktree のルートの `.github/ghas.yml`（cwd 基準で解決）。`--config` で上書きできる。

## config（`.github/ghas.yml`）

書式は本リポジトリ実物の [`.github/ghas.yml`](../../.github/ghas.yml) を参照（コピー用の書式例）。利用側はこれをコピーして自 repo の
`.github/ghas.yml` に置き、`org` を自分の org 名に変える。各項目の意味は
[code security configurations の REST API ドキュメント](https://docs.github.com/en/rest/code-security/configurations) を参照。

主な項目:

- `org` — 適用対象の org 名。
- `configuration.name` / `description` / `enforcement` — code security configuration の識別名・説明・強制方法（`enforced` で repo 側のオーバーライドを禁止）。
- `configuration.scanners` — 有効化する scanner（`advanced_security` / `dependency_graph` / `dependabot_alerts` / `secret_scanning` ほか）と値。
- `default_for_new_repos` — 新規 repo の default configuration に指定する範囲（`all` = public/private 問わず）。
- `attach_existing_repos` — 既存 repo へ attach する範囲（`all` = org 内すべて）。
- `actions.default_workflow_permissions` — `GITHUB_TOKEN` の既定権限（`read` で最小化）。
- `actions.can_approve_pull_request_reviews` — workflow から PR レビュー承認を許すか（`false` で権限昇格経路を塞ぐ）。
