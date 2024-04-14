#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/05 12:06:56
# Description: List remote node version, min version supported
# [√] List All LTS versions
# [√] List All node versions that greater or equal to minVer
# Ref: https://nodejs.org/dist/index.json
# Usage:
#   t ls-node
#   t ls-node v15
#   t ls-node v15 --lts

use ../utils/common.nu [ECODE]

const RELEASE_SOURCE = 'https://nodejs.org/dist/index.json'

export def ls-node-remote [
  minVer?: string,    # The min node version you want to query
  --lts,              # Filter the node versions that are LTS
] {

  let minVersion = if ($minVer | is-empty) { 16 } else { ($minVer | str replace 'v' '' | into int) }
  let vers = (http get $RELEASE_SOURCE | select version lts date npm? v8)
  let vRow = (
    $vers
      | upsert lts { if $in == false { '-' } else { $in }}
      | upsert NO { |node| (
        $node.version
          | split row ' '
          | first
          | split row '.'
          | first
          | str substring 1..
          | into int
        )}
  )

  if $lts {
    $vRow | where NO >= $minVersion | reject NO | where lts != '-' | print
  } else {
    $vRow | where NO >= $minVersion | reject NO | print
  }
}
