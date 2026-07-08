---
name: rotate-key
description: Rotate a leaked or expired API-key env variable across every .env and .mcp.json file in a project, safely and without ever printing the secret. Use when a key was committed/leaked/exposed (e.g. an agent pasted it into config files) and needs replacing everywhere at once, or on scheduled credential rotation.
disable-model-invocation: true
argument-hint: [VAR_NAME]
allowed-tools: Bash(rotate:*), Bash(rotate --list:*), Bash(rotate --version:*)
---

# rotate-key

Rotate the value of a secret env variable across every `.env` / `.env.*` / `.envrc` / `.mcp.json`
file in the current project, using the [`rotate`](https://github.com/yangsi7/rotate-env) CLI.

The whole point is to do this **without leaking the secret** into the transcript, the model's
context, or logs. Follow these rules exactly.

## Preconditions

- `rotate` must be installed and on `PATH` (`rotate --version`). If it is not, tell the user:
  `brew install yangsi7/tap/rotate` or
  `curl -fsSL https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.3/install.sh | bash`.
- You need the variable name (e.g. `ELEVENLABS_API_KEY`). If `$ARGUMENTS` is empty, ask the user
  which variable to rotate.

## Procedure

1. **Preview first (never skip).** Run a dry-run to show which files hold the key. This writes
   nothing and the value is masked:

   ```
   rotate <VAR_NAME>
   ```

   Show the user the list of files that would change and confirm this is what they expect.

2. **Get the new value without exposing it.** Do NOT ask the user to paste the secret into the
   chat, and NEVER put it on the command line (no `--value` flag; argv is world-readable via `ps`).
   Instead have the user provide it out-of-band, in order of preference:
   - a file: they save the new key to `~/new.key`, then you run
     `rotate --apply --yes --value-file ~/new.key <VAR_NAME>`;
   - an env var they export in their own shell (`export ROTATE_NEW_VALUE=...`) before you run
     `rotate --apply --yes <VAR_NAME>`.

   If neither is possible, instruct the user to run the apply command themselves in their terminal.

3. **Apply.** Once the value is supplied out-of-band, rotate everywhere non-interactively:

   ```
   rotate --apply --yes <VAR_NAME>
   ```

   Report the `[ok] rotated ... in N file(s)` result. The value stays masked (`ab****yz`) in all
   output, so it is safe to relay.

4. **Remind** the user to revoke the OLD key at the provider and to delete any temporary
   `~/new.key` file.

## Safety rules (do not violate)

- Never echo, print, cat, or otherwise surface the secret value. `rotate` masks it; you must not
  un-mask it.
- Never pass the secret as a command-line argument. Use `--value-file` or `$ROTATE_NEW_VALUE`.
- Prefer `--backup` (`rotate --apply --yes --backup <VAR_NAME>`) when the user wants a rollback.
- Scope with `--root <dir>` if the user only wants a subtree; default is the current directory,
  recursively.
