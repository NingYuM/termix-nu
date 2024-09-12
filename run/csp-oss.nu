
def update-assets [] {
  let matches = rg -e 'public-go1688-trantor-noprod|public-go1688-trantor-prod' --glob '!tools' --files-with-matches
      | complete | get stdout
  let files = $matches | lines | each { $in | str trim }
  if ($files | is-empty) { return }
  open ../ago-ui/tools/oss.yaml
    | upsert assets { $in | str replace https: '' }
    | each {|it|
      sd $it.assets $'//public-daqihui-prod.oss-cn-hangzhou.aliyuncs.com/fe-resources/cxfe/($it.dest)' ...$files
    } | ignore
}

alias main = update-assets
