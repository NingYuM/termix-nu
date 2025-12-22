
const OSS_PREFIX = 'oss://terminus-new-trantor/fe-resources'

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
  let mount = match ($mountpoint =~ '/$') { true => $mountpoint, false => $'($mountpoint)/' }
  ossutil du ($OSS_PREFIX)/($mount)
    | complete | get stdout | lines | where {|it| $it =~ '^total du size'}
    | first | split row  : | last
    | into filesize
}

# oss-stat --> Output: table with size of each iteration and total
export def oss-stat [limit: int = 3] {
  let time = date now
  $env.config.table.mode = 'psql'
  let stats = $ITERATIONS | first $limit | par-each -k {|it|
    { iteration: $it, size: (oss-du $it) }
  }
  let total = $stats | get size | math sum
  # Print the table
  print ($stats | table)
  print $"(ansi g)Total: ($total)(ansi rst)"
  let endTime = date now
  print $"(ansi g)Time: ($endTime - $time)(ansi rst)"
}

alias main = oss-stat
