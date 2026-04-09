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

use open-tools.nu [upgrade-latest-tool]
use setup.nu [setup-termix, upgrade-termix-nu]
use ../run/post-setup.nu [install-local-skills]

use ../utils/common.nu [ECODE, hr-line, is-installed, get-dot-conf]

const VALID_TOOLS = ['just', 'nu', 'nushell', 'fzf', 's5cmd', 'termix-nu']

def sync-installed-skills [] {
  if 'TERMIX_DIR' not-in $env {
    print $'Skip skill installation because (ansi y)TERMIX_DIR(ansi rst) is not set'
    return
  }

  install-local-skills $env.TERMIX_DIR
}

# Upgrade termix-nu, just or nushell
export def upgrade-tool [
  tool?: string = 'termix-nu',    # The tool to upgrade, currently support just, nushell or nu and termix-nu
  --all(-a),                      # Upgrade all tools: termix-nu, just and nushell
  --force(-f),                    # Force upgrade, even if the latest version is already installed
] {
  let tool = $tool | str trim | str downcase

  # If installed by setup.nu then upgrade by the same way
  if (get-dot-conf installMethod) == 'setup' {
    if $all {
      setup-termix --all --force=$force --in-place-update
      sync-installed-skills
    } else if $tool == 'termix-nu' {
      upgrade-termix-nu
      sync-installed-skills
    } else {
      let setupTool = if $tool in ['nu', 'nushell'] { 'nu' } else { $tool }
      setup-termix $setupTool --force=$force --in-place-update
    }
    exit $ECODE.SUCCESS
  }
  if $all {
    upgrade-termix-nu
    sync-installed-skills
    upgrade-latest-tool just --no-aria2c --force=$force
    upgrade-latest-tool nushell --no-aria2c --force=$force --post-install { rm $nu.plugin-path }
    if (is-installed fzf) {
      upgrade-latest-tool fzf --no-aria2c --force=$force
    }
    upgrade-latest-tool s5cmd --no-aria2c --force=$force
    exit $ECODE.SUCCESS
  }

  if $tool not-in $VALID_TOOLS {
    print -e $'Unsupported tool upgrading, currently supported: (ansi p)($VALID_TOOLS | str join ,)(ansi rst)'
    exit $ECODE.INVALID_PARAMETER
  }
  if $tool == 'termix-nu' {
    upgrade-termix-nu
    sync-installed-skills
    exit $ECODE.SUCCESS
  }
  let tool = if $tool in ['nu', 'nushell'] { 'nushell' } else { $tool }
  if $tool == 'nushell' {
    upgrade-latest-tool $tool --no-aria2c --force=$force --post-install { rm $nu.plugin-path }
  } else {
    upgrade-latest-tool $tool --no-aria2c --force=$force
  }
}
