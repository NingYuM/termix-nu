#!/bin/bash
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.

LATEST_VERSION='0.100.0'
DEST_DIR='/usr/local/bin/'

# 处理命令行参数
if [ $# -eq 1 ]; then
    DEST_DIR=$1
    # 确保路径以 / 结尾
    [[ "${DEST_DIR}" != */ ]] && DEST_DIR="${DEST_DIR}/"
fi

# 在 bash 中声明关联数组时需要使用 declare -A 来明确指定
# 这是一个关联数组，否则，bash 可能会错误地处理数组索引
declare -A ASSETS
ASSETS=(
  ["Darwin_x86_64"]="x86_64-apple-darwin"
  ["Darwin_arm64"]="aarch64-apple-darwin"
  ["Darwin_aarch64"]="aarch64-apple-darwin"
  ["Linux_x86_64"]="x86_64-unknown-linux-musl"
  ["Linux_arm64"]="aarch64-unknown-linux-musl"
  ["Linux_aarch64"]="aarch64-unknown-linux-musl"
)

BASE_URL='https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell'

function is_installed() {
  command -v $1 &> /dev/null
}

function is_lower_ver() {
  [ "$(printf '%s\n' $1 $2 | sort -V | head -n1)" != $2 ]
}

function get_versions() {
  declare -A versions
  for bin in nu; do
    if ! is_installed $bin; then
      versions["$bin"]="0.0.0"
    else
      version=$($bin --version)
      versions[$bin]=$version
    fi
  done
  echo ${versions[@]}
}

function install_or_update() {
  local bin=$1
  local platform=$2
  echo "Installing or updating $bin for $platform ..."
  local assetName=$(wget -qO - $BASE_URL/latest.json | grep name | cut -d '"' -f 4 | grep ${ASSETS[$platform]})
  local pkg="/tmp/$assetName"
  wget -O $pkg $BASE_URL/$assetName
  if [ -w $DEST_DIR ]; then
    tar xzf $pkg -C $DEST_DIR
    mv $DEST_DIR/nu-*/* $DEST_DIR/
  else
    if is_installed sudo; then
      sudo tar xzf $pkg -C $DEST_DIR
      sudo mv $DEST_DIR/nu-*/nu* $DEST_DIR/
    else
      echo "Error: No write permission for $DEST_DIR and sudo is not available."
      exit 1
    fi
  fi
  rm $pkg
  echo "Successfully installed $bin with version $LATEST_VERSION"
}

function main() {
  current=$(get_versions)
  latest=$LATEST_VERSION
  platform="$(uname -s)_$(uname -m)"

  echo "Current Nu version: $current"
  echo " Latest Nu version: $latest"
  echo "  Current Platform: $platform"
  echo " Install Directory: $DEST_DIR"

  for bin in nu; do
    if is_lower_ver ${current[$bin]} $LATEST_VERSION; then
      install_or_update $bin $platform
    else
      echo "$bin is already updated ..."
    fi
  done

  echo '------------------------------------------------------------'

  nu actions/setup.nu $DEST_DIR
}

main
