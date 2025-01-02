# Description: Unzip a targz file to a specified directory.
# Unzip tar.gz: 16sec 314ms 198µs, 16sec 493ms 940µs
# Zip   tar.gz: 1min 55sec 890ms 484µs, 1min 55sec 124ms 693µs
# Zip  tar.zst:
#   level 09: 51sec 296ms 27µs, 1.8G
#   level 12:
# Unzip tar.zst: 37sec 397ms 217µs, 36sec 963ms 86µs
# Usage:
#   zstd.nu zip-zstd gradle-cache.tar.zst
#   zstd.nu unzip-zstd gradle-cache.tar.zst
#   zstd.nu zip-targz gradle-cache.tar.gz
#   zstd.nu unzip-targz gradle-cache.tar.gz

def unzip-targz [file: string, dir: string = 'gradle-cache'] {
    if not ($dir | path exists) { mkdir $dir }
    let start = date now
    tar -xzf $file -C $dir
    let end = date now
    print $'Unzipping ($file) to ($dir) took (ansi g)($end - $start)(ansi reset)'
}

def zip-targz [file: string, dir: string = 'gradle-cache'] {
    let start = date now
    tar -czf $file -C $dir .
    let end = date now
    print $'Zipping ($file) to ($dir) took (ansi g)($end - $start)(ansi reset)'
}

def zip-zstd [file: string, dir: string = 'gradle-cache'] {
    let start = date now
    tar -cf - $dir | zstd -f -9 -o $file
    let end = date now
    print $'Zstd compressing ($file) took (ansi g)($end - $start)(ansi reset)'
}

def unzip-zstd [file: string, dir: string = 'gradle-cache'] {
    if not ($dir | path exists) { mkdir $dir }
    let start = date now
    zstd -dc $file | tar -xf -
    let end = date now
    print $'Zstd decompressing ($file) took (ansi g)($end - $start)(ansi reset)'
}

def main [action: string, file: string, dir: string = 'gradle-cache'] {
    match $action {
        'zip-zstd' => { zip-zstd $file $dir },
        'zip-targz' => { zip-targz $file $dir },
        'unzip-zstd' => { unzip-zstd $file $dir },
        'unzip-targz' => { unzip-targz $file $dir },
    }
}
