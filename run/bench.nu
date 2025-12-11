#!/usr/bin/env nu

const DEFAULT_COMMAND = 'pnpm build:pc > /dev/null 2>&1'

# Benchmark the build performance of a module
def main [
  name: string,                         # The name of the module being benchmarked
  command?: string = $DEFAULT_COMMAND,  # The build command to execute
] {
  if $nu.os-info.name == 'macos' {
    print $'(ansi g)Running benchmark on macOS...(ansi rst)'
  } else {
    print $'(ansi g)Current OS: ($nu.os-info.name)(ansi rst)'
    # 清理所有 sources.list.d 下的官方源配置
    rm -rf /etc/apt/sources.list.d/*
    if not ('/usr/bin/gtime' | path exists) {
      apt-get update; apt-get install time hyperfine -y --no-install-recommends
      ln -s /usr/bin/time /usr/bin/gtime
    }
    print $'(ansi g)Running benchmark on Linux...(ansi rst)'
  }
  print $'(ansi p)(char nl)=========Building Module ($name)================(ansi rst)(char nl)'
  print $'Current vite version: (ansi g)(pnpm vite --version)(ansi rst)'
  print $'CPU cores: (ansi g)(sys cpu | length)(ansi rst)'
  print $'(ansi p)(char nl)----------------GTime Result----------------(ansi rst)(char nl)'
  print $'Round 1:'
  gtime -v sh -c $"($command)"; sleep 3sec
  print $'Round 2:'
  gtime -v sh -c $"($command)"; sleep 3sec
  print $'Round 3:'
  gtime -v sh -c $"($command)"; sleep 5sec
  print $'(ansi p)(char nl)----------------Hyperfine Result----------------(ansi rst)(char nl)'
  hyperfine -r 3 --show-output $"gtime -f 'Peak RAM: %M KB' sh -c '($command)' 2>&1"
}
