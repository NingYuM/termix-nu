# pull down the latest nightly build of Nushell
#
# this command will
# - get the metadata of the latest build of Nushell in the nightly repo
# - filter the assets that match the search pattern `target`
# - fuzzy-ask one of them or use the single match
# - download the archive
# - give some hints about the version and the hash and how to extract the archive

use ../utils/common.nu [is-installed, hr-line]

export def get-latest-nightly-build [
  --list(-l),           # list all the available binary packages
  --interactive(-i),    # ask the user to choose the target architecture
  target: string = ''   # the target architecture, matches all of them by default
]: nothing -> nothing {

  mut target = $target
  let latest = http get https://api.github.com/repos/nushell/nightly/releases
      | sort-by published_at --reverse
      | first

  if $list {
    print 'Available packages:'; hr-line
    $latest.assets | get name | where $it !~ 'msi' | print; exit 0
  }

  if ($target | is-empty) and (not $interactive) {
    $target = $'($nu.os-info.arch)-((sys).host.name | str downcase)'
  }
  let matches = $latest.assets
      | get name
      | where $it !~ 'msi'
      | where $it =~ $target
      | parse --regex 'nu-\d\.\d+\.\d-(?<arch>[a-zA-Z0-9-_]*)\..*'
      | get arch

  let arch = match ($matches | length) {
    0 => {
      let span = metadata $target | get span
      error make {
        msg: $'(ansi red_bold)No_Match_Found(ansi reset)'
        label: {
          start: $span.start
          end: $span.end
          text: $'No architecture matching this in ($latest.html_url)'
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

  let target = $latest.assets | where name !~ 'msi' | where name =~ $arch
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

  let build = $target.name
      | parse --regex 'nu-(?<version>\d\.\d+\.\d)-(?<arch>[a-zA-Z0-9-_]*)\.(?<extension>.*)'
      | first
      | insert hash { $latest.tag_name | parse 'nightly-{hash}' | get 0.hash }

  let destDir = (which nu).path | path dirname | path join 'nu-nightly'
  if not ($destDir | path exists) { mkdir $destDir }

  if (is-installed aria2c) {
    aria2c $target.browser_download_url --dir $destDir --out $target.name
  } else {
    http get $target.browser_download_url | save --progress --force $'($destDir)/($target.name)'
  }

  print $"Latest nightly build \(version: ($build.version), hash: ($build.hash)\) saved as `(ansi default_dimmed)($target.name)(ansi reset)`\n"
  print (ls $destDir)

  match $build.extension {
    'tar.gz' => {
      cd $destDir
      tar xvf nu-*.tar.gz --directory $destDir
      rm nu-*.tar*gz; cd ..
      # `sudo` is required to move the files to `/usr/local/bin` on macOS
      sudo cp -r nu-nightly/nu-*/* .
      rm -rf nu-nightly
      print $'(char nl)Update to Nu: (ansi g)(./nu --version) - (./nu -c "version | get commit_hash")(ansi reset)'
      print $'Please restart Nu session to use the latest nightly release...'
    },
    'zip' => {
      print $'Try to unpack the archive...'
      cd $destDir
      tar xvf nu-*.zip
      rm nu-*.zip; cd ..
      cp nu-nightly/nu_plugin_* .
      cp nu-nightly/nu.exe nu-nightly.exe
      rm -rf nu-nightly
      print $'Please replace nu.exe with nu-nightly.exe manually and restart Nu session'
    },
    _ => {
      print $"Unknown extension ($build.extension), you'll have to figure out how to extract this archive ;)"
    },
  }
}
