#!/usr/bin/env nu

use ../utils/common.nu compare-ver

def check [test: string, expected: int, actual: int] {
  let status = if $actual == $expected { $"(ansi g)√(ansi rst) PASS" } else { $"(ansi r)X(ansi rst) FAIL" }
  if $actual == $expected {
    print $"($status) ($test): got (ansi g)($actual)(ansi rst), expected (ansi g)($expected)(ansi rst)"
  } else {
    print $"($status) ($test): got (ansi r)($actual)(ansi rst), expected (ansi g)($expected)(ansi rst)"
  }
}

print "=== Test compare-ver custom command ==="

# 基础版本比较
check "1.2.3 > 1.2.0" 1 (compare-ver "1.2.3" "1.2.0")
check "2.0.0 = 2.0.0" 0 (compare-ver "2.0.0" "2.0.0")
check "1.9.9 < 2.0.0" (-1) (compare-ver "1.9.9" "2.0.0")

# Pre-release 比较
check "1.2.3-beta < 1.2.3" (-1) (compare-ver "1.2.3-beta" "1.2.3")
check "1.2.3 > 1.2.3-beta" 1 (compare-ver "1.2.3" "1.2.3-beta")
check "1.2.3-alpha < 1.2.3-beta" (-1) (compare-ver "1.2.3-alpha" "1.2.3-beta")

# 数字 pre-release
check "1.2.3-alpha.1 < 1.2.3-alpha.2" (-1) (compare-ver "1.2.3-alpha.1" "1.2.3-alpha.2")
check "1.2.3-alpha.1 < 1.2.3-alpha.beta" (-1) (compare-ver "1.2.3-alpha.1" "1.2.3-alpha.beta")

# Build metadata (应该被忽略)
check "Build metadata ignored" 0 (compare-ver "1.2.3+build1" "1.2.3+build2")
check "Pre-release + build metadata ignored" 0 (compare-ver "1.2.3-alpha+build1" "1.2.3-alpha+build2")

# 边缘情况
# check "Empty pre-release < release" (-1) (compare-ver "1.2.3-" "1.2.3")
check "v prefix handling" (-1) (compare-ver "v1.2.3" "1.2.4")
