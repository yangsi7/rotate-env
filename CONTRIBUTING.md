# Contributing

Thanks for considering a contribution to `rotate`. Issues and pull requests are welcome.

## Development

`rotate` is a single Bash script (`rotate`) plus an installer (`install.sh`). Dependencies for development:

- `bash`, `awk`, `fd` (or `fdfind`), `jq`
- [`shellcheck`](https://www.shellcheck.net/) for linting
- [`bats-core`](https://github.com/bats-core/bats-core) for tests

```bash
make lint    # shellcheck rotate install.sh
make test    # bats tests/
```

CI runs both on Linux and macOS. Please make sure `make lint` and `make test` are green before opening a PR.

## Conventions

- Keep the tool a **single portable script**: POSIX-friendly Bash that runs on stock macOS `/bin/bash` (3.2) and modern bash, and works with both GNU and BSD userland (`stat`, `date`, `mktemp`, `cp`, `find`).
- **Never** let the secret reach argv or stdout/stderr. It goes to `awk`/`jq` via the environment and is masked in all logging. See `SECURITY.md`.
- Add or update a **bats test** for any behavior change (see `tests/rotate.bats`).
- Update **`CHANGELOG.md`** (Keep a Changelog format) and, for a release, bump the `VERSION` constant in `rotate` so `--version` matches the git tag.
- The README is human-facing prose: keep it free of em-dashes.

## Releasing (maintainers)

1. Bump `VERSION` in `rotate`, `DEFAULT_VERSION` in `install.sh`, and the README install URLs.
2. Update `CHANGELOG.md`.
3. Tag `vX.Y.Z`, push, and create a GitHub Release attaching `rotate`, `install.sh`, and `SHA256SUMS`.
4. Update the Homebrew formula (`yangsi7/homebrew-tap`) `url` + `sha256`, then `brew audit --strict --online` and `brew test`.
