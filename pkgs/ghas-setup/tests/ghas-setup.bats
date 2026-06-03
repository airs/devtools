#!/usr/bin/env bats
# ghas-setup のテスト。引数パース・pre-flight・--dry-run は wrap 済みの ghas-setup（GHAS_SETUP、
# 既定は PATH 上の ghas-setup）で検証する。実適用パス（create/update 分岐・gh api 呼び出し列）は
# gh をスタブし、生スクリプト（GHAS_SETUP_RAW）を bash で直起動して検証する。wrapper は gh を
# PATH 先頭に prefix するため stub で上書きできないが、bash 直起動なら shebang を回避でき PATH 上の
# stub gh が使われる。

GHAS_SETUP="${GHAS_SETUP:-ghas-setup}"
# 実適用パス用の生スクリプト。flake check では nix store のパスが渡る。未設定時（repo で
# `bats pkgs/ghas-setup/tests` を直接実行）は隣の生スクリプトを既定にする。
GHAS_SETUP_RAW="${GHAS_SETUP_RAW:-$BATS_TEST_DIRNAME/../ghas-setup}"

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

# gh をスタブする。呼び出し引数を $GH_LOG に記録し、種別ごとに想定 stdout を返す:
#   - auth status              : "admin:org" を出力（scope 判定の grep 用）/ exit 0
#   - api（--paginate=lookup）  : 既存 lookup。$1（""=新規, それ以外=既存 id）を返す
#   - api（POST で末尾が /configurations）: 新規作成。固定 id 123 を返す
#   - その他 api                : 読み戻し等。{} を返す
# 併せて実 gh の制約「--slurp は --jq と併用不可」を再現し、両指定なら非 0 終了する
# （この組み合わせの regression を検知するため）。
make_gh_stub() {
  STUB_DIR="$BASE/stubbin"
  GH_LOG="$BASE/gh-calls.log"
  mkdir -p "$STUB_DIR"
  : > "$GH_LOG"
  {
    printf '#!%s\n' "$(command -v bash)"
    cat <<EOF
echo "\$*" >> "$GH_LOG"
case "\$1" in
  auth) echo "admin:org"; exit 0 ;;
  api)
    has_slurp=0; has_jq=0; has_paginate=0
    for a in "\$@"; do
      case "\$a" in
        --slurp) has_slurp=1 ;;
        --jq|-q) has_jq=1 ;;
        --paginate) has_paginate=1 ;;
      esac
    done
    if [ "\$has_slurp" = 1 ] && [ "\$has_jq" = 1 ]; then
      echo "the \`--slurp\` option is not supported with \`--jq\` or \`--template\`" >&2
      exit 1
    fi
    [ "\$has_paginate" = 1 ] && { printf '%s' "$1"; exit 0; }
    case "\$*" in
      *"--method POST"*"/code-security/configurations "*) printf '123'; exit 0 ;;
    esac
    echo '{}'; exit 0 ;;
esac
exit 0
EOF
  } > "$STUB_DIR/gh"
  chmod +x "$STUB_DIR/gh"
  PATH="$STUB_DIR:$PATH"
}

@test "不明な引数は usage を出して exit 1" {
  write_config "$REPO"
  run "$GHAS_SETUP" --nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage: ghas-setup"* ]]
}

@test "--config に値が無いと usage を出して exit 1" {
  write_config "$REPO"
  run "$GHAS_SETUP" --config
  [ "$status" -eq 1 ]
  [[ "$output" == *"--config に値がありません"* ]]
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

@test "適用(新規): 既存 config 無し → POST 作成 + defaults/attach/actions を config 値で叩く" {
  write_config "$REPO"
  make_gh_stub ""   # lookup は空 → 新規作成分岐
  run bash "$GHAS_SETUP_RAW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"configuration を新規作成"* ]]
  # 新規作成 POST と、作成された id=123 への defaults/attach/actions 適用
  grep -q -- "--method POST /orgs/example-org/code-security/configurations " "$GH_LOG"
  grep -q -- "/code-security/configurations/123/defaults" "$GH_LOG"
  grep -q -- "/code-security/configurations/123/attach" "$GH_LOG"
  grep -q -- "--method PUT /orgs/example-org/actions/permissions/workflow" "$GH_LOG"
  # config 値が field として渡る
  grep -q -- "default_for_new_repos=all" "$GH_LOG"
  grep -q -- "scope=all" "$GH_LOG"
  grep -q -- "can_approve_pull_request_reviews=false" "$GH_LOG"
  # 更新分岐は呼ばれない
  ! grep -q -- "--method PATCH" "$GH_LOG"
}

@test "適用(更新): 既存 config 有り → PATCH 更新し新規作成しない" {
  write_config "$REPO"
  make_gh_stub "999"   # lookup が既存 id を返す → 更新分岐
  run bash "$GHAS_SETUP_RAW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"既存 configuration を更新"* ]]
  grep -q -- "--method PATCH /orgs/example-org/code-security/configurations/999" "$GH_LOG"
  grep -q -- "/code-security/configurations/999/defaults" "$GH_LOG"
  # 新規作成 POST は叩かない
  ! grep -q -- "--method POST /orgs/example-org/code-security/configurations " "$GH_LOG"
}
