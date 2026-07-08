#!/usr/bin/env bash
#
# install.sh — installer for `rotate` (https://github.com/yangsi7/rotate-env)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.3/install.sh | bash
#
# Prefer to inspect first (recommended):
#   curl -fsSLO https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.3/install.sh
#   less install.sh
#   bash install.sh
#
# Options:
#   --bin-dir <dir>   Install into <dir> (default: ~/.local/bin, fallback /usr/local/bin)
#   --version <tag>   Install a specific release tag (default: the tag this script ships with)
#   --uninstall       Remove an installed `rotate`
#   -h, --help        Show this help
#
# The whole body lives inside main(), invoked on the last line, so a truncated
# download can never partially execute.
#
# shellcheck disable=SC2016  # the $PATH shown to the user must stay literal
set -euo pipefail

REPO="yangsi7/rotate-env"
DEFAULT_VERSION="v0.1.3"
DL_TMP=""   # global so the EXIT trap can clean it under `set -u`

info()  { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33mwarn:\033[0m %s\n' "$*" >&2; }
err()   { printf '\033[0;31merror:\033[0m %s\n' "$*" >&2; }
die()   { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

install_usage() {
  cat <<'EOF'
install.sh — installer for rotate (https://github.com/yangsi7/rotate-env)

Usage:
  curl -fsSL https://raw.githubusercontent.com/yangsi7/rotate-env/v0.1.3/install.sh | bash

Options:
  --bin-dir <dir>   Install into <dir> (default: ~/.local/bin, fallback /usr/local/bin)
  --version <tag>   Install a specific release tag (default: the shipped tag)
  --uninstall       Remove an installed rotate
  -h, --help        Show this help
EOF
}

pkg_hint() {  # pkg_hint <tool>  -> prints a per-platform install hint
  local tool=$1
  if have brew;    then printf '  brew install %s\n' "$tool"; fi
  if have apt-get; then printf '  sudo apt-get install %s\n' "$tool"; fi
  if have dnf;     then printf '  sudo dnf install %s\n' "$tool"; fi
  if have pacman;  then printf '  sudo pacman -S %s\n' "$tool"; fi
}

check_deps() {
  local missing=0
  if ! have bash; then err "bash is required"; missing=1; fi
  if ! have fd && ! have fdfind; then
    err "fd is required (Debian/Ubuntu: package 'fd-find', binary 'fdfind')"
    pkg_hint fd; pkg_hint fd-find; missing=1
  fi
  if ! have jq; then
    err "jq is required (needed for .mcp.json files)"
    pkg_hint jq; missing=1
  fi
  [[ $missing -eq 0 ]] || die "install the missing dependencies above, then re-run"
}

pick_bin_dir() {  # echoes a writable bin dir
  local d=$1
  if [[ -n $d ]]; then printf '%s' "$d"; return; fi
  if [[ -d "$HOME/.local/bin" || ! -e "$HOME/.local/bin" ]]; then
    printf '%s' "$HOME/.local/bin"; return
  fi
  printf '%s' "/usr/local/bin"
}

on_path() {  # is <dir> on PATH?
  case ":$PATH:" in *":$1:"*) return 0 ;; *) return 1 ;; esac
}

download() {  # download <url> <dest>
  if have curl; then curl -fsSL --proto '=https' --tlsv1.2 "$1" -o "$2"
  elif have wget; then wget -qO "$2" "$1"
  else die "need curl or wget to download"; fi
}

main() {
  local bin_dir_opt="" version="$DEFAULT_VERSION" uninstall=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --bin-dir)   [[ $# -ge 2 ]] || die "--bin-dir needs a dir"; bin_dir_opt=$2; shift ;;
      --bin-dir=*) bin_dir_opt=${1#*=} ;;
      --version)   [[ $# -ge 2 ]] || die "--version needs a tag"; version=$2; shift ;;
      --version=*) version=${1#*=} ;;
      --uninstall) uninstall=1 ;;
      -h|--help)   install_usage; exit 0 ;;
      *) die "unknown option: $1" ;;
    esac
    shift
  done

  local bin_dir; bin_dir=$(pick_bin_dir "$bin_dir_opt")

  if [[ $uninstall -eq 1 ]]; then
    if [[ -e "$bin_dir/rotate" ]]; then
      rm -f -- "$bin_dir/rotate"; info "removed $bin_dir/rotate"
    else
      warn "no rotate found in $bin_dir"
    fi
    exit 0
  fi

  check_deps

  mkdir -p -- "$bin_dir" || die "cannot create $bin_dir"
  [[ -w $bin_dir ]] || die "$bin_dir is not writable (try --bin-dir ~/.local/bin)"

  local url="https://raw.githubusercontent.com/$REPO/$version/rotate"
  local dest="$bin_dir/rotate"
  DL_TMP=$(mktemp)
  trap 'rm -f -- "${DL_TMP:-}"' EXIT

  info "downloading rotate ($version)"
  download "$url" "$DL_TMP" || die "download failed from $url"
  head -1 "$DL_TMP" | grep -q '^#!' || die "downloaded file does not look like a script"

  install -m 755 "$DL_TMP" "$dest" 2>/dev/null || { cp -f -- "$DL_TMP" "$dest"; chmod 755 "$dest"; }
  info "installed $dest"

  if ! on_path "$bin_dir"; then
    warn "$bin_dir is not on your PATH. Add this to your shell profile:"
    printf '\n  export PATH="%s:$PATH"\n\n' "$bin_dir"
  fi

  info "done — run: rotate --help"
}

main "$@"
