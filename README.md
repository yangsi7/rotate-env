# rotate

> A small CLI that bulk-rotates every occurrence of an API-key env var across the `.env` and `.mcp.json` files found recursively from where you run it. Safe by hand or from an AI agent: it reads the new key from a file or env var and never surfaces it.

[![CI](https://github.com/yangsi7/rotate-env/actions/workflows/ci.yml/badge.svg)](https://github.com/yangsi7/rotate-env/actions/workflows/ci.yml)
[![ShellCheck](https://img.shields.io/badge/shellcheck-passing-brightgreen)](https://www.shellcheck.net/)
[![Release](https://img.shields.io/github/v/release/yangsi7/rotate-env?sort=semver)](https://github.com/yangsi7/rotate-env/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Your AI coding agent just pasted a live API key into twelve `.env` files and three `.mcp.json` configs across half your projects. Now you have to rotate it: find every file, replace the value in whatever quoting style each one happens to use, and do it without leaking the new key into your shell history or a committed template. `rotate` does exactly that, in one command, without ever printing the secret.

![rotate demo: finding every copy of a leaked API key across .env and .mcp.json files, then rotating them all in one command](demo.gif)

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
curl -fsSL https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.3/install.sh | bash
```

This installs `rotate` into `~/.local/bin` (no sudo). Prefer to read before you run? Inspect first:

```bash
curl -fsSLO https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.3/install.sh
less install.sh
bash install.sh
```

<details>
<summary>Manual install (git clone)</summary>

```bash
git clone https://github.com/yangsi7/rotate-env.git
cd rotate-env
make install          # copies rotate into ~/.local/bin (override with PREFIX=...)
# or just copy it anywhere on your PATH:
install -m 755 rotate ~/.local/bin/rotate
```

Uninstall with `make uninstall`, or `bash install.sh --uninstall`.
</details>

**Requirements:** `bash`, `awk`, and [`fd`](https://github.com/sharkdp/fd) (Debian/Ubuntu: `fd-find`, binary `fdfind`). [`jq`](https://jqlang.github.io/jq/) is needed only for `.mcp.json` files.

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

1. **Discover** target files with `fd` on every run (so new projects are picked up automatically). Directories named `node_modules`, `worktrees`, `.git`, `.next`, `dist`, `build` are pruned; `*.yaml`/`*.yml` files are skipped; and placeholder files (`*example*`, `*sample*`, `*template*`, `.env.dist`, `.env.tmpl`, `.env.defaults`, matched case-insensitively) plus `.bak`/`.orig` backups are excluded so a real secret is never written into a committed placeholder.
2. **Edit** `.env` files with `awk` (literal, quote-aware, exact-key) and `.mcp.json` with `jq walk` (covers env/headers/args).
3. **Write** atomically: a same-directory temp file, then `mv`, preserving the original permissions.

## Safety guarantees

- **The secret never appears on argv** (passed to `awk`/`jq` via the environment) and is **never printed** (all logs mask it to `ab****yz`).
- **Dry-run by default.** Nothing is written until `--apply`, and a dry-run never writes a temp file, so the new value never touches disk during a preview.
- **Idempotent.** Re-running with the same value changes nothing. Values already equal to the new one are skipped, so files that do not contain the key are never rewritten.
- **Atomic and reversible.** Per-file temp+`mv` with preserved permissions, plus optional `--backup` (chmod 600). Note there is no cross-file transaction: if a write fails midway, earlier files are already rotated, so use `--backup` when you want a rollback.

## Safe to run from an AI agent (or CI)

`rotate` is a plain command-line utility first: point it at a directory and it rotates the key across every matching file. Because it is built to never surface the secret, it is also safe to hand to an AI coding agent or a CI job, without leaking the key into a transcript, the model's context, or your logs (which is exactly the mess this tool exists to clean up).

- **It never prints the secret.** All output is masked to `ab****yz`, so the value never lands in an agent transcript, a CI log, or terminal scrollback.
- **It never puts the secret on argv.** The value is passed to `awk`/`jq` through the environment, so it cannot be captured via `ps`, shell history, or an agent's logged command line. Passing a secret as a `--value` flag is refused outright.
- **It runs fully non-interactive.** Provide the value via `$ROTATE_NEW_VALUE`, `--value-file`, or stdin and run `--apply --yes` with no TTY. Dry-run is the default, so an agent can preview the (masked) plan before committing.
- **It will not leak into committed files.** Placeholder and template files (`*example*`, `.env.dist`, and the like, matched case-insensitively) are never written, so an agent cannot accidentally rotate a real key into a git-tracked template.
- **It is deterministic and parseable.** Leveled logs go to stderr, data to stdout, and exit codes are stable (`0` ok, `2` usage, `127` missing dependency), so an agent can branch on the result. Runs are idempotent, so a retry is always safe.

An agent can rotate a compromised key across every project in one unattended call:

```bash
ROTATE_NEW_VALUE="$NEW_KEY" rotate --apply --yes ELEVENLABS_API_KEY
```

**Claude Code users:** this repo bundles a `/rotate-key` skill (`.claude/skills/rotate-key/`) that wraps the CLI with a safe, secret-never-surfaced workflow (preview, then apply with the value supplied out-of-band). It is available automatically when you work in a clone of this repo.

## Versioning

This project follows [Semantic Versioning](https://semver.org/). The public surface is the flags, output format, and exit codes. See [CHANGELOG.md](CHANGELOG.md).

## Contributing

Issues and PRs welcome. Run `make lint` (ShellCheck) and `make test` (bats) before submitting. CI runs both on Linux and macOS.

## License

[MIT](LICENSE) © yangsi7
