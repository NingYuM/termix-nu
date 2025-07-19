# This script removes 'filter' internal calls from .nu files in the
# current directory and its subdirectories.
# It searches for occurrences of 'filter' and replaces them with 'where'
glob **/*.nu
  | each {|file|
    open $file
      | ast $in --flatten
      | where content == 'filter' and shape == 'shape_internalcall'
      | if ($in | is-not-empty) { {file: $file occurrences: $in} }
  }
  | compact
  | each {|item|
    let content = open $item.file
    let new_content = $item.occurrences
      | reverse
      | reduce -f $content {|occurrence acc|
        let before = ($acc | str substring ..<$occurrence.span.start)
        let after = ($acc | str substring $occurrence.span.end..)
        $'($before)where($after)'
      }
    $new_content | save -f $item.file
  }
