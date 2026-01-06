# pull down the latest nightly build of Nushell
#
# this command will
# - get the metadata of the latest build of Nushell in the nightly repo
# - filter the assets that match the search pattern `target`
# - fuzzy-ask one of them or use the single match
# - download the archive
# - give some hints about the version and the hash and how to extract the archive

use ../utils/common.nu [ECODE, is-installed, hr-line, can-write, linux?]

export def get-latest-nightly-build [
  --list(-l),           # list all the available binary packages
  --interactive(-i),    # ask the user to choose the target architecture
  --tag(-t): string,    # the tag name of the release, e.g. '0.109.2-nightly.31+99c5c5f'
  target: string = ''   # the target architecture, matches all of them by default
]: nothing -> nothing {

  mut target = $target
  let headers = if ($env.GITHUB_TOKEN? | is-empty) { [] } else { [Authorization $'Bearer ($env.GITHUB_TOKEN)'] }
  let latest = http get -H $headers https://api.github.com/repos/nushell/nightly/releases
  let latest = if ($tag | is-empty) { $latest } else {
      $latest | where { $in.tag_name | str contains $tag }
    } | sort-by published_at --reverse | first

  if ($latest | is-empty) {
    error make --unspanned { msg: $"(ansi r)No release found matching tag `($tag)`(ansi rst)" }
  }

  if $list {
    print 'Available packages:'; hr-line
    $latest.assets | get name | where $it !~ 'msi' | print; exit $ECODE.SUCCESS
  }

  if ($target | is-empty) and (not $interactive) {
    let platform = if (linux?) { 'linux' } else { (sys host | get name | str downcase) }
    const PLATFORM_MAP = {
      windows: 'pc-windows',
      darwin: 'apple-darwin',
      linux: 'unknown-linux',
    }
    $target = $'($nu.os-info.arch)-($PLATFORM_MAP | get $platform)'
  }
  let matches = $latest.assets
      | get name
      | where $it !~ 'msi'
      | where $it =~ $target

  let arch = match ($matches | length) {
    0 => {
      let span = metadata $target | get span
      error make {
        msg: $'(ansi red_bold)No_Match_Found(ansi rst)'
        label: {
          span: $span
          text: $'No architecture matching this in ($latest.html_url)'
        }
      }
    },
    1 => { $matches.0 },
    _ => {
      let choice = $matches | input list --fuzzy $'Please (ansi cyan)choose one architecture(ansi rst):'
      if ($choice | is-empty) {
        print 'User chose to exit, bye...'
        return
      }

      $choice
    },
  }

  let target = $latest.assets | where name !~ 'msi' | where name =~ $arch
  if ($target | length) != 1 {
    error make --unspanned {
      msg: (
          $"(ansi red_bold)unexpected_internal_error(ansi rst):\n"
        + $"expected one match, found ($target | length)\n"
        + $"matches: ($target.name)"
      )
    }
  }
  let target = $target | first

  let build = $target.name
      | wrap name
      | insert hash { $latest.tag_name | parse '{version}-nightly.{build}+{hash}' | get 0?.hash? | default 'unknown' }
      | insert version { $latest.tag_name | parse '{version}-nightly.{build}+{hash}' | get 0?.version? | default 'unknown' }
      | insert extension { $target.name | path parse | get extension }

  let destDir = mktemp -d | path join 'nu-nightly'
  if not ($destDir | path exists) { mkdir $destDir }

  if (is-installed aria2c) {
    aria2c $target.browser_download_url --dir $destDir --out $target.name
  } else {
    http get $target.browser_download_url | save --progress --force $'($destDir)/($target.name)'
  }

  print $"Latest nightly build \(version: ($build.version), hash: ($build.hash)\) saved as `(ansi default_dimmed)($target.name)(ansi rst)`\n"
  print (ls $destDir)

  match $build.extension {
    'gz' => {
      cd $destDir
      tar xvf nu-*.tar.gz
      rm nu-*.tar*gz; cd ..
      let binDir = $nu.current-exe | path dirname
      print $'Nu will be installed to (ansi g)($binDir)(ansi rst)'
      # `sudo` is required to move the files to `/usr/local/bin` on macOS
      if (can-write $binDir) {
        mv nu-nightly/nu-*/nu* $binDir
      } else {
        # Use mv instead of cp to avoid 'terminated by signal SIGKILL (Forced quit)' error
        sudo mv nu-nightly/nu-*/nu* $binDir
      }
      rm -rf $destDir; cd $binDir
      print $'(char nl)Update to Nu: (ansi g)(./nu --version) - (./nu -n --no-std-lib -c "version | get commit_hash")(ansi rst)'
      print $'Please restart Nu session to use the latest nightly release...'
    },
    'zip' => {
      print $'Try to unpack the archive...'
      cd $destDir
      tar xvf nu-*.zip
      rm nu-*.zip; cd ..
      let binDir = $nu.current-exe | path dirname
      mv nu-nightly/nu_plugin_* $binDir
      mv nu-nightly/nu.exe $'($binDir)/nu-nightly.exe'
      rm -rf $destDir
      print $'(char nl)Please replace (ansi g)nu.exe(ansi rst) with (ansi g)nu-nightly.exe(ansi rst) manually and restart Nu session:'
      print $'(ansi g)mv -force ($binDir)/nu-nightly.exe ($binDir)/nu.exe(ansi rst)'
    },
    _ => {
      print -e $"Unknown extension ($build.extension), you'll have to figure out how to extract this archive ;)"
    },
  }
}
