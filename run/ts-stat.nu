
# 按文件夹或者文件逐个统计其中的 TS 代码行数并打印
ls | select name | insert Lines {
    get name | each {
        cloc --include-lang=TypeScript --exclude-dir node_modules $it |
        lines | parse -r  "TypeScript.+\s+(?P<code>\d+)$" |
        get code | into int
    }
} | default Lines 0

char nl; char nl;

# ls | select name | insert Lines {
#     get name | each {
#         scc  $it |
#         lines | parse -r  "TypeScript  .+\s+(?P<code>\d+)$" |
#         get code | into int
#     }
# } | default Lines 0
