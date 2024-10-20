#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables
: "${VERSION:="ventura"}"  # OSX Version

TMP="$STORAGE/tmp"
BASE_IMG_ID="InstallMedia"
BASE_IMG="$STORAGE/base.dmg"
BASE_VERSION="$STORAGE/$PROCESS.version"

downloadImage() {

  local board
  local version="$1"
  local file="BaseSystem"
  local path="$TMP/$file.dmg"

  case "${version,,}" in
    "sequoia" | "15"* )
      board="Mac-7BA5B2D9E42DDD94" ;;
    "sonoma" | "14"* )
      board="Mac-827FAC58A8FDFA22" ;;
    "ventura" | "13"* )
      board="Mac-4B682C642B45593E" ;;
    "monterey" | "12"* )
      board="Mac-B809C3757DA9BB8D" ;;
    "bigsur" | "big-sur" | "11"* )
      board="Mac-2BD1B31983FE1663" ;;
    "catalina" | "10.15"* )
      board="Mac-00BE6ED71E35EB86" ;;
    "mojave" | "10.14"* )
      board="Mac-7BA5B2DFE22DDD8C" ;;
    "highsierra" | "10.13"* )
      board="Mac-7BA5B2D9E42DDD94" ;;
    *)
      error "Unknown VERSION specified, value \"${version}\" is not recognized!"
      return 1 ;;
  esac

  local msg="Downloading macOS ${version^}"
  info "$msg recovery image..." && html "$msg..."

  rm -rf "$TMP"
  mkdir -p "$TMP"

  /run/progress.sh "$path" "" "$msg ([P])..." &

  # if ! /run/fetch.py -b "$board" -n "$file" -os latest -o "$TMP" download; then
  echo /run/fetch.py -s "${version,,}" -n "$file" -o "$TMP"
  # python3 --version

  if ! /run/fetch.py -s "${version,,}" -n "$file" -o "$TMP"; then
    error "Failed to fetch macOS \"${version^}\" recovery image with board id \"$board\"!"
    fKill "progress.sh"
    return 1
  fi

  fKill "progress.sh"

  if [ ! -f "$path" ] || [ ! -s "$path" ]; then
    error "Failed to find file \"$path\" !"
    return 1
  fi

  mv -f "$path" "$BASE_IMG"
  rm -rf "$TMP"

  echo "$version" > "$BASE_VERSION"
  return 0
}

if [ ! -f "$BASE_IMG" ] || [ ! -s "$BASE_IMG" ]; then
  if ! downloadImage "$VERSION"; then
    rm -rf "$TMP"
    exit 34
  fi
fi

STORED_VERSION=""
if [ -f "$BASE_VERSION" ]; then
  STORED_VERSION=$(<"$BASE_VERSION")
fi

if [ "$VERSION" != "$STORED_VERSION" ]; then
  info "Different version detected, switching base image from \"$STORED_VERSION\" to \"$VERSION\""
  if ! downloadImage "$VERSION"; then
    rm -rf "$TMP"
    exit 34
  fi
fi

DISK_OPTS="-device virtio-blk-pci,drive=${BASE_IMG_ID},bus=pcie.0,addr=0x6"
DISK_OPTS+=" -drive file=$BASE_IMG,id=$BASE_IMG_ID,format=dmg,cache=unsafe,readonly=on,if=none"

return 0
