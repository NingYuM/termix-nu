
let ASSET_STATS = open tmp/stats.json

def main [] {
  $ASSET_STATS
    | get nodeParts
    | values
    | sort-by renderedLength -r
    | upsert gzipLength { $in | into filesize }
    | upsert brotliLength { $in | into filesize }
    | upsert renderedLength { $in | into filesize }
    | upsert pkg {|it| get-meta $it.metaUid }
    | first 15
    | reject metaUid brotliLength
}

def get-meta [metaId] {
  let meta = $ASSET_STATS.nodeMetas | get $metaId
  let pkg = $meta.id | trim-id
  let moduleParts = $meta.moduleParts | columns | str join ','
  let importedBy = $meta.importedBy | get uid | first 10
  let importedBy = $importedBy | reduce --fold [] {|it, acc|
      $acc ++ ($ASSET_STATS.nodeMetas | get $it | get id | trim-id)
    }
  { pkg: $pkg, moduleParts: $moduleParts, importedBy: $importedBy }
}

def trim-id [] {
  $in | str replace '/Users/hustcer/github/terminus/terp-ui/node_modules/.pnpm/' ''
}
