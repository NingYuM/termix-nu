#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/01/15 13:56:56
# Description: Upload commonly used tools to OSS
# TODO:
# [√] Setup ossutil
# [√] Upload Nushell to OSS
# [√] Upload Just to OSS
# [√] Create meta info for uploaded assets
# [√] Create a Github action to upload assets automatically

use ../utils/common.nu [ECODE, compare-ver]

const ASSET_PREFIX = 'open-tools'

const TOOL_MAP = {
    just: 'casey/just',
    nushell: 'nushell/nushell',
    # nushell: 'nushell/nightly',
  }

export def setup-oss-util [
  --endpoint(-e): string,    # The endpoint of OSS
  --ak-id(-k): string,       # The access key id of OSS
  --ak-secret(-s): string,   # The access key secret of OSS
  --sts-token(-t): string,   # The STS token of OSS
] {
  sudo -v ; curl https://gosspublic.alicdn.com/ossutil/install.sh | sudo bash
  if ($sts_token | is-empty) {
    ossutil config --endpoint $endpoint --access-key-id $ak_id --access-key-secret $ak_secret
  } else {
    ossutil config --endpoint $endpoint --access-key-id $ak_id --access-key-secret $ak_secret --sts-token $sts_token
  }
}

export def oss-assets-upload [
  name: string,           # The name of the asset, currently support: nushell, just
  --bucket(-b): string,   # The bucket name of OSS to store the asset
] {
  let rootPath = $'oss://($bucket)/($ASSET_PREFIX)'
  let toolPath = $'oss://($bucket)/($ASSET_PREFIX)/($name)'
  let latestPath = $'oss://($bucket)/($ASSET_PREFIX)/($name)/latest.json'

  [$rootPath, $toolPath] | each {|it|
    if (ossutil ls $it | str contains 'Object Number is: 0') {
      ossutil mkdir $it
    }
  } | ignore

  let shouldSync = (ossutil ls $latestPath | str contains 'Object Number is: 0') or (compare-tools-ver $name $toolPath) == -1
  if $shouldSync { sync-latest-assets $name $toolPath } else { print $'No need to sync latest assets for ($name).' }
}

def compare-tools-ver [
  name: string,
  toolPath: string,
] {
  let latestPath = $'($toolPath)/latest.json'
  let latest = ossutil cat $latestPath | lines | where $it !~ 'elapsed' | str join | from json
  let ossVersion = $latest.version
  let repo = $TOOL_MAP | get $name
  let assetMeta = http get $'https://api.github.com/repos/($repo)/releases/latest'
  compare-ver $ossVersion $assetMeta.tag_name
}

def sync-latest-assets [
  name: string,
  toolPath: string,
] {

  let repo = $TOOL_MAP | get $name
  let assetMeta = http get $'https://api.github.com/repos/($repo)/releases/latest'
  mut assets = $assetMeta | get assets.browser_download_url
  if ($name == 'nushell') {
    $assets = ($assets | where $it =~ 'full')
  }
  print $'Syncing latest assets of ($name) to OSS...'
  ossutil rm --force -r $toolPath
  mkdir $name
  $assets | each {|it| aria2c $it -d $name }

  let latestMeta = {
    version: $assetMeta.tag_name,
    publishAt: $assetMeta.published_at,
    repo: $'https://github.com/($repo)',
    assets: (ls -s $name | to json),
  }

  $latestMeta | save $'($name)/latest.json'
  ossutil cp --recursive $name $toolPath
}
