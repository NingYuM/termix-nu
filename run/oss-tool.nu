
use ../utils/common.nu [FZF_DEFAULT_OPTS, FZF_THEME]

const EXTRA_KEEP = [versions.json latest.json]
const OSS_PREFIX = 'oss://terminus-new-trantor/fe-resources'
const OSS_HTTP_PREFIX = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources'

const ITERATIONS = [
  2.5.23.1228
  2.5.24.0130
  2.5.24.0228
  2.5.24.0330
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
  dev
  test
  staging
  terp-dev
  terp-test
  terp-prod
  terp-staging
]

# oss-du 2.5.23.1228 --> Output: 3.0 GB
export def oss-du [
  mountpoint: string,  # OSS path to calculate disk usage for
] {
  let mount = $mountpoint | str trim -c / | ($in)/
  ossutil du ($OSS_PREFIX)/($mount)
    | complete | get stdout | lines | where {|it| $it =~ '^total du size'}
    | first | split row ':' | last
    | into filesize
}

# oss-stat --> Output: table with size of each iteration and total
export def oss-stat [
  limit: int = 3,  # Number of recent iterations to stat
] {
  let time = date now
  $env.config.table.mode = 'psql'
  let stats = $ITERATIONS | last $limit | par-each -k {|it|
    { mountpoint: $it, size: (oss-du $it) }
  }
  let total = $stats | get size | math sum
  # Print the table
  print ($stats | table)
  print $"(ansi g)Total: ($total)(ansi rst)"
  let endTime = date now
  print $"(ansi g)Time: ($endTime - $time)(ansi rst)"
}

# 删除 OSS 上过期的静态资源，只保留最近一个版本
export def oss-clean-deprecated-statics [
  mountpoint: string = 'ttt0',  # OSS mount point: dev, terp-test, 2.5.24.0330, etc. Default is ttt0
  --interactive(-i),            # Interactive mode: select mountpoints via fzf
] {
  $env.config.table.mode = 'psql'
  let start = date now

  # Get mountpoints to clean
  let mountpoints = if $interactive { select-mountpoints } else { [$mountpoint] }
  if ($mountpoints | is-empty) {
    print $'(ansi grey66)No mountpoint selected, Bye...(ansi rst)'
    return
  }

  # Collect cleanup info for all mountpoints
  let cleanup_infos = $mountpoints | each {|mp| get-mountpoint-clean-info $mp } | compact
  if ($cleanup_infos | is-empty) {
    print $'(ansi grey66)No objects to clean, Bye...(ansi rst)'
    return
  }

  # Display summary and confirm
  print $'(char nl)(ansi gb)=== Cleanup Summary ===(ansi rst)(char nl)'
  for info in $cleanup_infos {
    print $'Mountpoint: (ansi g)($info.mountpoint)(ansi rst)'
    print $'  Current size: (ansi y)($info.size)(ansi rst)'
    print $'  Objects to remove: (ansi r)($info.remove_candidates | length)(ansi rst)'
    print ($info.remove_candidates | table)
    print ''
  }

  let total_objects = $cleanup_infos | get remove_candidates | flatten | length
  let confirm = input $'(ansi y)Remove ($total_objects) objects from ($cleanup_infos | length) mountpoints? [y/N] (ansi rst)'
  if ($confirm | str downcase) != 'y' {
    print $'(ansi grey66)Aborted by user, Bye...(ansi rst)'
    return
  }

  # Execute cleanup for each mountpoint
  for info in $cleanup_infos {
    clean-mountpoint-objects $info.mountpoint $info.remove_candidates
  }

  print $"(ansi g)Total time: ((date now) - $start)(ansi rst)"
}

# Get cleanup info for a single mountpoint
def get-mountpoint-clean-info [
  mountpoint: string,  # OSS mount point to analyze
] {
  let mp = $mountpoint | str trim -c /
  let size = oss-du $mp

  let keep_modules = try {
    http get ($OSS_HTTP_PREFIX)/($mp)/latest.json | values | get dirname
  } catch {
    print $"(ansi r)Failed to fetch latest.json for ($mp), skipping...(ansi rst)"
    return null
  }

  let remove_candidates = get-remove-candidates $mp $keep_modules
  if ($remove_candidates | is-empty) {
    print $"(ansi grey66)No deprecated objects in ($mp), skipping...(ansi rst)"
    return null
  }

  {
    mountpoint: $mp,
    size: $size,
    keep_modules: $keep_modules,
    remove_candidates: $remove_candidates
  }
}

# Clean objects from a single mountpoint
def clean-mountpoint-objects [
  mountpoint: string,           # OSS mount point
  remove_candidates: list<any>, # List of objects to remove
] {
  print $'(char nl)Cleaning (ansi g)($mountpoint)(ansi rst)...'

  let results = $remove_candidates | par-each {|it|
    { path: $it, result: (ossutil rm -rf $it | complete) }
  }

  let failures = $results | where { $in.result.exit_code != 0 }
  let success_count = ($remove_candidates | length) - ($failures | length)

  if ($failures | length) > 0 {
    print $"(ansi r)Failed to remove ($failures | length) objects:(ansi rst)"
    print ($failures | get path)
  }

  print $'Cleaned (ansi g)($success_count)(ansi rst) objects from (ansi g)($mountpoint)(ansi rst)'
  print $'New size of (ansi g)($mountpoint)(ansi rst): (ansi g)(oss-du $mountpoint)(ansi rst)'
}

# Interactive mountpoint selection via fzf
def select-mountpoints [] {
  let input = $ITERATIONS | str join (char nl)
  let header = "Select mountpoint(s) to clean"

  print $'(ansi grey66)Shortcuts: TAB: Select, CTRL-A: Select All, CTRL-D: Deselect All, CTRL-T: Toggle All(ansi rst)(char nl)'

  # Run fzf for selection
  const FZF_KEY_BINDING = "--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all"
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($header)" ($FZF_THEME) ($FZF_KEY_BINDING)'

  let selected = try { $input | fzf -m --ansi | lines } catch {
    print -e $'(ansi r)Failed to run fzf. Please ensure fzf is installed.(ansi rst)'
    return []
  }

  if ($selected | is-empty) { return [] }

  $selected | each { str trim }
}

# Get direct children objects of a mountpoint
def get-direct-children [
  mountpoint: string,  # OSS mount point to list children from
] {
  let mount = $mountpoint | str trim -c / | ($in)/
  ossutil ls ($OSS_PREFIX)/($mount) -d | lines | where $it =~ '^oss://'
}

# Get remove candidates by mountpoint and keep modules
def get-remove-candidates [
  mountpoint: string,         # OSS mount point to scan
  keep_modules: list<string>, # List of module names to keep
] {
  let children = get-direct-children $mountpoint
  let keep = $keep_modules | append $EXTRA_KEEP
  $children | where {|it| ($it | str trim -c / | split row / | last) not-in $keep }
}

# Main entry point for OSS tools
@example '统计最近 3 个迭代版本的 OSS 存储使用量' {
  nu run/oss-tool.nu stat
}
@example '统计最近 5 个迭代版本的 OSS 存储使用量' {
  nu run/oss-tool.nu stat -l 5
}
@example '清理指定 mountpoint 的过期静态资源' {
  nu run/oss-tool.nu clean -m dev
} --result '显示待删除对象列表，确认后执行删除'
@example '交互式选择 mountpoint 进行清理' {
  nu run/oss-tool.nu clean -i
} --result '通过 fzf 多选 mountpoint，汇总显示后确认删除'
export def oss-tool [
  action: string@['stat', 'clean'],   # Action to perform: `stat`, `clean`
  --limit(-l): int = 3,               # Number of recent iterations to stat for `stat` action
  --mountpoint(-m): string = 'ttt0',  # OSS mount point for `clean` action: `dev`, `terp-test`, `2.5.25.0330`, etc.
  --interactive(-i),                  # Interactive mode for `clean` action
] {
  match $action {
    'stat' => { oss-stat $limit }
    'clean' => { oss-clean-deprecated-statics $mountpoint --interactive=$interactive }
    _ => { print $'(ansi r)Invalid action: ($action)(ansi rst)'; exit 1 }
  }
}

alias main = oss-tool
