#!/bin/bash
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.

LATEST_VERSION='0.100.0'
DEST_DIR='/usr/local/bin/'

ASSETS=(
  ["macos_x86_64"]="x86_64-apple-darwin"
  ["macos_aarch64"]="aarch64-apple-darwin"
  ["linux_x86_64"]="x86_64-unknown-linux-musl"
  ["linux_aarch64"]="aarch64-unknown-linux-musl"
)

BASE_URL='https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell'

function is_installed() {
  command -v "$1" &> /dev/null
}

function is_lower_ver() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

function get_versions() {
  declare -A versions
  for bin in nu; do
    if ! is_installed "$bin"; then
      versions["$bin"]="0.0.0"
    else
      version=$("$bin" --version)
      versions["$bin"]=$version
    fi
  done
  echo "${versions[@]}"
}

function install_or_update() {
  local bin=$1
  local platform=$2
  echo "Installing or updating $bin ..."
  local assetName=$(wget -qO - "$BASE_URL/latest.json" | grep name | cut -d '"' -f 4 | grep "${ASSETS[$platform]}")
  local pkg="/tmp/$assetName"
  wget -O "$pkg" "$BASE_URL/$assetName"
  if is_installed sudo; then
    sudo tar xzf "$pkg" -C "$DEST_DIR"
  else
    tar xzf "$pkg" -C "$DEST_DIR"
  fi
  rm "$pkg"
  echo "$bin is installed successfully with version $LATEST_VERSION"
}

function main() {
  current=$(get_versions)
  latest=$LATEST_VERSION
  platform="$(uname -s)_$(uname -m)"

  echo "Current Nu version: $current"
  echo "Latest  Nu version: $latest"

  for bin in nu; do
    if is_lower_ver "${current[$bin]}" "$LATEST_VERSION"; then
      install_or_update "$bin" "$platform"
    else
      echo "$bin is updated ..."
    fi
  done

  nu run/setup.nu
}

main
