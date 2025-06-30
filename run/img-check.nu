
# Check bin versions of docker image
# Output example:
#   Nu: 0.105.1, Node: v20.19.2 LTS, npm: 10.8.2, pnpm: 9.15.9, Git: 2.39.5, fnm 1.38.1
#   GNU bash: 5.2.15, Wget 1.21.3, aria2: 1.36.0, curl: 7.88.1, ripgrep 13.0.0, sd 1.0.0
#   fd 10.2.0, just 1.40.0, ossutil v1.7.19, ast-grep(sg) 0.33.0
def main [] {
  let wget_ver = wget --version | lines | first | split row ' ' | get 2
  let curl_ver = curl --version | lines | first | split row ' ' | get 1
  let aria_ver = aria2c --version | lines | first | split row ' ' | get 2
  let bash_ver = bash --version | lines | first | split row ' ' | get 3 | split row '(' | first
  print $'Nu: (nu -v), Node: (node -v | str trim -c v), npm: (npm -v), pnpm: (pnpm -v), Git: (get-ver git), fnm: (get-ver fnm)'
  print $'Bash: ($bash_ver), Wget: ($wget_ver), aria2c: ($aria_ver), curl: ($curl_ver), rg: (get-ver rg), sd: (get-ver sd)'
  print $'fd: (get-ver fd), just: (get-ver just), ossutil: (get-ver ossutil), ast-grep/sg: (get-ver sg)'
}

def get-ver [bin: string] {
  if (which $bin | is-empty) { return 'N/A' }
  try { ^$bin --version | complete | get stdout | lines | first | split row ' ' | last } catch { 'N/A' }
}
