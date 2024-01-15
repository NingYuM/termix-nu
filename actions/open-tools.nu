# Upgrade the latest release of a tool from the OSS storage
#
# This command will
# - get the metadata of the latest tool release from the OSS storage
# - filter the assets that match the search pattern `target`
# - fuzzy-ask one of them or use the single match
# - download the archive
# - extract the archive and replace the old binary

use ../utils/common.nu [ECODE, is-installed, hr-line]

const TOOL_PREFIX = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools'

export def upgrade-latest-tool [
  name: string,         # The name of the tool, e.g. `nushell`
  target: string = ''   # The target architecture, matches all of them by default
  --list(-l),           # List all the available binary packages
  --interactive(-i),    # Ask the user to choose the target architecture
]: nothing -> nothing {

  const BIN_MAP = {
    just: 'just',
    nushell: 'nu',
  }

  mut target = $target
  let latest = http get $'($TOOL_PREFIX)/($name)/latest.json'

  if $list {
    print 'Available packages:'; hr-line
    $latest.assets | get name | print; exit $ECODE.SUCCESS
  }

  if ($target | is-empty) and (not $interactive) {
    $target = $'($nu.os-info.arch)-((sys).host.name | str downcase)'
  }
  let matches = $latest.assets | get name | where $it =~ $target

  let arch = match ($matches | length) {
    0 => {
      let span = metadata $target | get span
      error make {
        msg: $'(ansi red_bold)No_Match_Found(ansi reset)'
        label: {
          span: $span
          text: $'No architecture matching this in the remote OSS storage'
        }
      }
    },
    1 => { $matches.0 },
    _ => {
      let choice = $matches | input list --fuzzy $'Please (ansi cyan)choose one architecture(ansi reset):'
      if ($choice | is-empty) {
        print 'User chose to exit, bye...'
        return
      }

      $choice
    },
  }

  let target = $latest.assets | where name =~ $arch
  if ($target | length) != 1 {
    error make --unspanned {
      msg: (
          $"(ansi red_bold)unexpected_internal_error(ansi reset):\n"
        + $"expected one match, found ($target | length)\n"
        + $"matches: ($target.name)"
      )
    }
  }
  let target = $target | first
  let bin = $BIN_MAP | get $name

  let destDir = (which $bin).path | path dirname | path join 'latest'
  if not ($destDir | path exists) { mkdir $destDir }

  if (is-installed aria2c) {
    aria2c $'($TOOL_PREFIX)/($name)/($target.name)' --dir $destDir --out $target.name
  } else {
    http get $'($TOOL_PREFIX)/($name)/($target.name)' | save --progress --force $'($destDir)/($target.name)'
  }

  print $"Latest ($name) of version: ($latest.version) saved as `(ansi default_dimmed)($target.name)(ansi reset)`\n"
  # print $'Contents of ($destDir)'; hr-line
  # print (ls $destDir)

  let extension = if ($target.name ends-with '.tar.gz') { 'tar.gz' } else { 'zip' }

  match $extension {
    'tar.gz' => {
      cd $destDir
      tar xf $'($bin)-*.tar.gz' --directory $destDir
      rm $'($bin)-*.tar*gz'; cd ..
      # `sudo` is required to move the files to `/usr/local/bin` on macOS
      glob $'($destDir)/**/($bin)*' | each {|it| if ($it | path type) == 'file' { sudo cp $it . } }
      rm -rf $destDir
      let version = nu -c $'./($bin) --version'
      print $'(char nl)Update to ($name): (ansi g)($version)(ansi reset)'
      if $name == 'nushell' {
        print $'Please restart Nu session to use the latest release...'
      }
    },
    'zip' => {
      print $'Try to unpack the archive...'
      cd $destDir
      tar xf $'($bin)-*.zip'
      rm $'($bin)-*.zip'; cd ..
      if $name == 'nushell' {
        cp $'($destDir)/nu_plugin_*' .
        print 'Nushell plugins have been updated successfully'
        cp $'($destDir)/($bin).exe' $'($bin)-latest.exe'
        print $'(ansi r)Please replace ($bin).exe with ($bin)-latest.exe manually in ($destDir | path dirname) directory(ansi reset)'
        rm -rf $destDir
        return
      }
      cp $'($destDir)/($bin).exe' $'($bin).exe'
      rm -rf $destDir
      let version = nu -c $'./($bin).exe --version'
      print $'(char nl)Update to ($name): (ansi g)($version)(ansi reset)'
      print $'($name) has been updated successfully'
    },
    _ => {
      print $"Unknown extension ($extension), you'll have to figure out how to extract this archive ;)"
    },
  }
}
