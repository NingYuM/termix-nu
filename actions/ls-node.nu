# Author: hustcer
# Created: 2021/10/05 12:06:56
# Description: List remote node version, min version supported
# Usage:
#   t ls-node
#   t ls-node v15

def 'ls-node-remote' [
    minVer?: string  # The node version you want to query
] {
    let installed = ((which fnm | length) > 0)
    let minVersion = (if ($minVer | empty?) { 10 } { ($minVer | str find-replace 'v' '' | into int) })
    if $installed {}  {
        $'You should install `fnm` and try again..., bye!'
        exit --now
    }

    let vers = (fnm ls-remote | lines | str trim | wrap ver)
    let vRow = (
        $vers | insert NO { |node| (
                $node.ver |
                split row ' ' |
                first |
                split row '.' |
                first |
                str substring '1,' |
                into int
            )
        }
    )
    echo ($vRow | where NO >= $minVersion | select ver)
}

ls-node-remote $nu.env.NODE_MIN_VER
