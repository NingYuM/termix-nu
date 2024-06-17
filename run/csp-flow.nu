# REF:
#   - 一体化页面接入指南: https://aliyuque.antfin.com/irp6y6/ltdqun/sasf9oorc6ywpnqy#OLQhu
#   - 采购代码迁移指南: https://alidocs.dingtalk.com/i/nodes/EpGBa2Lm8aZxe5myCl2jRxO2WgN7R35y
#   - 采购前端页面/组件梳理: https://alidocs.dingtalk.com/i/nodes/Y1OQX0akWmzdBowLFgKNjZ2nVGlDd3mE
#   - 前端接口调用清单: https://aliyuque.antfin.com/go1688/qg7x5q/gr5xixxtdbqrgtcg#t6k3

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

export def convertGBK2UTF8 [] {
  let files = glob pkgs/style-go/**/*.*
  for f in $files {
    print $'Convert ($f)'
    if (file $f | str contains 'ISO-8859') {
      open -r $f | decode gbk | save -rf $f
    }
  }
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

export def gen-page-data [
  environment: string = 'test', # Get page data of the specified environment
] {
  const DEFAULT_PAGE_TITLE = 'Unknown Title'
  const ENV_MAP = {
    test: 'public-go1688-trantor-noprod.oss-cn-hangzhou.aliyuncs.com'
    prod: 'public-go1688-trantor-prod.oss-cn-hangzhou.aliyuncs.com'
  }
  let pages = glob pkgs/**/resources/package.json
    | each { split row 'pkgs/' | last }
    | wrap pkg
    | upsert name {|it| $it.pkg | split row / | first }
    | upsert path cxfe
    | upsert version {|it| open $'pkgs/($it.pkg)' | get distVersion }
    | upsert route {|it| $'asrm/($it.name)' }
    | upsert title {|it|
        let module = $'pkgs/($it.name)/module.json'
        if ($module | path exists) {
          open $module | get title? | default $DEFAULT_PAGE_TITLE
        } else { $DEFAULT_PAGE_TITLE }
      }
    | reject -i pkg

  let data = {
    title: '云采销 - SRM',
    assetsDomain: ($ENV_MAP | get -i $environment),
    pages: $pages,
  }
  $data
    | to json -i 2
    | print
}
