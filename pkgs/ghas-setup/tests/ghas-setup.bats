#!/usr/bin/env bats
# ghas-setup のテスト。ghas-setup は PATH 上にある前提（GHAS_SETUP で上書き可）。
# 実 org を変更するパス（gh api）は認証が要るため検証しない。認証なしで到達できる
# 引数パース・pre-flight・--dry-run（gh auth チェックより手前で exit）だけを対象にする。

GHAS_SETUP="${GHAS_SETUP:-ghas-setup}"

setup() {
  BASE="$BATS_TEST_TMPDIR"
  REPO="$BASE/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  git commit -q --allow-empty -m init
}

# .github/ghas.yml を書く（dry-run が読む全項目を含む）。
write_config() {
  mkdir -p "$1/.github"
  cat > "$1/.github/ghas.yml" <<'EOF'
org: example-org
configuration:
  name: example-default
  description: Test configuration.
  enforcement: enforced
  scanners:
    advanced_security: enabled
    secret_scanning: enabled
default_for_new_repos: all
attach_existing_repos: all
actions:
  default_workflow_permissions: read
  can_approve_pull_request_reviews: false
EOF
}

@test "不明な引数は usage を出して exit 1" {
  write_config "$REPO"
  run "$GHAS_SETUP" --nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: ghas-setup"* ]]
}

@test "git 管理外で実行すると明確なエラーで exit 1" {
  mkdir -p "$BASE/nongit"
  cd "$BASE/nongit"
  run "$GHAS_SETUP" --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"git worktree"* ]]
}

@test "config が無ければ exit 1" {
  run "$GHAS_SETUP" --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"config file が見つかりません"* ]]
}

@test "--dry-run は解決値と叩く API を出して exit 0（gh は呼ばない）" {
  write_config "$REPO"
  run "$GHAS_SETUP" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"org: example-org"* ]]
  [[ "$output" == *"name: example-default"* ]]
  [[ "$output" == *"これから叩く API"* ]]
  [[ "$output" == *"/orgs/example-org/actions/permissions/workflow"* ]]
}

@test "--config で別 yaml を渡せる" {
  mkdir -p "$BASE/alt"
  cat > "$BASE/alt/other.yml" <<'EOF'
org: alt-org
configuration:
  name: alt-default
  description: Alt.
  enforcement: unenforced
  scanners:
    advanced_security: enabled
default_for_new_repos: none
attach_existing_repos: none
actions:
  default_workflow_permissions: read
  can_approve_pull_request_reviews: false
EOF
  run "$GHAS_SETUP" --config "$BASE/alt/other.yml" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"org: alt-org"* ]]
}
