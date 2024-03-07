#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/01/16 19:06:52
# Description: Upgrade termix-nu, just and nushell
#   [√] Upgrade termix-nu
#   [√] Upgrade Nushell
#   [√] Upgrade just
#   [√] Upgrade all tools: termix-nu, just and nushell
# Usage:
#   t upgrade
#   t upgrade just
#   t upgrade nushell

use ../utils/common.nu [ECODE, hr-line]
use open-tools.nu [upgrade-latest-tool]

const VALID_TOOLS = ['just', 'nu', 'nushell', 'termix-nu']

# Upgrade termix-nu, just or nushell
export def upgrade-tool [
  tool?: string = 'termix-nu',    # The tool to upgrade, currently support just, nushell or nu and termix-nu
  --all(-a),                      # Upgrade all tools: termix-nu, just and nushell
  --force(-f),                    # Force upgrade, even if the latest version is already installed
] {
  if $all {
    upgrade-termix-nu
    upgrade-latest-tool just --no-aria2c --force=$force
    upgrade-latest-tool nushell --no-aria2c --force=$force --post-install { rm $nu.plugin-path }
    exit $ECODE.SUCCESS
  }

  let tool = $tool | str trim | str downcase
  if $tool not-in $VALID_TOOLS {
    print $'Unsupported tool upgrading, currently supported: (ansi p)($VALID_TOOLS | str join ,)(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  if $tool == 'termix-nu' {
    upgrade-termix-nu
    exit $ECODE.SUCCESS
  }
  let tool = if $tool == 'just' { $tool } else { 'nushell' }
  upgrade-latest-tool $tool --no-aria2c --force=$force
}

# Upgrade termix-nu script source repo
def upgrade-termix-nu [] {
  print $'Upgrading termix-nu...'; hr-line
  cd $env.TERMIX_DIR
  git checkout master
  git pull --tags
  git pull origin (git tag -l --sort=-v:refname | lines | select 0).0 --ff-only
}
