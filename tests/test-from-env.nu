use std assert
use std/testing *
use ../utils/common.nu ["from env"]

@test
def "from env basic key value" [] {
    let input = "KEY=VALUE"
    let expected = { KEY: "VALUE" }
    assert equal ($input | from env) $expected
}

@test
def "from env with comments" [] {
    let input = "
# This is a comment
KEY=VALUE # Inline comment
ANOTHER=VAL
"
    let expected = { KEY: "VALUE", ANOTHER: "VAL" }
    assert equal ($input | from env) $expected
}

@test
def "from env with double quotes" [] {
    let input = 'KEY="VALUE WITH SPACES"'
    let expected = { KEY: "VALUE WITH SPACES" }
    assert equal ($input | from env) $expected
}

@test
def "from env with single quotes" [] {
    let input = "KEY='VALUE WITH SPACES'"
    let expected = { KEY: "VALUE WITH SPACES" }
    assert equal ($input | from env) $expected
}

@test
def "from env with escaped characters" [] {
    let input = 'KEY="Line\nBreak\tTab\"Quote\""'
    let expected = { KEY: "Line\nBreak\tTab\"Quote\"" }
    assert equal ($input | from env) $expected
}

@test
def "from env with hash in value" [] {
    let input = "
HASH_IN_QUOTE=\"foo#bar\"
HASH_IN_SINGLE='foo#bar'
"
    let expected = { HASH_IN_QUOTE: "foo#bar", HASH_IN_SINGLE: "foo#bar" }
    assert equal ($input | from env) $expected
}

@test
def "from env with whitespace" [] {
    let input = "
    KEY  =  VALUE
    QUOTED = \"  SPACED  \"
    "
    let expected = { KEY: "VALUE", QUOTED: "  SPACED  " }
    assert equal ($input | from env) $expected
}

@test
def "from env mixed content" [] {
    let input = "
SIMPLE=value
# Comment
WITH_HASH=\"foo#bar\" # comment
WITH_EQUALS=foo=bar
WITH_QUOTES=\"quoted\"
WITH_SINGLE_QUOTES='single quoted'
EMPTY_LINE=
"
    let expected = {
        SIMPLE: "value",
        WITH_HASH: "foo#bar",
        WITH_EQUALS: "foo=bar",
        WITH_QUOTES: "quoted",
        WITH_SINGLE_QUOTES: "single quoted",
        EMPTY_LINE: ""
    }
    assert equal ($input | from env) $expected
}

@test
def "from env with commented out variables" [] {
    let input = "
# COMMENTED_VAR=value
  # INDENTED_COMMENT=value
REAL_VAR=real_value
"
    let expected = { REAL_VAR: "real_value" }
    assert equal ($input | from env) $expected
}

@test
def "from env with user example structure" [] {
    let input = "
# TERMIX_DIR=/work
 TERMIX_DIR=/Users/hustcer/iWork/terminus/termix-nu
 ERDA_USERNAME=15988136866
 # ERDA_USERNAME=15195950676
"
    let expected = {
        TERMIX_DIR: "/Users/hustcer/iWork/terminus/termix-nu",
        ERDA_USERNAME: "15988136866"
    }
    assert equal ($input | from env) $expected
}

@test
def "from env with export prefix" [] {
    let input = "
export EXPORTED=value
    export OTHER = spaced
NO_EXPORT=plain
"
    let expected = { EXPORTED: "value", OTHER: "spaced", NO_EXPORT: "plain" }
    assert equal ($input | from env) $expected
}

@test
def "from env with escaped hash" [] {
    let input = "
PASSWORD=abc\\#123
URL=https://example.com/\\#anchor # trailing comment
LITERAL=foo\\bar
"
    let expected = {
        PASSWORD: "abc#123",
        URL: "https://example.com/#anchor",
        LITERAL: "foo\\bar"
    }
    assert equal ($input | from env) $expected
}
