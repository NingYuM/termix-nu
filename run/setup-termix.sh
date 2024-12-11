#!/bin/bash
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.

DEST_DIR='/usr/local/bin/'

ASSETS=(
  ["macos_x86_64"]="x86_64-apple-darwin"
  ["macos_aarch64"]="aarch64-apple-darwin"
  ["linux_x86_64"]="x86_64-unknown-linux-musl"
  ["linux_aarch64"]="aarch64-unknown-linux-musl"
)

LATEST_META='https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell/latest.json'

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

function get_latest_versions() {
  declare -A versions
  version=$(curl -s "$LATEST_META" | jq -r '.version' | sed 's/v//')
  versions["nu"]=$version
  echo "${versions[@]}"
}

function install_or_update() {
  local bin=$1
  local platform=$2
  echo "Installing or updating $bin ..."
  local latest=$(curl -s "$LATEST_META")
  local assetName=$(echo "$latest" | jq -r ".assets[] | select(.name | test(\"${ASSETS[$platform]}\")) | .name")
  local pkg="/tmp/$assetName"
  curl -L -o "$pkg" "${LATEST_META/latest.json/$assetName}"
  if is_installed sudo; then
    sudo tar xzf "$pkg" -C "$DEST_DIR"
  else
    tar xzf "$pkg" -C "$DEST_DIR"
  fi
  rm "$pkg"
  echo "$bin is installed successfully with version $(echo "$latest" | jq -r '.version')"
}

function main() {
  platform="$(uname -s)_$(uname -m)"
  current=$(get_versions)
  latest=$(get_latest_versions)

  echo "Current Nu version: $current"
  echo "Latest  Nu version: $latest"

  for bin in nu; do
    if is_lower_ver "${current[$bin]}" "${latest[$bin]}"; then
      install_or_update "$bin" "$platform"
    else
      echo "$bin is updated ..."
    fi
  done

  nu run/setup.nu
}

main
