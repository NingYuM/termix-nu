#!/usr/bin/env nu

const BENCH_RESULTS = [
  { module: 'agent-mobile',   time: 36.411sec, mem: 3967701.33KB, desc: 'Vite7 Erda' },
  { module: 'agent',          time: 77.767sec, mem: 4144845.33KB, desc: 'Vite7 Erda' },
  { module: 'agent-mobile',   time: 14.255sec, mem: 2567229.33KB, desc: 'Vite8 Erda' },
  { module: 'agent',          time: 52.521sec, mem: 2619102.67KB, desc: 'Vite8 Erda' },
  { module: 'base-mobile',    time: 20.606sec, mem: 2116553.00KB, desc: 'Vite7 Erda' },
  { module: 'base',           time: 51.646sec, mem: 4121074.67KB, desc: 'Vite7 Erda' },
  { module: 'base-mobile',    time: 3.747sec,  mem: 1013766.67KB, desc: 'Vite8 Erda' },
  { module: 'base',           time: 22.839sec, mem: 2460664.00KB, desc: 'Vite8 Erda' },
  { module: 'charts-mobile',  time: 40.388sec, mem: 3843428.00KB, desc: 'Vite7 Erda' },
  { module: 'charts',         time: 46.330sec, mem: 4028472.00KB, desc: 'Vite7 Erda' },
  { module: 'charts-mobile',  time: 16.642sec, mem: 2749942.67KB, desc: 'Vite8 Erda' },
  { module: 'charts',         time: 13.156sec, mem: 2435352.00KB, desc: 'Vite8 Erda' },
  { module: 'service',        time: 73.457sec, mem: 5193624.00KB, desc: 'Vite7 Erda' },
  { module: 'service',        time: 32.316sec, mem: 4427730.67KB, desc: 'Vite8 Erda' },
  { module: 'service-mobile', time: 19.568sec, mem: 2121902.67KB, desc: 'Vite7 Erda' },
  { module: 'service-mobile', time: 4.365sec,  mem: 1086797.33KB, desc: 'Vite8 Erda' },
  { module: 'terp',           time: 84.897sec, mem: 6048318.67KB, desc: 'Vite7 Erda' },
  { module: 'terp',           time: 37.206sec, mem: 4427468.00KB, desc: 'Vite8 Erda' },
  { module: 'terp-mobile',    time: 13.785sec, mem: 1478697.33KB, desc: 'Vite7 Erda' },
  { module: 'terp-mobile',    time: 2.958sec,  mem: 847340.00KB,  desc: 'Vite8 Erda' },
]

# Calc benchmark summary
def main [] {
  $BENCH_RESULTS
    | group-by module
    | transpose module rows
    | each {|row|
      let m = $row.module
      let items = $row.rows

      let v7 = ($items | where desc =~ 'Vite7' | first)
      let v8 = ($items | where desc =~ 'Vite8' | first)

      let t7 = $v7.time
      let t8 = $v8.time
      let m7 = $v7.mem
      let m8 = $v8.mem

      # 构建速度倍数：Vite8 相比 Vite7 的速度 = t7 / t8
      let speed_ratio = ($t7 / $t8 | into float)
      let mem_improve = ($m7 - $m8) / $m7 * 100 | into float

      {
        module: $m,
        vite7_time: ($t7 | format duration sec),
        vite8_time: ($t8 | format duration sec),
        speed_ratio_vs_v7: $speed_ratio,
        vite7_mem: $m7,
        vite8_mem: $m8,
        mem_improve_percent: $mem_improve
      }
    }
    | sort-by module
    | table -t light
}
