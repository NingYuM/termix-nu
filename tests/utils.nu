# Common test runner utilities for unit tests

# Run a single test and return the result
export def run_test [test: record<name: string, execute: closure>]: nothing -> record<name: string, result: string, error: string> {
  try {
    do ($test.execute)
    { result: 'PASS', name: $test.name, error: '' }
  } catch { |error|
    { result: 'FAIL', name: $test.name, error: $'($error.msg)' }
  }
}

# Print test results table
export def print_results [results: list<record<name: string, result: string>>] {
  let display_table = $results | update result { |row|
    let emoji = if ($row.result == 'PASS') { $'(ansi g)√(ansi rst)' } else { $'(ansi r)×(ansi rst)' }
    $'($emoji) ($row.result)'
  }

  if ('GITHUB_ACTIONS' in $env) {
    print ($display_table | to md --pretty)
  } else {
    print $display_table
  }

  let failed = $results | where result == 'FAIL'
  for test in $failed {
    print $"\n($test.name): ($test.error)"
  }
}

# Print test summary and return success status
export def print_summary [results: list<record<name: string, result: string>>] {
  let success = $results | where ($it.result == 'PASS') | length
  let failure = $results | where ($it.result == 'FAIL') | length
  let count = $results | length

  if ($failure == 0) {
    print $"\n(ansi g)Testing completed: ($success) of ($count) were successful(ansi reset)\n"
  } else {
    print $"\n(ansi r)Testing completed: ($failure) of ($count) failed(ansi reset)\n"
  }
}

# Run all tests and exit with appropriate code
export def run_tests [file: string, tests: list<record<name: string, execute: closure>>] {
  $env.config.table.mode = 'psql'
  print $'-----------------------------------------------------------------------------------'
  let display_file = if ('TERMIX_DIR' in $env) { $file | path relative-to $env.TERMIX_DIR } else { $file }
  print $'  (ansi g)Running tests of ($display_file) ...(ansi rst)'
  print $'-----------------------------------------------------------------------------------'

  let results = $tests | each { |test| run_test $test }

  print -n (char nl)
  print_results $results
  print_summary $results

  if ($results | any { |test| $test.result == 'FAIL' }) {
    exit 1
  }
}
