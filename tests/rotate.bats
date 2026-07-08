#!/usr/bin/env bats
#
# Test suite for `rotate`. Run with: bats tests/
#
# Fixtures are rebuilt per-test under $BATS_TEST_TMPDIR/mock. Secrets here are fake.

ROTATE="$BATS_TEST_DIRNAME/../rotate"
NEWVAL='sk_new_ABC-123.xyz'          # realistic value: alnum + - _ . (no quote chars)

setup() {
  FIX="$BATS_TEST_TMPDIR/mock"
  rm -rf "$FIX"
  mkdir -p "$FIX"/{projA,projB,projC,projD,node_modules/pkg}

  cat > "$FIX/projA/.env" <<'EOF'
# app config
ELEVENLABS_API_KEY=sk_old_bare
NEXT_PUBLIC_ELEVENLABS_API_KEY=sk_old_collision_prefix
ELEVENLABS_API_KEY_BACKUP=sk_old_collision_suffix
RESEND_API_KEY=re_untouched
EOF
  cat > "$FIX/projB/.env.local" <<'EOF'
ELEVENLABS_API_KEY="sk_old_dquote"
OTHER='keep_me'
ELEVENLABS_API_KEY=sk_old_comment # trailing comment kept
EOF
  cat > "$FIX/projB/.env" <<'EOF'
ELEVENLABS_API_KEY='sk_old_squote'
EOF
  cat > "$FIX/projC/.envrc" <<'EOF'
export ELEVENLABS_API_KEY=sk_old_export
export UNRELATED=leave_alone
EOF
  printf 'ELEVENLABS_API_KEY=\n' > "$FIX/projD/.env"

  cat > "$FIX/.mcp.json" <<'EOF'
{
  "mcpServers": {
    "elevenlabs": { "command": "npx", "args": ["-y", "@elevenlabs/mcp"], "env": { "ELEVENLABS_API_KEY": "sk_old_json_env" } },
    "gemini": { "command": "bash", "args": ["-c", "env", "ELEVENLABS_API_KEY=sk_old_json_args", "bunx", "gemini"] },
    "ref": { "type": "http", "url": "https://ref", "headers": { "x-ref-api-key": "keep_header" } },
    "other": { "env": { "GOOGLE_API_KEY": "keep_google", "NEXT_PUBLIC_ELEVENLABS_API_KEY": "keep_collision" } }
  }
}
EOF

  # files that must be excluded from discovery
  echo 'ELEVENLABS_API_KEY=DO_NOT_TOUCH_example' > "$FIX/projA/.env.example"
  echo 'ELEVENLABS_API_KEY=DO_NOT_TOUCH_bak'     > "$FIX/projA/.env.bak"
  echo 'ELEVENLABS_API_KEY=DO_NOT_TOUCH_bakts'   > "$FIX/projA/.env.bak.20250101000000"
  echo 'ELEVENLABS_API_KEY=DO_NOT_TOUCH_nm'      > "$FIX/node_modules/pkg/.env"
}

# deterministic content hash of the whole fixture tree (POSIX cksum)
tree_hash() {
  find "$FIX" -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s:' "$f"; cksum < "$f"
  done
}

apply()   { ROTATE_NEW_VALUE="$NEWVAL" run "$ROTATE" --apply --yes "$@" --root "$FIX"; }
dryrun()  { ROTATE_NEW_VALUE="$NEWVAL" run "$ROTATE" "$@" --root "$FIX"; }

# ---------------------------------------------------------------------------
# CLI surface
# ---------------------------------------------------------------------------
@test "--version prints version and exits 0" {
  run "$ROTATE" --version
  [ "$status" -eq 0 ]
  [[ "$output" == rotate\ * ]]
}

@test "no args prints usage to stderr and exits 2" {
  run "$ROTATE"
  [ "$status" -eq 2 ]
  [[ "$output" == *USAGE* ]]
}

@test "unknown option exits 2" {
  run "$ROTATE" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "--value on argv is refused (anti-leak)" {
  run "$ROTATE" --apply --value sekret KEY --root "$FIX"
  [ "$status" -eq 2 ]
  [[ "$output" == *"refusing to read a secret from the command line"* ]]
}

@test "invalid variable name is rejected" {
  ROTATE_NEW_VALUE=x run "$ROTATE" --apply --yes 'bad name!' --root "$FIX"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid variable name"* ]]
}

@test "empty new value is refused" {
  ROTATE_NEW_VALUE='' run "$ROTATE" --apply --yes ELEVENLABS_API_KEY --root "$FIX" </dev/null
  [ "$status" -eq 2 ]
  [[ "$output" == *"empty new value"* ]]
}

# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------
@test "--list finds real files, excludes example/bak/node_modules" {
  run "$ROTATE" --list --root "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/projA/.env"* ]]
  [[ "$output" == *"/.mcp.json"* ]]
  [[ "$output" != *".env.example"* ]]
  [[ "$output" != *".env.bak"* ]]
  [[ "$output" != *"node_modules"* ]]
}

@test "default scope is the current directory (no --root)" {
  cd "$FIX"
  run "$ROTATE" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"/projA/.env"* ]]
}

# ---------------------------------------------------------------------------
# Dry-run
# ---------------------------------------------------------------------------
@test "dry-run writes nothing and leaves no temp files" {
  before="$(tree_hash)"
  dryrun ELEVENLABS_API_KEY
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN"* ]]
  after="$(tree_hash)"
  [ "$before" = "$after" ]
  run find "$FIX" -name '.rotate.*'
  [ -z "$output" ]
}

@test "dry-run never prints the secret" {
  dryrun ELEVENLABS_API_KEY
  [[ "$output" != *"$NEWVAL"* ]]
  [[ "$output" != *"sk_old_"* ]]
}

# ---------------------------------------------------------------------------
# Apply: every .env shape
# ---------------------------------------------------------------------------
@test "apply replaces bare, quoted, single-quoted, export, empty, and inline-comment" {
  apply ELEVENLABS_API_KEY
  [ "$status" -eq 0 ]
  grep -qxF "ELEVENLABS_API_KEY=$NEWVAL" "$FIX/projA/.env"
  grep -qxF "ELEVENLABS_API_KEY=\"$NEWVAL\"" "$FIX/projB/.env.local"
  grep -qF  "ELEVENLABS_API_KEY=$NEWVAL # trailing comment kept" "$FIX/projB/.env.local"
  grep -qxF "ELEVENLABS_API_KEY='$NEWVAL'" "$FIX/projB/.env"
  grep -qxF "export ELEVENLABS_API_KEY=$NEWVAL" "$FIX/projC/.envrc"
  grep -qxF "ELEVENLABS_API_KEY=$NEWVAL" "$FIX/projD/.env"
}

@test "apply leaves collision and unrelated keys untouched" {
  apply ELEVENLABS_API_KEY
  grep -qxF "NEXT_PUBLIC_ELEVENLABS_API_KEY=sk_old_collision_prefix" "$FIX/projA/.env"
  grep -qxF "ELEVENLABS_API_KEY_BACKUP=sk_old_collision_suffix" "$FIX/projA/.env"
  grep -qF  "re_untouched" "$FIX/projA/.env"
  grep -qF  "UNRELATED=leave_alone" "$FIX/projC/.envrc"
}

@test "apply never touches excluded files" {
  apply ELEVENLABS_API_KEY
  grep -qF "DO_NOT_TOUCH_example" "$FIX/projA/.env.example"
  grep -qF "DO_NOT_TOUCH_bak" "$FIX/projA/.env.bak"
  grep -qF "DO_NOT_TOUCH_nm" "$FIX/node_modules/pkg/.env"
}

@test "apply never prints the secret" {
  apply ELEVENLABS_API_KEY
  [[ "$output" != *"$NEWVAL"* ]]
}

# ---------------------------------------------------------------------------
# Apply: JSON (.mcp.json)
# ---------------------------------------------------------------------------
@test "apply rewrites JSON env + args wrapper, keeps headers/google/collision, stays valid" {
  apply ELEVENLABS_API_KEY
  run jq -e . "$FIX/.mcp.json"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers.elevenlabs.env.ELEVENLABS_API_KEY' "$FIX/.mcp.json")" = "$NEWVAL" ]
  run jq -e --arg w "ELEVENLABS_API_KEY=$NEWVAL" '.mcpServers.gemini.args | index($w)' "$FIX/.mcp.json"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.mcpServers.ref.headers["x-ref-api-key"]' "$FIX/.mcp.json")" = "keep_header" ]
  [ "$(jq -r '.mcpServers.other.env.GOOGLE_API_KEY' "$FIX/.mcp.json")" = "keep_google" ]
  [ "$(jq -r '.mcpServers.other.env.NEXT_PUBLIC_ELEVENLABS_API_KEY' "$FIX/.mcp.json")" = "keep_collision" ]
}

# ---------------------------------------------------------------------------
# Idempotency, filtering, backups, permissions
# ---------------------------------------------------------------------------
@test "second apply with same value changes nothing (idempotent)" {
  apply ELEVENLABS_API_KEY
  apply ELEVENLABS_API_KEY
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to update"* ]]
}

@test "old-value filter only replaces matching occurrences" {
  mkdir -p "$FIX/one" "$FIX/two"
  printf 'TOK=leaked\n' > "$FIX/one/.env"
  printf 'TOK=other\n'  > "$FIX/two/.env"
  ROTATE_OLD_VALUE='leaked' ROTATE_NEW_VALUE='fresh' run "$ROTATE" --apply --yes TOK --root "$FIX"
  [ "$status" -eq 0 ]
  grep -qxF 'TOK=fresh' "$FIX/one/.env"
  grep -qxF 'TOK=other' "$FIX/two/.env"
}

@test "--backup writes a 0600 copy holding the old value, and is excluded on re-run" {
  P="$FIX/perm"; mkdir -p "$P"
  printf 'K=old\n' > "$P/.env"; chmod 640 "$P/.env"
  ROTATE_NEW_VALUE='newv' run "$ROTATE" --apply --yes --backup K --root "$P"
  [ "$status" -eq 0 ]
  grep -qxF 'K=newv' "$P/.env"

  # original perms preserved
  mode="$(stat -c '%a' "$P/.env" 2>/dev/null || stat -f '%Lp' "$P/.env")"
  [ "$mode" = "640" ]

  # backup exists, is 0600, holds old value
  bak="$(find "$P" -name '.env.bak.*')"
  [ -n "$bak" ]
  bmode="$(stat -c '%a' "$bak" 2>/dev/null || stat -f '%Lp' "$bak")"
  [ "$bmode" = "600" ]
  grep -qxF 'K=old' "$bak"

  # a re-run must NOT re-discover / corrupt the backup
  run "$ROTATE" --list --root "$P"
  [[ "$output" != *".bak."* ]]
}
