#!/bin/bash
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.

DEST_DIR='/usr/local/bin/'
BASE_URL='https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell'

# 处理命令行参数
if [ $# -eq 1 ]; then
  DEST_DIR=$1
  # Make sure DEST_DIR ends with a slash
  [[ "${DEST_DIR}" != */ ]] && DEST_DIR="${DEST_DIR}/"
fi

# Check if command exists
function is_installed() {
  command -v $1 &> /dev/null
}

# Check if first version is lower than second version
function is_lower_ver() {
  [ "$(printf '%s\n' $1 $2 | sort -V | head -n1)" != $2 ]
}

# Get current version of nu, or 0.0.0 if not installed
function get_versions() {
  local version
  if ! is_installed nu; then
    version="0.0.0"
  else
    version=$(nu --version)
  fi
  echo $version
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
  echo $latest
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
  local targetArch=$(get_target_arch $platform)

  # Use wget or curl to get the latest release asset name for the specified platform
  local assetName
  if is_installed curl; then
    assetName=$(curl -s $BASE_URL/latest.json | grep name | cut -d '"' -f 4 | grep ${targetArch})
  elif is_installed wget; then
    assetName=$(wget -qO - $BASE_URL/latest.json | grep name | cut -d '"' -f 4 | grep ${targetArch})
  else
    echo "Error: Neither wget nor curl is installed. Please install one of them and try again."
    exit 1
  fi

  local pkg="/tmp/$assetName"

  # Use wget or curl to download the package for installation
  if is_installed wget; then
    wget -O $pkg $BASE_URL/$assetName
  else
    curl -L -o $pkg $BASE_URL/$assetName
  fi

  if [ -w $DEST_DIR ]; then
    tar xzf $pkg -C $DEST_DIR
    mv $DEST_DIR/nu-*/nu* $DEST_DIR/
    rm -rf $DEST_DIR/nu-*
  else
    if is_installed sudo; then
      sudo tar xzf $pkg -C $DEST_DIR
      sudo mv $DEST_DIR/nu-*/nu* $DEST_DIR/
      sudo rm -rf $DEST_DIR/nu-*
    else
      echo "Error: No write permission for $DEST_DIR and sudo is not available."
      exit 1
    fi
  fi
  rm $pkg
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
    if is_lower_ver ${current[$bin]} $latest; then
      install_or_update $bin $platform $latest
    else
      echo "$bin is already updated ..."
    fi
  done

  echo '------------------------------------------------------------'

  nu actions/setup.nu $DEST_DIR --in-place-update
}

main
