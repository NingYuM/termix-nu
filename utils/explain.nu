#!/usr/bin/env nu

# | Examples:
# | help explain "ls | sort-by size | reverse | first | get name | unknown-external | non-existing"
# | => ls - List the filenames, sizes, and modification times of items in a directory.
# | => sort-by - Sort by the given cell path or closure.
# | =>   size - The cell path(s) or closure(s) to compare elements by.
# | => reverse - Reverses the input list or table.
# | => first - Return only the first several rows of the input. Counterpart of `last`. Opposite of `skip`.
# | => get - Extract data using a cell path.
# | =>   name - The cell path to the data.
# | => unknown-external - This command is neither known to nu nor does it exist in PATH
# | => non-existing - This command is neither known to nu nor does it exist in PATH
# |
# | help explain "ls -d foo bar baz"
# | => ls - List the filenames, sizes, and modification times of items in a directory.
# | =>   -d - Display the apparent directory size ("disk usage") in place of the directory metadata size
# | =>   foo - The glob pattern to use.
# | =>   bar - The glob pattern to use.
# | =>   baz - The glob pattern to use.

# Explain the pipeline
export def "help explain" [pipeline: string] {
  ast -f $pipeline
    | reduce -f null {|it, acc| explain-item $it $acc }
    | ignore
}

# Explain a single item in the pipeline
def explain-item [item: record, last?: record] {
  let content = $item.content
  let highlight = $content | nu-highlight
  match $item.shape {
    shape_internalcall => {
      let explain = help $content | lines | first
      print $'($highlight) - ($explain)'
      $item
    },
    shape_flag if $last != null => {
      let flag = (
        help commands
          | where name == $last.content
          | get 0.params
          | where name =~ ($content + '(\(|\))')
          | get 0
      )
      print $'  ($content) - ($flag.description)'
      $last | upsert flag ($flag.type? != 'switch')
    },
    shape_external => {
      if (which $content | get path | is-not-empty) {
        print $'($highlight) - An external program, unknown to nu'
      } else {
        print $'($highlight) - This command is neither known to nu nor does it exist in PATH'
      }
      null
    },
    shape_pipe => null,
    _ if $last.flag? == true => ($last | update flag false)
    _ => {
      let arg = $last.arg? | default 0
      let params = (
        help commands
          | where name == $last.content
          | get 0.params
          | where not ($it.name starts-with '-')
      )
      if $arg >= ($params | length) {
        if ($params | last | $in.name starts-with '...') {
          print $'  ($content) - ($params | last | get description)'
        }
      } else {
          print $'  ($content) - ($params | get $arg | get description)'
      }

      $last | upsert arg ($arg + 1) | upsert flag false
    }
  }
}
