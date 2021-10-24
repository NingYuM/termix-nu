# Author: hustcer
# Created: 2021/10/05 12:06:56
# Description: List remote node version, min version supported
# [√] List All LTS versions
# Ref: https://nodejs.org/dist/index.json
# Usage:
#   t ls-node
#   t ls-node v15
#   t ls-node v15 true

def 'ls-node-remote' [
    minVer?: string  # The node version you want to query
    isLts: string    # Filter the node versions that are LTS
] {
    let installed = ((which fnm | length) > 0)
    let minVersion = (if ($minVer | empty?) { 10 } { ($minVer | str find-replace 'v' '' | into int) })
    if $installed {}  {
        $'You should install `fnm` and try again..., bye!'
        exit --now
    }

    let vers = (fnm ls-remote | lines | str trim | wrap Version)
    let vRow = (
        $vers | insert NO { |node| (
                $node.Version |
                split row ' ' |
                first |
                split row '.' |
                first |
                str substring (1,) |
                into int
            )
        } | insert isLTS { |node| ($node.Version | str contains '(') }
    )
    if $isLts == 'true' {
        echo ($vRow | where NO >= $minVersion | where isLTS | select Version)
    } {
        echo ($vRow | where NO >= $minVersion | select Version)
    }
}
