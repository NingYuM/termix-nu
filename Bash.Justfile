# Useful commands for daily works
# Create: 2021/09/11 21:47:29
# Ref:
#   1. https://github.com/casey/just
#   2. https://www.nushell.sh/book/
#   3. https://github.com/dylanaraps/pure-bash-bible
#   4. https://github.com/Idnan/bash-guide
#   5. https://github.com/denysdovhan/bash-handbook
# Author: M.J.

#!/usr/bin/env just --justfile
# ^ A shebang isn't required, but allows a justfile to be executed
#   like a script, with `./justfile test`, for example.

set shell := ["nu", "-c"]

# The export setting causes all just variables
# to be exported as environment variables.
set export

# If positional-arguments is true, recipe arguments will be
# passed as positional arguments to commands. For linewise
# recipes, argument $0 will be the name of the recipe.
set positional-arguments

# Use `just --evaluate` to show env vars
CURRENT_TAG := 'v2.2.x'
# CURRENT_TAG := 'v2.2.0.9'
PREV_MALL_TAG := 'v2.2.0.9-2021.09.10'
JUST_FILE := justfile()
JUST_DIR := justfile_directory()
INVOCATION_DIRECTORY := invocation_directory()
TERMIX_DIR := '/Users/hustcer/github/terminus/termix-nu'

# Spaces around ':=' here are allowed
export HEAD_ENV_VAR := '1'

# Just commands aliases
# alias ag := git-age

# To pass arguments to a dependency, put the dependency
# in parentheses along with the arguments, just like:
# default: (sh-cmd "main")
# List available commands by default
default:
  @just --list --list-prefix '··· '

# Listing the branches of a git repo and the day of the last commit
git-age:
  @let-env JUST_INVOKE_DIR = {{invocation_directory()}}; \
    nu "$TERMIX_DIR/git/age.nu";

# Use arg1=('xyz') to set default $1
# Set default ENV_MALL_TAG here, can not shadow previous defined
# Bash command test
sh-cmd arg1=('xyz') ENV_MALL_TAG='v0.0.0.0.0.1':
  #!/usr/bin/env bash

  # set -e makes bash exit if a command fails.
  # set -u makes bash exit if a variable is undefined.
  # set -x makes bash print each script line before it’s run.
  # set -o pipefail makes bash exit if a command in a pipeline fails.
  set -euo pipefail
  # Argument $0 will be the name of the recipe.
  echo '{{'I {{LOVE}} curly braces!'}}'
  echo "Current Arg #0: $0"
  echo "Current Arg #1: $1"
  echo "Current Arg1: $arg1"
  echo "{{uppercase(`git --version`)}}"
  echo "{{replace(`git --version`, 'git', 'git:')}}"
  # No spaces around '=' are allowed, works here and in 'sh-cmd.sh' too
  export CMD_ENV_VAR='Yes'
  # Assignment works here but not work in 'sh-cmd.sh'
  CMD_ENV_ASSIGNMENT='Assign'
  # To override CURRENT_TAG use `t CURRENT_TAG=v0.0.1.x sh-cmd abc`
  # or use `t --set CURRENT_TAG v0.0.1.x sh-cmd abc`
  echo "Current Tag: $CURRENT_TAG"
  CURRENT_PROJECT=`basename "$INVOCATION_DIRECTORY"`
  # CURRENT_PROJECT still not work in the following if expression
  IN_MOBILE={{ if `basename "$INVOCATION_DIRECTORY"` == 'gaia-mobile' { 'Y' } else { 'N' } }}
  echo "IN_MOBILE: $IN_MOBILE"
  echo "CURRENT_PROJECT: $CURRENT_PROJECT"
  echo "Env Mall Tag: $ENV_MALL_TAG"
  echo "PREV_MALL_TAG: $PREV_MALL_TAG"
  echo "CMD_ENV_VAR: $CMD_ENV_VAR"
  echo "HEAD_ENV_VAR: $HEAD_ENV_VAR"
  echo "CMD_ENV_ASSIGNMENT: $CMD_ENV_ASSIGNMENT"
  echo "Current Tag env: {{env_var_or_default('CURRENT_TAG', 'v2.x')}}"
  echo "JUST_DIR: $JUST_DIR"
  echo "JUST_FILE: $JUST_FILE"
  echo "Justfile: {{justfile()}}"
  echo "Justfile Directory: {{justfile_directory()}}"
  echo "INVOCATION_DIRECTORY: $INVOCATION_DIRECTORY"
  sh "$TERMIX_DIR/sh-cmd.sh"
