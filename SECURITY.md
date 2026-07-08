# Security Policy

`rotate` exists to rotate secrets safely, so its own handling of the secret is part of its contract.

## Threat model / guarantees

- The secret is **never placed on the command line** (argv is world-readable via `ps`). It is passed to `awk`/`jq` through the environment and read from a file, an env var, a silent TTY prompt, or stdin. Passing a secret via a `--value` flag is refused.
- The secret is **never printed**. All output is masked (`ab****yz`).
- **Dry-run is the default**, and a dry-run never writes a temp file, so the new value never touches disk during a preview.
- Writes are **atomic** (same-directory temp file, then `mv`) and preserve the original file's permissions. Optional backups are created `0600`.
- Placeholder/template files (`*example*`, `*sample*`, `*template*`, `.env.dist`, `.env.tmpl`, `.env.defaults`, matched case-insensitively) and `.bak`/`.orig` backups are **never written**, so a real secret is never rotated into a git-tracked placeholder.
- New values containing an embedded newline or carriage return are **rejected** (they could otherwise inject extra `.env` declarations).

## Supported versions

The latest `0.1.x` release is supported. Please upgrade before reporting.

## Reporting a vulnerability

Please report suspected vulnerabilities privately via GitHub's **"Report a vulnerability"** button under the repository's **Security** tab (Security Advisories), rather than opening a public issue. You will get an acknowledgement and a fix or mitigation timeline. Once a fix ships, coordinated disclosure is welcome.
