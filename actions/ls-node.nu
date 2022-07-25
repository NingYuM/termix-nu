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
#   t ls-node v15 true

def 'ls-node-remote' [
  minVer: string   # The node version you want to query
  isLts: bool      # Filter the node versions that are LTS
] {

  # brew install fnm to install it, see: https://github.com/Schniz/fnm
  let notInstalled = (which fnm | length) == 0
  let minVersion = if ($minVer | empty?) { 10 } else { ($minVer | str replace 'v' '' | into int) }
  if $notInstalled {
    $'You should install `fnm` and try again..., bye!'
    exit --now
  }

  let vers = (fnm ls-remote | lines | str trim | wrap Version)
  let vRow = (
    $vers | upsert NO { |node| (
      $node.Version
        | split row ' '
        | first
        | split row '.'
        | first
        | str substring '1,'
        | into int
    )} | upsert isLTS { |node| ($node.Version | str contains '(') }
  )
  if $isLts {
    # ($vRow | where {|node| $node.NO >= $minVersion && $node.isLTS } | select Version)
    echo ($vRow | where NO >= $minVersion | where isLTS == true | select Version)
  } else {
    echo ($vRow | where NO >= $minVersion | select Version)
  }
}
