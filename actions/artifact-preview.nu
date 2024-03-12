#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/03/12 19:39:56
#
# REF: https://github.com/junegunn/fzf
# Usage:
#   nu preview-artifact.nu 2.5.24.0130+20240311194733 $data

use ../utils/common.nu [hr-line]

export def preview-artifact [
  version: string,      # The version of the selected artifact
  metaPath: string,     # The metadata file path of the releases
] {
  print $'Version: ($version)'; hr-line
  $env.config.table.mode = 'psql'
  let releases = open $metaPath
  let selected = $releases.0.data.list | where version == $version | get 0
  mut meta = $selected | select version userId createdAt releaseId modes
  $meta.modes = (($meta.modes | from json | columns) | str join ', ')
  $meta.createdBy = ($releases.userInfo | get -i $meta.userId).nick?.0?
  $meta | select version createdBy createdAt releaseId modes | print; hr-line
  print $selected.changelog
}

alias main = preview-artifact
