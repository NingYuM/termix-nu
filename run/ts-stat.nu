
# 按文件夹或者文件逐个统计其中的 TS 代码行数并打印
ls | select name | update Lines {
    get name | each { |it|
        cloc --include-lang=TypeScript --exclude-dir node_modules $it |
        lines | parse -r  "TypeScript.+\s+(?P<code>\d+)$" |
        get code | into int
    }
} | default Lines 0 | flatten

char nl; char nl;

# ls | select name | update Lines {
#     get name | each { |it|
#         scc  $it |
#         lines | parse -r  "TypeScript  .+\s+(?P<code>\d+)$" |
#         get code | into int
#     }
# } | default Lines 0 | flatten

# Counting all nushell lines:
# fd .nu | lines | each { |it| wc -l $it } | detect columns -n | rename lines file | get lines | each { $it|into int } | math sum
