
# Description Git Summary tool
# TODO:
#   [ ] Summary by author
#   [ ] Summary git repo from the specified branch
#   [ ] Add more repositorys to the list
#   [ ] Pull the latest commit of each repository before summary
#   [ ] Add a just task to do the summary automatically

const REPOS = [terp-ui service-ui nusi-slim nusi-flex material-ui termix-nu]
const MEMBERS = [hustcer wuu 曹琛尧 yangf artisan 沈泽棋 JSANN 周羿风]
const EXCLUDES = [
    pnpm-lock.yaml
    tools/.service-key-list.nu
    packages/pc/src/services
    packages/mobile/src/services
    packages/share/src/utils/generate/service-key-list.ts
    packages/share/src/utils/generate/model-key-mapping.ts
  ]
const NAME_MAP = {
  hustcer: '马俊', wuu: '吴冰雁', yangf: '杨帆', artisan: '蒋毅强', JSANN: '郑文宽'
}

# Git REPO Commit summary tool
def summary [
  --to(-t): string,
  --max-count(-c): int = 10000,
  --from(-f): string = '2024/04/07',
] {
  mut stats = []
  let to = if ($to | is-empty) { date now | format date %Y/%m/%d } else { $to }

  for repo in $REPOS {
    z $repo
    for a in $MEMBERS {
      mut stat = t git-stat --author $a --from $from --to $to --max-count $max_count --summary-only --json --exclude ($EXCLUDES | str join ',')
                        | from json
                        | upsert name ($NAME_MAP | get -o $a | default $a)
                        | upsert repo $repo
      $stats = ($stats | append $stat)
    }
  }
  $stats
    | select repo name commits insertions deletions uniqFileChanged
    | sort-by insertions -r
}

alias main = summary
