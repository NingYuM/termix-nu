# REF:
#   - 一体化页面接入指南: https://aliyuque.antfin.com/irp6y6/ltdqun/sasf9oorc6ywpnqy#OLQhu
#   - 采购代码迁移指南: https://alidocs.dingtalk.com/i/nodes/EpGBa2Lm8aZxe5myCl2jRxO2WgN7R35y
#   - 采购前端页面/组件梳理: https://alidocs.dingtalk.com/i/nodes/Y1OQX0akWmzdBowLFgKNjZ2nVGlDd3mE
#   - 前端接口调用清单: https://aliyuque.antfin.com/go1688/qg7x5q/gr5xixxtdbqrgtcg#t6k3

# Pnpm workspace 配置文件生成
# glob pkgs/**/package.json | each { $in | split row 'asrm-ui/' | last | path dirname } | sort | to yaml
# ls pkgs/ -s | select name | upsert pass 'init' | upsert isSeven {|it| $'pkgs/($it.name)/resources' | path exists } | upsert description '' | sort-by name | to yaml | save -f tools/build-pkg.yaml
# open tools/build-pkg.yaml | where isSeven == true | where pass == false | each { just b $in.name }
# ossutil cp -i $env.OSS_AK -k $env.OSS_SK oss://public-daqihui-noprod-uat/fe-resources/csp-pkgs/ -r csp-pkgs
# ossutil cp -i $env.OSS_AK -k $env.OSS_SK -r csp-pkgs oss://public-daqihui-prod/fe-resources/csp-pkgs/

const CSP_APPS = [
  pp-fe
  ep-ui
  ago-ui
  rad-ui
  csp-wx
  acrm-ui
  asrm-ui
  bulma-ui
  buyer-h5
  imall-ui
  carbon-ui
  csp-portal-ui
]

# Update all-pkgs.yml
export def update-all-pkgs [] {
  $CSP_APPS
    | reduce --fold [] {|it, acc|
        z $it;
        let pkgs = if ('pkgs' | path exists) { ls -s pkgs | get name } else { [] }
        $acc ++ $pkgs
      }
    | uniq
    | sort
    | to text
    | print

  print (char nl)
  print r#'Copy and paste then do: open tools/all-pkgs.yml -r | lines | uniq | sort | save -f tools/all-pkgs.yml'#
}

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

# Remove seven modules
export def remove-seven [
  --remove,
  --environment(-e): string = 'test',
] {
  let OSS_MAP = {
    prod: 'oss://public-go1688-trantor-prod/fe-resources/cxfe',
    test: 'oss://public-go1688-trantor-noprod/fe-resources/cxfe-test'
  }
  let oss = $OSS_MAP | get $environment
  let modules = open tools/seven.yml
  let total = $modules | length
  $modules | enumerate | par-each {|it|
    let count = ossutil ls -d -i $env.OSS_AK -k $env.OSS_SK $'($oss)/($it.item)/'
          | parse 'Object and Directory Number is: {count}' | get count | get 0 | into int
    let viewCount = ossutil ls -d -i $env.OSS_AK -k $env.OSS_SK $'($oss)/($it.item)/1.0.0/view/'
          | parse 'Object and Directory Number is: {count}' | get count | get 0 | into int
    print $'($it.index + 1)/($total) | ($oss)/($it.item)/: ($count) / ($viewCount)'
    if $count > 0 and $viewCount > 0 and $remove {
      ossutil rm -rf -i $env.OSS_AK -k $env.OSS_SK $'($oss)/($it.item)/'
    }
  }
}

# Show pipeline resources of CSP apps
export def show-resources [] {
  use std repeat

  const CSP_APP_BUILD_COST = {
    ago-ui: '2min',
    pp-fe: '10min',
    ep-ui: '11min',
    rad-ui: '95min',
    csp-wx: '5min',
    acrm-ui: '98min',
    asrm-ui: '50min',
    bulma-ui: '36min',
    buyer-h5: '5min',
    imall-ui: '3min',
    carbon-ui: '5min',
    csp-portal-ui: '9min',
  }
  mut resources = []
  for app in $CSP_APPS {
    z $app
    let resource = if $app == 'ago-ui' { {} } else if $app == 'pp-fe' {
        open pipeline.yml | get stages.stage.1.0.js-build.resources
      } else {
        open .erda/pipelines/build-all.yml | get stages.stage.1.0.custom-script.resources
      }
    let packages = if $app in [pp-fe ago-ui] { 1 } else { ls pkgs | length }
    let description = open package.json | get description
    let cost = $CSP_APP_BUILD_COST | get $app
    let meta = { app: $app, ...$resource, packages: $packages, cost: $cost, description: $description }
    $resources = $resources ++ [$meta]
  }
  print $resources
  let total = $resources | reduce --fold 0 {|it, acc| $acc + $it.packages }
  print $'(ansi g)('-' | repeat 95 | str join)(ansi reset)'
  print $'Total packages: (ansi p)($total)(ansi reset)'
}

export def get-1688-urls [--save(-s)] {
  let urls = rg 1688.com --glob '!tools' --glob '!mock*' --glob '!example' --glob '!*.{md,vm,xml}' --glob '!module.json' --glob '!build.config.js' --json
    | from json -o
    | filter {|it| $it.type == 'match' }
    | get data
    | select path.text lines.text submatches
    | rename path match submatches
    | update path { $in | str replace pkgs/ '' }
    | filter { not ($in.match | str trim | str starts-with //) }
    | upsert url {|it| $it.match | parse-url $it.submatches }
    | reject match submatches
    | uniq-by url
    | sort-by path

  if $save { $urls | save -f tools/urls.yaml } else { $urls | print }
}

def parse-url [matches] {
  $in
    | str replace -a '"' "'"
    | str replace -a '`' "'"
    | split row "'"
    | filter {|it| $it =~ '1688.com' }
    | to text
    | str trim
}

export def get-keywords [
  keyword: string = '阿里',
  --save(-s)
] {
  const NAME_MAP = { 阿里: 'ali' }
  const IGNORE_PATHS = [notice_detail/resources/modes/view/view.js]
  let keywords = rg $keyword pkgs --glob '!tools' --glob '!mock*' --glob '!{example,demo}' --glob '!*.{md,vm,xml,groovy}' --glob '!{module.json,Justfile}' --glob '!{build.config.js,rsbuild.config.ts}' --json
    | from json -o
    | filter {|it| $it.type == 'match' }
    | get data
    | select path.text lines.text submatches
    | rename path match submatches
    | update path { $in | str replace pkgs/ '' }
    | filter { $in.path not-in $IGNORE_PATHS }
    | filter { not ($in.match | str trim | str starts-with //) }
    | filter { not ($in.match | str trim | str starts-with *) }
    | filter { not ($in.match | str trim | str starts-with /*) }
    | filter {|it| if $keyword == '1688' { $it.match !~ '1688.com' } else { true } }
    | update match {$in | str trim}
    | reject submatches
    | uniq-by match
    | sort-by path

  if $save { $keywords | save -f $'tools/keyword-($NAME_MAP | get -i $keyword | default $keyword).yaml' } else { $keywords | print }
}

export def get-assets [
  --save(-s),
  --append(-a),
  --save-path(-p): string = 'tools/assets.yaml',
  assetsDomain = 'gw.alipayobjects.com',
  workDir = '/Users/hustcer/iWork/terminus/csp-repos-all',
] {
  let currentDir = (pwd)
  cd $workDir

  let urls = rg $assetsDomain --glob '!{tools,example,tests}' --glob '!*.{md,xml}' --json
    | from json -o
    | filter {|it| $it.type == 'match' }
    | get data
    | select path.text lines.text submatches
    | rename path match submatches
    | upsert assets {|it| $it.match | split row '"' | where $it =~ $assetsDomain | get 0 }
    | update assets { $in | str trim --right --char '\' }
    | update assets {|it| $it.assets | split row "'" | where $it =~ $assetsDomain | get 0 }
    | where $it.assets !~ '`'
    | where $it.assets =~ $'($assetsDomain)/'
    | where $it.assets !~ '// 注意：'
    | update assets { $in | str replace '@{' '' | str replace '}' '' }
    | reject match submatches
    | uniq-by assets
    | sort-by assets

  cd $currentDir
  if $save {
    if $append { $urls | save -fa $save_path } else { $urls | save -f $save_path }
  } else { $urls | print }
}
