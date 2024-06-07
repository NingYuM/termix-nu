
# Pnpm workspace 配置文件生成
# glob pkgs/**/package.json | each { $in | split row 'asrm-ui/' | last | path dirname } | sort | to yaml
# ls pkgs/ -s | select name | upsert pass 'init' | upsert isSeven {|it| $'pkgs/($it.name)/resources' | path exists } | upsert description '' | sort-by name | to yaml | save -f tools/build-pkg.yaml
# open tools/build-pkg.yaml | where isSeven == true | where pass == false | each { just b $in.name }

export def update-pkg [] {
  let pkgs = ls pkgs/ | get name
  # Clear Husky config
  print 'Removing husky config...'
  $pkgs | each {|it|
    let pkgJson = glob $'($it)/**/package.json' | first
    let pkg = open $pkgJson | reject -i husky
    $pkg | save -f $pkgJson
  }

  # Add assets script after building assets
  print 'Adding assets.nu script after building assets...'
  $pkgs | each {|it|
    let pkgJson = glob $'($it)/**/package.json' | first
    let assetsScript = if ($pkgJson =~ 'resources') { '../../../tools/assets.nu' } else { '../../tools/assets.nu' }
    let pkg = open $pkgJson
        | upsert scripts.build {|it|
            if ($it.scripts?.build? | is-empty) {
              if ($pkgJson =~ 'resources') {
                $'rsbuild build && nu ($assetsScript)'
              }
            } else if not ($it.scripts?.build? =~ 'assets.nu') {
              $'($it.scripts?.build?) && nu ($assetsScript)'
            } else {
              $it.scripts?.build?
            }
          }
    $pkg | save -f $pkgJson
  }

  # Add assets release version for each package
  print 'Adding assets release version for each package...'
  $pkgs | each {|it|
    let pkgJson = glob $'($it)/**/package.json' | first
    let pkg = open $pkgJson | upsert distVersion '1.0.0'
    $pkg | save -f $pkgJson
  }

  # Remove f2elint deps
  print 'Removing outdated f2elint deps...'
  $pkgs | each {|it|
    let pkgJson = glob $'($it)/**/package.json' | first
    let pkg = open $pkgJson | reject -i devDependencies.f2elint
    $pkg | save -f $pkgJson
  }

  print 'Formatting code...'
  just fmt
}

export def prepare-pkg [--add-missing-pkg(-a)] {
  # Copy missing packages
  let repoRoot = '/Users/hustcer/github/term-o/csp_fe_repos'
  let pkgs = open -r tools/pkgs.yaml | lines
  let currentPkgs = ls pkgs -s | get name
  let packages = ($pkgs ++ $currentPkgs | uniq | sort) | wrap pkg
    | upsert srcExists {|it| ($'($repoRoot)/($it.pkg)' | path exists) }
    | upsert isSeven {|it| ($'($repoRoot)/($it.pkg)/resources/' | path exists) }
    | upsert transferred {|it|
        let pkgJson = if $it.isSeven { $'pkgs/($it.pkg)/resources/package.json' } else { $'pkgs/($it.pkg)/package.json' }
        ($'pkgs/($it.pkg)' | path exists) and ($pkgJson | path exists)
      }
    | upsert shouldRemove {|it| ($it.pkg not-in $pkgs) }
    | sort-by isSeven pkg

  $packages | print
  if $add_missing_pkg {
    let missingPkgs = $packages | where transferred == false
    if ($missingPkgs | length) > 0 {
      print 'The following missing pkgs will be added:'
      print $missingPkgs
      $missingPkgs | each {|it| cp -r $'($repoRoot)/($it.pkg)' pkgs/ }
      return
    }
    print "\nNothing to be added, bye...\n"
  }
}
