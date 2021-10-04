# Concatenate files performance test.
# Run by nu run/merge-perf.nu

$'Performance of merge two files in cat of bash:(char nl)'
hyperfine -m 20 'cat ./git/git-batch-exec.nu ./utils/compose-cmd.nu > run/.git-batch-exec-compose.nu'
char nl
^ls -la run
$'-----------------------------------------------------------'

$'Performance of merge two files in open and save of nu:(char nl)'
hyperfine -m 20 'nu run/merge.nu'
^ls -la run
