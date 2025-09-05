use std assert
use std/testing *
use ../utils/common.nu [compare-ver]

@test
def 'compare-ver basic version comparison' [] {
  assert equal (compare-ver "1.2.3" "1.2.0") 1
  assert equal (compare-ver "2.0.0" "2.0.0") 0
  assert equal (compare-ver "1.9.9" "2.0.0") (-1)
}

@test
def 'compare-ver pre-release comparison' [] {
  assert equal (compare-ver "1.2.3-beta" "1.2.3") (-1)
  assert equal (compare-ver "1.2.3" "1.2.3-beta") 1
  assert equal (compare-ver "1.2.3-alpha" "1.2.3-beta") (-1)
}

@test
def 'compare-ver numeric pre-release comparison' [] {
  assert equal (compare-ver "1.2.3-alpha.1" "1.2.3-alpha.2") (-1)
  assert equal (compare-ver "1.2.3-alpha.1" "1.2.3-alpha.beta") (-1)
}

@test
def 'compare-ver build metadata handling' [] {
  # Build metadata should be ignored
  assert equal (compare-ver "1.2.3+build1" "1.2.3+build2") 0
  assert equal (compare-ver "1.2.3-alpha+build1" "1.2.3-alpha+build2") 0
}

@test
def 'compare-ver v prefix handling' [] {
  assert equal (compare-ver "v1.2.3" "1.2.4") (-1)
}
