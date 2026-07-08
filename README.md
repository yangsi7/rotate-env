# rotate

> Rotate a leaked or expired API-key env variable across all your `.env` and `.mcp.json` files, safely.

[![CI](https://github.com/yangsi7/rotate-env/actions/workflows/ci.yml/badge.svg)](https://github.com/yangsi7/rotate-env/actions/workflows/ci.yml)
[![ShellCheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://www.shellcheck.net/)
[![Release](https://img.shields.io/github/v/release/yangsi7/rotate-env?sort=semver)](https://github.com/yangsi7/rotate-env/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Your AI coding agent just pasted a live API key into twelve `.env` files and three `.mcp.json` configs across half your projects. Now you have to rotate it: find every file, replace the value in whatever quoting style each one happens to use, and do it without leaking the new key into your shell history or a committed template. `rotate` does exactly that, in one command, without ever printing the secret.

![rotate in action](demo.gif)

## Quickstart

```bash
# 1) Dry-run: see every file that holds the key (writes NOTHING):
rotate SOME_API_KEY_ENV_VAR

# 2) Rotate it everywhere, unattended:
ROTATE_NEW_VALUE='sk_your_new_api_key_value' rotate --apply --yes SOME_API_KEY_ENV_VAR
```

By default `rotate` searches the current directory recursively. Point it elsewhere with `--root`:

```bash
rotate --apply --root ~/code ELEVENLABS_API_KEY
```

## Install

**Homebrew** (macOS and Linux):

```bash
brew install yangsi7/tap/rotate
```

**Install script** (any Unix with `curl`):

```bash
curl -fsSL https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.2/install.sh | bash
```

This installs `rotate` into `~/.local/bin` (no sudo). Prefer to read before you run? Inspect first:

```bash
curl -fsSLO https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.2/install.sh
less install.sh
bash install.sh
```

<details>
<summary>Manual install (git clone)</summary>

```bash
git clone https://github.com/yangsi7/rotate-env.git
cd rotate-env
make install          # symlinks rotate into ~/.local/bin (override with PREFIX=...)
# or just copy it anywhere on your PATH:
install -m 755 rotate ~/.local/bin/rotate
```

Uninstall with `make uninstall`, or `bash install.sh --uninstall`.
</details>

**Requirements:** `bash`, [`fd`](https://github.com/sharkdp/fd) (Debian/Ubuntu: `fd-find`, binary `fdfind`), and [`jq`](https://jqlang.github.io/jq/) (only for `.mcp.json` files).

## Use cases

- **AI agent leaked a key.** An agent copied a secret into many project files. Rotate it everywhere at once.
- **Compromised or expired key.** You regenerated a provider key and need every project to pick up the new one.
- **Offboarding / credential hygiene.** Someone left, or a key aged out of policy. Rotate on a schedule.
- **Monorepos and many-project setups.** One secret referenced from dozens of `.env` files and MCP configs.

## Usage

```
rotate [options] <VAR_NAME>
```

Default mode is a masked dry-run preview. Pass `--apply` to actually write (with a confirmation prompt, or `--yes` to skip it).

| Option | Description |
| --- | --- |
| `-n, --dry-run` | Preview changes without writing (the default) |
| `--apply` | Write changes (prompts for confirmation) |
| `-y, --yes` | Skip the confirmation prompt (needed for non-interactive `--apply`) |
| `-b, --backup` | Copy each file to `<file>.bak.<ts>` (chmod 600) before writing |
| `--value-file <path>` | Read the new value from a file |
| `--old-value-file <path>` | Only replace occurrences whose current value matches (surgical) |
| `--root <dir>` | Recursive search root (repeatable; replaces the default) |
| `--shallow-root <dir>` | Depth-1 search root (repeatable) |
| `--max-depth <n>` | Limit recursion depth |
| `--list` | List the discovered target files and exit |
| `-v, --verbose` | Debug logging |
| `-V, --version` | Print version |
| `-h, --help` | Full help with more examples |

### Providing the new value (never on the command line)

The secret is never read from a flag, because command-line arguments are visible to every process via `ps`. Provide it one of these ways instead:

```bash
rotate --apply --value-file ~/new.key ELEVENLABS_API_KEY   # from a file
ROTATE_NEW_VALUE='sk_...' rotate --apply ELEVENLABS_API_KEY # from an env var
pbpaste | rotate --apply ELEVENLABS_API_KEY                 # piped on stdin
rotate --apply ELEVENLABS_API_KEY                           # silent interactive prompt
```

### Surgical rotation

Only replace the specific leaked value, leaving any other values of the same variable untouched:

```bash
ROTATE_OLD_VALUE='sk_leaked' ROTATE_NEW_VALUE='sk_fresh' rotate --apply --yes ANTHROPIC_API_KEY
```

## Supported file formats

**`.env`, `.env.*`, `.envrc`** (`=` separator), every common shape:

```bash
KEY=value
KEY="value"
KEY='value'
export KEY=value
KEY=                       # empty / declared-but-unset is filled in
KEY=value # inline comment  (comment preserved)
```

The original quoting style, `export` prefix, and trailing comment are all preserved, and the value is inserted literally (so `/`, `&`, and backslashes in a key are safe). Matching is exact, so rotating `API_KEY` never touches `GOOGLE_API_KEY` or `NEXT_PUBLIC_API_KEY`.

**`.mcp.json`** (JSON `:` separator), all three places a secret hides:

```jsonc
{ "mcpServers": {
  "a": { "env":     { "ELEVENLABS_API_KEY": "value" } },        // env block
  "b": { "headers": { "x-api-key": "value" } },                  // HTTP headers
  "c": { "args": ["env", "ELEVENLABS_API_KEY=value", "cmd"] }    // args[] wrapper
}}
```

## How it works

1. **Discover** target files with `fd` on every run (so new projects are picked up automatically). `node_modules`, git worktrees, `.git`, and example/sample/template/backup files are excluded so a real secret is never written into a committed placeholder.
2. **Edit** `.env` files with `awk` (literal, quote-aware, exact-key) and `.mcp.json` with `jq walk` (covers env/headers/args).
3. **Write** atomically: a same-directory temp file, then `mv`, preserving the original permissions.

## Safety guarantees

- **The secret never appears on argv** (passed to `awk`/`jq` via the environment) and is **never printed** (all logs mask it to `ab****yz`).
- **Dry-run by default.** Nothing is written until `--apply`, and a dry-run never writes a temp file, so the new value never touches disk during a preview.
- **Idempotent.** Re-running with the same value changes nothing. Values already equal to the new one are skipped, so files that do not contain the key are never rewritten.
- **Atomic and reversible.** Per-file temp+`mv` with preserved permissions, plus optional `--backup` (chmod 600). Note there is no cross-file transaction: if a write fails midway, earlier files are already rotated, so use `--backup` when you want a rollback.

## Versioning

This project follows [Semantic Versioning](https://semver.org/). The public surface is the flags, output format, and exit codes. See [CHANGELOG.md](CHANGELOG.md).

## Contributing

Issues and PRs welcome. Run `make lint` (ShellCheck) and `make test` (bats) before submitting. CI runs both on Linux and macOS.

## License

[MIT](LICENSE) © yangsi7
