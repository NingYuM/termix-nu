#!/bin/bash
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

DEST_DIR='/usr/local/bin/'
BASE_URL='https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell'

# 显示帮助信息
function show_help() {
  echo "Usage: $0 [OPTIONS] [DEST_DIR]"
  echo ""
  echo "Install or update nushell (nu) binary on macOS or Linux."
  echo ""
  echo "Arguments:"
  echo "  DEST_DIR    Installation directory (default: /usr/local/bin/)"
  echo ""
  echo "Options:"
  echo "  -h, --help  Show this help message and exit"
  echo ""
  echo "Examples:"
  echo "  $0                    # Install to /usr/local/bin/"
  echo "  $0 /opt/bin           # Install to /opt/bin/"
  echo "  $0 ~/bin              # Install to ~/bin/"
}

# 处理命令行参数
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [ $# -eq 1 ]; then
  DEST_DIR=$1
  # Make sure DEST_DIR ends with a slash
  [[ "${DEST_DIR}" != */ ]] && DEST_DIR="${DEST_DIR}/"
fi

# Check if command exists
function is_installed() {
  command -v "$1" &> /dev/null
}

function validate_archive_entries() {
  local pkg=$1
  local entry
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ "$entry" == /* || "$entry" == ../* || "$entry" == *"/../"* || "$entry" == *"/.." ]]; then
      echo "Error: Unsafe archive entry found in $pkg: $entry"
      exit 1
    fi
  done < <(tar tzf "$pkg")
}

# Check if first version is lower than second version
function is_lower_ver() {
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

# Get current version of nu, or 0.0.0 if not installed
function get_versions() {
  local version
  if ! is_installed nu; then
    version="0.0.0"
  else
    version=$(nu --version)
  fi
  echo "$version"
}

# Use wget or curl to get the latest binary version
function get_latest_version() {
  local latest
  if is_installed curl; then
    latest=$(curl -s $BASE_URL/version.json)
  elif is_installed wget; then
    latest=$(wget -qO - $BASE_URL/version.json)
  else
    echo "Error: Neither wget nor curl is installed. Please install one of them and try again."
    exit 1
  fi
  echo "$latest"
}

# Get target package name keyword for the specified platform
get_target_arch() {
  local platform=$1
  case $platform in
    'Darwin_x86_64')                  echo 'x86_64-apple-darwin' ;;
    'Darwin_arm64'|'Darwin_aarch64')  echo 'aarch64-apple-darwin' ;;
    'Linux_x86_64')                   echo 'x86_64-unknown-linux-musl' ;;
    'Linux_arm64'|'Linux_aarch64')    echo 'aarch64-unknown-linux-musl' ;;
    *)  echo "Unsupported platform: $platform" && exit 1 ;;
  esac
}

# Install or update nu binary for the specified platform
function install_or_update() {
  local bin=$1
  local platform=$2
  local version=$3
  echo "Installing or updating $bin for $platform ..."
  mkdir -p "$DEST_DIR"
  local targetArch=$(get_target_arch "$platform")

  # Use wget or curl to get the latest release asset name for the specified platform
  local assetName
  if is_installed curl; then
    assetName=$(curl -s $BASE_URL/latest.json | grep name | cut -d '"' -f 4 | grep "${targetArch}")
  elif is_installed wget; then
    assetName=$(wget -qO - $BASE_URL/latest.json | grep name | cut -d '"' -f 4 | grep "${targetArch}")
  else
    echo "Error: Neither wget nor curl is installed. Please install one of them and try again."
    exit 1
  fi

  local pkg="/tmp/$assetName"

  # Use wget or curl to download the package for installation
  if is_installed wget; then
    wget -O "$pkg" $BASE_URL/"$assetName"
  else
    curl -L -o "$pkg" $BASE_URL/"$assetName"
  fi

  validate_archive_entries "$pkg"
  local stage_dir
  stage_dir=$(mktemp -d)
  tar xzf "$pkg" -C "$stage_dir"
  shopt -s nullglob
  local staged_bins=("$stage_dir"/nu-*/nu*)
  shopt -u nullglob
  if [ ${#staged_bins[@]} -eq 0 ]; then
    rm -rf "$stage_dir" "$pkg"
    echo "Error: Failed to find extracted nu binaries in $assetName"
    exit 1
  fi

  if [ -w "$DEST_DIR" ]; then
    mv "${staged_bins[@]}" "$DEST_DIR"/
  else
    if is_installed sudo; then
      sudo mv "${staged_bins[@]}" "$DEST_DIR"/
    else
      rm -rf "$stage_dir" "$pkg"
      echo "Error: No write permission for $DEST_DIR and sudo is not available."
      exit 1
    fi
  fi
  rm -rf "$stage_dir"
  rm "$pkg"
  # 删除不需要的插件文件，忽略不存在的情况
  rm -f "$DEST_DIR"/nu_*cust* "$DEST_DIR"/nu_*exam* "$DEST_DIR"/nu_*str* 2>/dev/null || true
  echo "Successfully installed $bin with version $version"
}

# Install or update nu binary for the current platform
function main() {
  current=$(get_versions)
  latest=$(get_latest_version)
  platform="$(uname -s)_$(uname -m)"

  echo "Current Nu version: $current"
  echo " Latest Nu version: $latest"
  echo "  Current Platform: $platform"
  echo " Install Directory: $DEST_DIR"

  for bin in nu; do
    if is_lower_ver "$current" "$latest"; then
      install_or_update $bin "$platform" "$latest"
    else
      echo "$bin is already updated ..."
    fi
  done

  echo '------------------------------------------------------------'

  # Get the directory where the script is located
  SCRIPT_DIR="$(dirname "$0")"
  local nu_cmd
  if [[ -x "${DEST_DIR}nu" ]]; then
    nu_cmd="${DEST_DIR}nu"
  else
    nu_cmd="$(command -v nu)"
  fi
  # Call the nu script with the correct path
  "$nu_cmd" "$SCRIPT_DIR/../actions/setup.nu" "$DEST_DIR" --in-place-update

  if [[ "${TERMIX_SKIP_POST_SETUP:-0}" != "1" ]]; then
    "$nu_cmd" "$SCRIPT_DIR/post-setup.nu" "$SCRIPT_DIR/.."
  fi
}

main
