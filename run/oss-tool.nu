
const EXTRA_KEEP = [versions.json latest.json]
const OSS_PREFIX = 'oss://terminus-new-trantor/fe-resources'
const OSS_HTTP_PREFIX = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources'

const ITERATIONS = [
  2.5.23.1228
  2.5.24.0115
  2.5.24.0130
  2.5.24.0228
  2.5.24.0315
  2.5.24.0330
  2.5.24.0415
  2.5.24.0430
  2.5.24.0530
  2.5.24.0630
  2.5.24.0730
  2.5.24.0830
  2.5.24.0930
  2.5.24.1030
  2.5.24.1130
  2.5.24.1230
  2.5.25.0130
  2.5.25.0228
  2.5.25.0330
  3.0.2506
  3.0.2508
  3.0.2509
  3.0.2512
]

# oss-du 2.5.23.1228 --> Output: 3.0 GB
export def oss-du [mountpoint: string] {
  let mount = $mountpoint | str trim -c / | ($in)/
  ossutil du ($OSS_PREFIX)/($mount)
    | complete | get stdout | lines | where {|it| $it =~ '^total du size'}
    | first | split row ':' | last
    | into filesize
}

# oss-stat --> Output: table with size of each iteration and total
export def oss-stat [limit: int = 3] {
  let time = date now
  $env.config.table.mode = 'psql'
  let stats = $ITERATIONS | last $limit | par-each -k {|it|
    { iteration: $it, size: (oss-du $it) }
  }
  let total = $stats | get size | math sum
  # Print the table
  print ($stats | table)
  print $"(ansi g)Total: ($total)(ansi rst)"
  let endTime = date now
  print $"(ansi g)Time: ($endTime - $time)(ansi rst)"
}

# 删除 OSS 上过期的静态资源，只保留最近一个版本
export def oss-clean-deprecated-statics [mountpoint: string = 'ttt0'] {
  $env.config.table.mode = 'psql'
  print $'Current size of (ansi g)($mountpoint)(ansi rst) before cleaning: (ansi g)(oss-du $mountpoint)(ansi rst)'
  let start = date now
  let mp = $mountpoint | str trim -c /
  let keep_modules = try {
    http get ($OSS_HTTP_PREFIX)/($mp)/latest.json | values | get dirname
  } catch {
    print $"(ansi r)Failed to fetch latest.json for ($mp), please check network or path.(ansi rst)"
    return
  }
  print $'Keeping the following modules for (ansi g)($mp)(ansi rst): (char nl)'
  print $keep_modules
  let remove_candidates = get-remove-candidates $mp $keep_modules
  print $'(char nl)Removing the following objects for (ansi g)($mp)(ansi rst): (char nl)'
  print $remove_candidates; print -n (char nl)

  let confirm  = input $'Are you sure to remove the above objects? (ansi g)[Y/n](ansi rst) '
  if ($confirm | str downcase) != 'y' { print $'(ansi grey66)Aborted by user, Bye...(ansi rst)'; exit 0 }
  let results = $remove_candidates | par-each {|it|
    { path: $it, result: (ossutil rm -rf $it | complete) }
  }
  let failures = $results | where { $in.result.exit_code != 0 }
  if ($failures | length) > 0 {
    print $"(ansi r)Failed to remove ($failures | length) objects:(ansi rst)"
    print ($failures | get path)
  }
  let end = date now
  print $'Cleaned (ansi g)(($remove_candidates | length) - ($failures | length))(ansi rst) objects successfully!'
  print $"(ansi g)Time: ($end - $start)(ansi rst)"
  print $'Current size of (ansi g)($mountpoint)(ansi rst) after cleaning: (ansi g)(oss-du $mountpoint)(ansi rst)'
}

# Get direct children objects of a mountpoint
def get-direct-children [mountpoint: string] {
  let mount = $mountpoint | str trim -c / | ($in)/
  ossutil ls ($OSS_PREFIX)/($mount) -d | lines | where $it =~ '^oss://'
}

# Get remove candidates by mountpoint and keep modules
def get-remove-candidates [mountpoint: string, keep_modules: list<string>] {
  let children = get-direct-children $mountpoint
  let keep = $keep_modules | append $EXTRA_KEEP
  $children | where {|it| ($it | str trim -c / | split row / | last) not-in $keep }
}

alias main = oss-clean-deprecated-statics
