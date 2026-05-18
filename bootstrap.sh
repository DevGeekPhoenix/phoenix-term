#!/usr/bin/env bash
# Phoenix Term — curl-pipe-bash installer.

set -euo pipefail

REPO="${PHOENIX_REPO:-DevGeekPhoenix/phoenix-term}"
INSTALL_DIR="${PHOENIX_INSTALL_DIR:-$HOME/.phoenix-term}"
PIN_TAG="${PHOENIX_TAG:-}"

SEA=$'\e[38;2;32;178;170m'
YEL=$'\e[38;2;250;189;47m'
RED=$'\e[38;2;251;73;52m'
DIM=$'\e[38;2;120;120;120m'
B=$'\e[1m'
R=$'\e[0m'

say()  { printf "%s•%s %s\n" "$SEA" "$R" "$*"; }
warn() { printf "%s!%s %s\n" "$YEL" "$R" "$*" >&2; }
die()  { printf "%s✗%s %s\n" "$RED" "$R" "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required (sudo apt install curl  /  brew install curl)"
command -v tar  >/dev/null 2>&1 || die "tar is required"

printf "\n%s%sPhoenix Term — bootstrap%s\n" "$SEA" "$B" "$R"
printf "%srepo:%s         %s\n" "$DIM" "$R" "$REPO"
printf "%sinstall dir:%s  %s\n\n" "$DIM" "$R" "$INSTALL_DIR"

if [[ -n "$PIN_TAG" ]]; then
  TAG="$PIN_TAG"
  say "using pinned release: $TAG"
else
  # /releases/latest redirect avoids GitHub API auth + the 60-req/hr unauth rate limit.
  say "resolving latest release"
  RESOLVED=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/$REPO/releases/latest" 2>/dev/null || true)
  TAG="${RESOLVED##*/tag/}"
  if [[ -z "$TAG" || "$TAG" == "$RESOLVED" ]]; then
    die "no published releases at https://github.com/$REPO/releases — publish one first or pass PHOENIX_TAG=vX.Y.Z"
  fi
  say "latest release: $SEA$B$TAG$R"
fi

TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

say "downloading $TARBALL_URL"
curl -fsSL --retry 3 --connect-timeout 10 "$TARBALL_URL" -o "$TMP/phoenix.tar.gz" \
  || die "download failed — check your network and the release URL"

say "extracting"
tar -C "$TMP" -xzf "$TMP/phoenix.tar.gz"
SRC_DIR=$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)
[[ -d "$SRC_DIR" ]] || die "extraction produced no top-level directory"

if [[ -d "$INSTALL_DIR" ]]; then
  BAK="$INSTALL_DIR.bak-$(date +%Y%m%d%H%M%S)"
  say "moving existing $INSTALL_DIR → $BAK"
  mv "$INSTALL_DIR" "$BAK"
fi
mkdir -p "$(dirname "$INSTALL_DIR")"
mv "$SRC_DIR" "$INSTALL_DIR"
echo "$TAG" > "$INSTALL_DIR/.version"
say "extracted to $INSTALL_DIR ($TAG)"

[[ -f "$INSTALL_DIR/install.sh" ]] || die "install.sh missing from release tarball — bad release?"

printf "\n"
say "handing off to install.sh"
exec bash "$INSTALL_DIR/install.sh" "$@"
