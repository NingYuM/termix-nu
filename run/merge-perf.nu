# Concatenate files performance test.
# Run by nu run/merge-perf.nu
#
# Benchmark #1: cat ./git/git-batch-exec.nu ./utils/compose-cmd.nu > run/.git-batch-exec-compose.nu
#   Time (mean ± σ):       2.5 ms ±   0.5 ms    [User: 0.7 ms, System: 1.5 ms]
#   Range (min … max):     1.9 ms …   7.4 ms    454 runs#
#
# Benchmark #2: nu run/merge.nu
#   Time (mean ± σ):      77.7 ms ±   8.5 ms    [User: 79.6 ms, System: 49.4 ms]
#   Range (min … max):    69.9 ms … 123.0 ms    36 runs
#
# Benchmark #3: bat ./git/git-batch-exec.nu ./utils/compose-cmd.nu > run/.git-batch-exec-compose.nu
#   Time (mean ± σ):      71.8 ms ±   0.6 ms    [User: 61.1 ms, System: 8.2 ms]
#   Range (min … max):    70.7 ms …  73.2 ms    38 runs
#

$'Performance of merge two files in cat of bash:(char nl)'
hyperfine -m 20 'cat ./git/git-batch-exec.nu ./utils/compose-cmd.nu > run/.git-batch-exec-compose.nu'
char nl
^ls -la run
$'-----------------------------------------------------------'

$'Performance of merge two files in open and save of nu:(char nl)'
hyperfine -m 20 'nu run/merge.nu'
^ls -la run
