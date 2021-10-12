# Author: hustcer
# Created: 2021/10/10 07:36:56
# Usage:
#   use source command to load it

let __env = ($nu.env | pivot key value)

# Get the specified env key's value or ''
def 'get-env' [
  key: string     # The key to get it's env value
  default?: string # The default value for an empty env
] {
  let val = ($__env | match key $key | get value)
  if ($val | empty?) { $default } { $val }
}

# Check if a CLI App was installed, if true get the installed version, otherwise return 'N/A'
def 'get-ver' [
  app: string     # The CLI App to check
  verCmd: string  # The Nushell command to get it's version number
] {
  let installed = ((which $app | length) > 0)
  echo (if $installed { nu -c $verCmd }  { 'N/A' })
}

# Check if a git repo has the specified ref: could be a branch or tag, etc.
def 'has-ref' [
  ref: string   # The git ref to check
] {
  let parse = (git rev-parse --verify -q $ref)
  if ($parse | empty?) { $false } { $true }
}
