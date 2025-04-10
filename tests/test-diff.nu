use std assert
use ../actions/code-review.nu [is-safe-git, generate-include-args, generate-exclude-args]

# Get the unicode width of the input string
def get-uw [] { $in | str stats | get unicode-width }

#[test]
def 'is-safe-git should work as expected' [] {
  assert equal (is-safe-git 'git diff') true
  assert equal (is-safe-git 'git show') true
  assert equal (is-safe-git 'git log') false
  assert equal (is-safe-git 'git checkout') false
  assert equal (is-safe-git 'git show 0dd0eb5') true
  assert equal (is-safe-git 'git show HEAD') true
  assert equal (is-safe-git 'git show head~1') true
  assert equal (is-safe-git 'git diff HEAD~2') true
  assert equal (is-safe-git 'git diff head~3 main') true
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5') true
  assert equal (is-safe-git 'git show 2393375 | less') false
  assert equal (is-safe-git 'git show 2393375>diff.patch') false
  assert equal (is-safe-git 'git show 2393375 o+e>diff.patch') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 nu/*') true
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*') true
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm -rf abc') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* && rm -rf abc') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* || rm -rf abc') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm ./*') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm -f ./*') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm -rf ./*') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* > out.txt') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* >> out.txt') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* < in.txt') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* << in.txt') false
  assert equal (is-safe-git 'git show head:utils/common.nu') true
  assert equal (is-safe-git 'git show HEAD:utils/common.nu') true
}

#[test]
def 'generate-include-arg should work as expected' [] {
  assert equal (git diff d370863 631b71f --name-only ...(generate-include-args run/,dotfiles/,Dockerfile) | lines | length) 5
  assert equal (git diff d370863 631b71f --name-only ...(generate-include-args run/,dotfiles/,Dockerfile,*.nu) | lines | length) 7
  assert equal (git diff d370863 631b71f ...(generate-include-args run/,Dockerfile) | get-uw) 2529
  assert equal (git diff d370863 631b71f ...(generate-include-args run/*,Dockerfile) | get-uw) 2529
  assert equal (git diff d370863 631b71f ...(generate-include-args *.nu,Dockerfile) | get-uw) 11023
}

#[test]
def 'generate-exclude-arg should work as expected' [] {
  assert equal (git diff d370863 631b71f --name-only ...(generate-exclude-args run/,dotfiles/,Dockerfile) | lines | length) 9
  assert equal (git diff d370863 631b71f --name-only ...(generate-exclude-args run/,dotfiles/,Dockerfile,*.nu) | lines | length) 7
  assert equal (git diff d370863 631b71f ...(generate-exclude-args run/,Dockerfile) | get-uw) 20280
  assert equal (git diff d370863 631b71f ...(generate-exclude-args run/*,Dockerfile) | get-uw) 20280
  assert equal (git diff d370863 631b71f ...(generate-exclude-args *.nu,Dockerfile) | get-uw) 11786
}

#[test]
def 'generate-exclude-arg and generate-include-arg should work as expected' [] {
  assert equal (git diff d370863 631b71f ...(generate-include-args run/,Dockerfile) ...(generate-exclude-args run/,Dockerfile) | get-uw) 0
  assert equal (git diff d370863 631b71f ...(generate-include-args Dockerfile) ...(generate-exclude-args run/,Dockerfile) | get-uw) 0
  assert equal (git diff d370863 631b71f ...(generate-include-args Dockerfile) ...(generate-exclude-args run/) | get-uw) 2186
}

#[test]
def 'generate-exclude-arg and generate-include-arg should work with git show' [] {
  assert equal (git show 371b75c ...(generate-include-args actions/) ...(generate-exclude-args utils/) | get-uw) 2283
  assert equal (git show 371b75c ...(generate-include-args actions/) ...(generate-exclude-args actions/) | get-uw) 0
  assert equal (git show 371b75c ...(generate-include-args utils/) | get-uw) 992
  assert equal (git show 371b75c ...(generate-exclude-args utils/) | get-uw) 2283
}
