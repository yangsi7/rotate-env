# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this project is

`rotate` is a single-file Bash CLI that bulk-rotates the value of a named secret env variable across every `.env` / `.env.*` / `.envrc` / `.mcp.json` file found recursively from where it runs. Source of truth: the `rotate` script at the repo root. `install.sh` is the installer; the Homebrew formula lives in a separate repo (`yangsi7/homebrew-tap`).

## Build / test / lint

```bash
make lint    # shellcheck rotate install.sh   (must be clean)
make test    # bats tests/                    (must be green)
```

Requirements: `bash`, `awk`, `fd` (or `fdfind`), `jq`, plus `shellcheck` and `bats-core` for the checks.

## Invariants you must not break

- **The secret never reaches argv or stdout/stderr.** It is passed to `awk`/`jq` via the environment and masked in every log line. Do not add debug output that prints file contents or the value.
- **Portability:** must run on stock macOS `/bin/bash` (3.2) and modern bash, with GNU or BSD userland. Avoid bash-4-only features unless guarded; prefer the existing helpers (`file_mode`, `is_placeholder`).
- **Placeholders are never written:** `is_placeholder()` (case-insensitive) is the authoritative guard that keeps secrets out of template/example/backup files. Extend it rather than relying on `fd` excludes alone.
- Any behavior change needs a matching test in `tests/rotate.bats`, a `CHANGELOG.md` entry, and (for a release) a `VERSION` bump so `--version` matches the tag.

## Using rotate itself (it is agent-safe)

`rotate` is designed to be run by an agent without leaking the key. Feed the new value via `$ROTATE_NEW_VALUE`, `--value-file`, or stdin (never as an argument) and run non-interactively:

```bash
ROTATE_NEW_VALUE="$NEW_KEY" rotate --apply --yes SOME_API_KEY_ENV_VAR
```

Preview first with a plain `rotate SOME_API_KEY_ENV_VAR` (dry-run, writes nothing, output is masked).

## Do not

- Commit real secrets, `.env` files, or `.rotate.*` / `*.bak.*` artifacts (see `.gitignore`).
- Add em-dashes to the README (human-facing prose).
