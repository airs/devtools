#!/usr/bin/env bats
# env-init のフルセットテスト。env-init は PATH 上にある前提（ENV_INIT で上書き可）。

ENV_INIT="${ENV_INIT:-env-init}"

setup() {
  # base を正規化せず $BATS_TEST_TMPDIR をそのまま使う。macOS では symlink (/var → /private/var)
  # を含むため、env-init 側の canonicalize_dir によるパス正規化（symlink 跨ぎでの primary 判定・
  # sibling 除外）を実地で検証することになる。
  BASE="$BATS_TEST_TMPDIR"
  REPO="$BASE/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  git commit -q --allow-empty -m init
}

# 評価専用ロジック行・コメント・空行・算術・空値代入を含むテンプレートを書く。
write_template() {
  cat > "$1/.env.template" <<'EOF'
# comment line
APP_NAME="demo"
PORT_APP=$((3000 + N))
EMPTY=

if true; then :; fi
EOF
}

@test "--help はヘッダを出して exit 0" {
  run "$ENV_INIT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktree"* ]]
}

@test "未知の引数は exit 2" {
  run "$ENV_INIT" --nope
  [ "$status" -eq 2 ]
}

@test "git 管理外で実行すると明確なエラーで exit 1" {
  mkdir -p "$BASE/nongit"
  cd "$BASE/nongit"
  run "$ENV_INIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"git worktree"* ]]
}

@test ".env.template が無ければ exit 1" {
  run "$ENV_INIT"
  [ "$status" -eq 1 ]
  [[ "$output" == *".env.template not found"* ]]
}

@test "primary は N=0 で .env を生成し権限 600・評価専用行は出力しない" {
  write_template "$REPO"
  run "$ENV_INIT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Generated"* ]]
  [ -f "$REPO/.env" ]
  grep -qx 'WORKTREE_N=0' "$REPO/.env"
  grep -qx 'APP_NAME="demo"' "$REPO/.env"
  grep -qx 'PORT_APP="3000"' "$REPO/.env"
  grep -qx 'EMPTY=""' "$REPO/.env"
  grep -qx '# comment line' "$REPO/.env"
  ! grep -q 'if true' "$REPO/.env"
  perm="$(stat -c '%a' "$REPO/.env" 2>/dev/null || stat -f '%Lp' "$REPO/.env")"
  [ "$perm" = "600" ]
}

@test "冪等性: 再実行で skip、--force で再生成" {
  write_template "$REPO"
  run "$ENV_INIT"
  [ "$status" -eq 0 ]
  run "$ENV_INIT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
  run "$ENV_INIT" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"Generated"* ]]
}

@test "-n は N を設定し先頭ゼロを除去、不正値は exit 2" {
  write_template "$REPO"
  run "$ENV_INIT" -n 5
  [ "$status" -eq 0 ]
  grep -qx 'WORKTREE_N=5' "$REPO/.env"
  grep -qx 'PORT_APP="3005"' "$REPO/.env"

  run "$ENV_INIT" --force -n 08
  [ "$status" -eq 0 ]
  grep -qx 'WORKTREE_N=8' "$REPO/.env"

  run "$ENV_INIT" --force -n abc
  [ "$status" -eq 2 ]

  run "$ENV_INIT" -n
  [ "$status" -eq 2 ]
}

@test "N が 99 を超えると exit 1" {
  write_template "$REPO"
  run "$ENV_INIT" -n 100
  [ "$status" -eq 1 ]
}

@test "sibling worktree は最小未使用 N を得て、解放後の N を再利用する" {
  write_template "$REPO"
  "$ENV_INIT"

  git worktree add -q "$BASE/wtA" -b branchA
  write_template "$BASE/wtA"
  ( cd "$BASE/wtA" && "$ENV_INIT" )
  grep -qx 'WORKTREE_N=1' "$BASE/wtA/.env"

  git worktree add -q "$BASE/wtB" -b branchB
  write_template "$BASE/wtB"
  ( cd "$BASE/wtB" && "$ENV_INIT" )
  grep -qx 'WORKTREE_N=2' "$BASE/wtB/.env"

  git worktree remove --force "$BASE/wtA"
  git worktree add -q "$BASE/wtC" -b branchC
  write_template "$BASE/wtC"
  ( cd "$BASE/wtC" && "$ENV_INIT" )
  grep -qx 'WORKTREE_N=1' "$BASE/wtC/.env"
}
