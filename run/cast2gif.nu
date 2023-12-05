# Usage:
#   asciinema rec dplg.cast
#   nu run/cast2gif.nu dplg.cast
def main [cast: string] {
    open $cast | perl -CS -pe 's/([\x{4e00}-\x{9fa5}]|[\x{3040}-\x{30ff}])/$1 /g' | save -rf $'o-($cast)'
    agg $'o-($cast)' $'o-($cast).gif' --renderer=resvg
}
