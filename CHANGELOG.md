# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-07-08

Initial public release.

### Added
- Rotate a named env variable's value across `.env`, `.env.*`, `.envrc`, and `.mcp.json`
  files, discovered at runtime with `fd` (default: current directory, recursive).
- `.env` rewriting via `awk`: preserves quoting style (bare / double / single), the
  `export` prefix, and trailing inline comments; fills empty `KEY=`; exact-key matching
  (no substring collisions); literal value insertion (safe for `/`, `&`, backslashes).
- `.mcp.json` rewriting via `jq walk`: handles `env` blocks, `headers` blocks, and the
  inline `args[]` `"KEY=value"` wrapper form.
- Dry-run by default with a masked preview; `--apply` writes after confirmation
  (`--yes` to skip). Atomic temp+`mv` writes with preserved permissions.
- Secret handling: never passed on argv (goes to `awk`/`jq` via the environment),
  never printed (masked in all output). New value via `--value-file`,
  `$ROTATE_NEW_VALUE`, an interactive silent prompt, or stdin.
- Surgical rotation via `--old-value-file` / `$ROTATE_OLD_VALUE` (replace only a
  specific current value). Idempotent (skips values already equal to the new one).
- `--backup` (timestamped, chmod 600), `--root` / `--shallow-root` / `--max-depth`,
  `--list`, `--verbose`, `--version`, and `--help`.
- Default excludes: `node_modules`, git worktrees, `.git`, and
  example/sample/template/backup files (so a real secret is never written into a
  committed placeholder).
- `install.sh` installer (dependency checks, `~/.local/bin`, `--uninstall`,
  `--bin-dir`, `--version` pin) and a `Makefile` (`install` / `uninstall` / `test` / `lint`).
- ShellCheck + bats CI on Linux and macOS.

[Unreleased]: https://github.com/yangsi7/rotate-env/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yangsi7/rotate-env/releases/tag/v0.1.0
