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
 USERNAME=159
 # USERNAME=151
"
    let expected = {
        TERMIX_DIR: "/Users/hustcer/iWork/terminus/termix-nu",
        USERNAME: "159"
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

@test
def "from env with empty input" [] {
    # Issue 1: Empty input should return empty record, not empty list
    let result = ("" | from env)
    assert equal $result {}
    assert equal ($result | describe) "record"
}

@test
def "from env with only comments" [] {
    let input = "
# Just a comment
  # Another comment
"
    let result = ($input | from env)
    assert equal $result {}
    assert equal ($result | describe) "record"
}

@test
def "from env with duplicate keys" [] {
    # Issue 2: Duplicate keys should keep last value (common .env behavior)
    let input = "
KEY=first
KEY=second
KEY=third
"
    let expected = { KEY: "third" }
    assert equal ($input | from env) $expected
}

@test
def "from env with blank lines" [] {
    # Issue 5: Blank lines (whitespace only) should be skipped
    let input = "
KEY1=value1


KEY2=value2

KEY3=value3
"
    let expected = { KEY1: "value1", KEY2: "value2", KEY3: "value3" }
    assert equal ($input | from env) $expected
}

@test
def "from env with escaped backslash in double quotes" [] {
    # Double backslash in .env file should become single backslash
    # In single-quoted nushell string: \\ = 2 literal backslashes = one \\ pair in .env
    # In .env format, \\ represents one literal backslash
    let input = 'KEY="path\\to\\file"'
    # Expected value: path\to\file (single backslashes)
    let expected = { KEY: "path\\to\\file" }
    assert equal ($input | from env) $expected
}

@test
def "from env with mixed escapes in double quotes" [] {
    # Test escape sequences in double-quoted values
    # In .env file: \n = newline, \\n = literal backslash + n
    # In single-quoted nushell: \n = backslash + n, \\n = two backslashes + n
    let input = 'KEY="line1\nline2\\nnotanewline"'
    # Expected: line1 + newline + line2 + backslash + n + notanewline
    let expected = { KEY: "line1\nline2\\nnotanewline" }
    assert equal ($input | from env) $expected
}
