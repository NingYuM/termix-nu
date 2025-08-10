#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/05 12:06:56
# Description: List remote node version, min version supported
# [√] List All LTS versions
# [√] List All node versions that greater or equal to minVer
# Ref: https://nodejs.org/dist/index.json
# Usage:
#   t ls-node
#   t ls-node v18
#   t ls-node v18 --lts

use ../utils/common.nu [ECODE]

const RELEASE_SOURCE = 'https://nodejs.org/dist/index.json'

@example '查询已发布 Node 版本，最小主版本默认为 18' {
  t ls-node
} --result '输出信息包含版本、LTS 标识、发布时间、内置 npm 与 v8 版本'
@example '查询 20 及以上的 Node 版本' {
  t ls-node 20
}
@example '查询 18 及以上的 Node LTS 版本' {
  t ls-node v18 --lts
}
export def ls-node-remote [
  minVer?: string,    # The min node version you want to query
  --lts,              # Filter the node versions that are LTS
] {

  let minVersion = if ($minVer | is-empty) { 18 } else { $minVer | str trim -c v | into int }
  let vers = http get $RELEASE_SOURCE | select version lts date npm? v8
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
