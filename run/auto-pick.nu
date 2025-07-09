# Usage:
#   nu --config $nu.config-path run/auto-pick.nu
#   nu --config $nu.config-path run/auto-pick.nu --repo service-ui

def main [
  --list-only(-l),                  # Only list the commits to be picked
  --repo(-r): string = 'terp-ui',   # The repository to do the picking
] {
  let list = if $list_only { '--list-only' } else { '' }
  if $repo =~ 'terp' {
    z $repo; t pull-all
    print $'(char nl)Start to auto pick commits in (ansi g)($repo)(ansi rst) ...'
    t git-pick 0330 --from release/2.5.24.0330 --to develop $list
    t git-pick 0330 --from develop --to release/2.5.24.0330 $list
    t git-pick 0330 --from release/latest --to develop $list
    t git-pick 0330 --from develop --to release/latest $list
  }
  if $repo =~ 'service' {
    z $repo; t pull-all
    print $'(char nl)Start to auto pick commits in (ansi g)($repo)(ansi rst) ...'
    t git-pick 0330 --from release/2.5.24.0330 --to develop $list
    t git-pick 0415 --from release/2.5.24.0415 --to develop $list
    t git-pick 0330 --from release/2.5.24.0330 --to release/latest $list
    t git-pick 0330 --from develop --to release/2.5.24.0330 $list
    t git-pick 0330 --from develop --to release/2.5.24.0415 $list
    t git-pick 0415 --from develop --to release/2.5.24.0415 $list
    t git-pick 0415 --from feature/terp --to release/2.5.24.0415 $list
    t git-pick 0330 --from feature/terp --to release/2.5.24.0330 $list
    t git-pick 0330 --from feature/terp --to release/2.5.24.0415 $list
  }
}
