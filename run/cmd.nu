#!/usr/bin/env nu

# ./cmd.nu abc okay -s

let foo = 'foo'

def main [
    var1: string
    option?: string
    --show(-s): bool
] {
    $foo
    $var1 == 'abc'
    $show == true
    if $option == $nothing { 'empty' } else { $option }
}
