use ../utils/common.nu [hr-line]

const HEADERS = [
  'cookie'
  'terp_iam_dev=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ0b2tlbklkIjoiMjAyNTA3MjEwOTM1MTgyODNmNGFjMjdmZmM0MWI0Y2QxOWNiYTkwNTdjNzU4NmY3ZSIsImV4cGlyZSI6MjU5MjAwLCJwYXRoIjoiLyIsImRvbWFpbiI6InRlcm1pbnVzLmlvIiwiaHR0cE9ubHkiOnRydWUsInNlY3VyZSI6ZmFsc2UsImlzcyI6ImlhbSgyLjUuMjUuMDUzMC4wLVNOQVBTSE9UKSIsInN1YiI6ImlhbSB1c2VyIiwiZXhwIjoxNzUzNDk5NTk1LCJuYmYiOjE3NTMyNDAzOTUsImlhdCI6MTc1MzI0MDM5NSwianRpIjoiZDA2N2Y0YWFlMzdiNDk2ODk3MWUxYzg2MDZlZTc2ZWEifQ.iIAccE8Hje9U9mA4v-JInFQmydopUquMGG-gmRYooyA'
]

const MENU_API = '/api/trantor/menu/tree/TERP_PORTAL'

const SETTINGS = {
  dev: {
    code: 203,
    name: 'TERP_PORTAL',
    host: 'https://t-erp-console-dev.app.terminus.io'
  },
  test: {
    code: 22,
    name: 'TERP_PORTAL',
    host: 'https://t-erp-console-test.app.terminus.io'
  },
  staging: {
    code: 1,
    name: 'TERP_PORTAL',
    host: 'https://t-erp-console-staging.app.terminus.io'
  }
}

# Query TERP menus and save to local file by environment
export def query-menu [environment: string = 'dev'] {
  let option = $SETTINGS | get $environment
  let headers = [trantor2-app $option.name trantor2-team $option.code]
  let menu = http get -H [...$HEADERS ...$headers] $'($option.host)($MENU_API)' | get data
  # Collect and sort all leaf node paths
  print "All Leaf Node Paths (Sorted)   "; hr-line
  let all_menus = if ($menu | length) > 0 {
    $menu | each { |item| collect-leaf-paths $item } | flatten | sort
  } else { [] }

  $all_menus | save -rf $'./data/menu-($environment).md'

  $all_menus | str join "\n" | print
}

# Function to recursively collect leaf node paths
def collect-leaf-paths [node: any, path: string = ""] {
  let current_label = $node | get label
  let current_path = if ($path | str length) > 0 {
    $path + " --> " + $current_label
  } else {
    $current_label
  }

  # Check if children field exists and is not empty
  let children = try { $node | get children } catch { [] }

  if ($children | length) == 0 {
    # This is a leaf node, return the path
    [$current_path]
  } else {
    # Has child nodes, recursively collect paths from each child node
    $children | each { |child|
      collect-leaf-paths $child $current_path
    } | flatten
  }
}

alias main = query-menu
