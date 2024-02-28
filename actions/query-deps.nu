#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/02/04 13:56:56
# REF:
#   - git ls-tree -r --name-only develop
# Usage:
#   t query-deps @terminus/approval-flow --all-branches

use ../utils/common.nu [hr-line, windows?, _TIME_FMT]

# Query node dependencies in all package.json files from the specified branches
export def 'query deps' [
  dep: string,                # The node dependency package name
  --dev(-d),                  # Query from `devDependencies`
  --branches(-b): string,     # The branches to query, multiple branches should be separated by `,`
  --all-local-branches(-l),   # Query from all local branches
  --all-remote-branches(-r),  # Query from all remote branches
] {
  let start = date now
  let rootDir = git rev-parse --show-toplevel
  cd $rootDir
  let branchCandidates = get-branches --branches $branches --all-local-branches=$all_local_branches --all-remote-branches=$all_remote_branches
  mut result = []
  let query = if $dev { $'devDependencies.\($dep)' } else { $'dependencies.\($dep)' }
  for br in $branchCandidates {
    let pkgs = git ls-tree -r --name-only $br | lines | where $it ends-with package.json
    for pkg in $pkgs {
      let content = git show $'($br):($pkg)'
      if ($content | is-empty) { continue }
      let ver = $content | query json $query
      if ($ver | is-empty) { continue }
      let commit = get-commit-meta $br $pkg $dep
      $result = ($result | append [{ branch: $br, file: $pkg, dependency: $dep, version: $ver, ...$commit }])
    }
  }
  let end = date now
  print $'(char nl)Query node dependencies for (ansi p)($dep)(ansi reset) from all `package.json` files:'; hr-line
  if ($result | is-empty) {
    print $'(ansi grey58)-- Nothing found --(ansi reset)(char nl)'
  } else {
    $result | sort-by -r commitAt | print
  }
  print $'Time elapsed: ($end - $start)'
}

def get-branches [--branches: string, --all-local-branches, --all-remote-branches] {
  if not ($branches | is-empty) {
    return ($branches | split row ',')
  }
  if $all_local_branches {
    return (git branch | lines | par-each -k { str substring 2.. })
  }
  if $all_remote_branches {
    git fetch origin -p
    return (git branch -r | lines | str trim | where $it starts-with origin/ | where $it !~ 'origin/HEAD')
  }
  return [(git branch --show-current)]
}

# Get the commit summary of the specified file and keyword
def get-commit-summary [branch: string, file: string, keyword: string] {
  let blame = git blame --line-porcelain $branch -- $file
  let grepKeyword = if (windows?) { $'"($keyword)"' } else { $'\"($keyword)\"' }
  let hasPrevious = ($blame | grep $grepKeyword -B 3) =~ 'previous'
  let count = if $hasPrevious { 12 } else { 11 }
  let selections = if $hasPrevious { [0 5 7 12] } else { [0 5 7 11] }
  let summary = ($blame | grep $grepKeyword -B $count | lines | select ...$selections)
  let SHA = $summary.0 | str substring 0..9
  let committer = $summary.1 | str trim | split row ' ' | get 1
  let commitAt = (($summary.2 | str trim | split row ' ' | get 1 | into int) * 1000 * 1000 * 1000 | into datetime) + 8hr
    | format date $_TIME_FMT
  return { SHA: $SHA, committer: $committer, commitAt: $commitAt }
}

# Same as get-commit-summary but remove usage of `grep`
# Get the commit meta of the specified file and keyword
def get-commit-meta [branch: string, file: string, keyword: string] {
  let blame = git blame $branch -- $file | lines | find $'"($keyword)"'
                      | split column ')' | rename meta content | get 0
  let meta = $blame.meta | detect columns -n
  let meta = if ($meta | columns | length) == 2 { $meta | rename SHA commit } else { $meta | rename SHA file commit }
  let commit = $meta.commit.0 | split row ' ' | compact --empty
  let commitAt = $commit | last 4 | first 2 | str join ' '
  let committer = $commit | first (($commit | length) - 4) | str join ' ' | str trim -c '('
  { SHA: $meta.SHA.0, committer: $committer, commitAt: $commitAt }
}

alias main = query deps
