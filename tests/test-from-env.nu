#!/usr/bin/env nu
# Description:
#   Unit tests for `from env`
# Usage:
#   nu tests/test-from-env.nu

use std assert
use utils.nu [run_tests]
use ../utils/common.nu ["from env"]

def main [] {
  run_tests $env.PROCESS_PATH [
    { name: 'from env basic key value', execute: { test-basic } }
    { name: 'from env with comments', execute: { test-comments } }
    { name: 'from env with double quotes', execute: { test-double-quotes } }
    { name: 'from env with single quotes', execute: { test-single-quotes } }
    { name: 'from env with escaped characters', execute: { test-escaped-chars } }
    { name: 'from env with hash in value', execute: { test-hash-in-value } }
    { name: 'from env with whitespace', execute: { test-whitespace } }
    { name: 'from env mixed content', execute: { test-mixed-content } }
    { name: 'from env with commented out variables', execute: { test-commented-out-vars } }
    { name: 'from env with user example structure', execute: { test-user-example } }
    { name: 'from env with export prefix', execute: { test-export-prefix } }
    { name: 'from env with escaped hash', execute: { test-escaped-hash } }
    { name: 'from env with empty input', execute: { test-empty-input } }
    { name: 'from env with only comments', execute: { test-only-comments } }
    { name: 'from env with duplicate keys', execute: { test-duplicate-keys } }
    { name: 'from env with blank lines', execute: { test-blank-lines } }
    { name: 'from env with escaped backslash in double quotes', execute: { test-escaped-backslash } }
    { name: 'from env with mixed escapes in double quotes', execute: { test-mixed-escapes } }
  ]
}

# ============================================
# Tests
# ============================================

def test-basic [] {
  let input = "KEY=VALUE"
  let expected = { KEY: "VALUE" }
  assert equal ($input | from env) $expected
}

def test-comments [] {
  let input = "
# This is a comment
KEY=VALUE # Inline comment
ANOTHER=VAL
"
  let expected = { KEY: "VALUE", ANOTHER: "VAL" }
  assert equal ($input | from env) $expected
}

def test-double-quotes [] {
  let input = 'KEY="VALUE WITH SPACES"'
  let expected = { KEY: "VALUE WITH SPACES" }
  assert equal ($input | from env) $expected
}

def test-single-quotes [] {
  let input = "KEY='VALUE WITH SPACES'"
  let expected = { KEY: "VALUE WITH SPACES" }
  assert equal ($input | from env) $expected
}

def test-escaped-chars [] {
  let input = 'KEY="Line\nBreak\tTab\"Quote\""'
  let expected = { KEY: "Line\nBreak\tTab\"Quote\"" }
  assert equal ($input | from env) $expected
}

def test-hash-in-value [] {
  let input = "
HASH_IN_QUOTE=\"foo#bar\"
HASH_IN_SINGLE='foo#bar'
"
  let expected = { HASH_IN_QUOTE: "foo#bar", HASH_IN_SINGLE: "foo#bar" }
  assert equal ($input | from env) $expected
}

def test-whitespace [] {
  let input = "
    KEY  =  VALUE
    QUOTED = \"  SPACED  \"
    "
  let expected = { KEY: "VALUE", QUOTED: "  SPACED  " }
  assert equal ($input | from env) $expected
}

def test-mixed-content [] {
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

def test-commented-out-vars [] {
  let input = "
# COMMENTED_VAR=value
  # INDENTED_COMMENT=value
REAL_VAR=real_value
"
  let expected = { REAL_VAR: "real_value" }
  assert equal ($input | from env) $expected
}

def test-user-example [] {
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

def test-export-prefix [] {
  let input = "
export EXPORTED=value
    export OTHER = spaced
NO_EXPORT=plain
"
  let expected = { EXPORTED: "value", OTHER: "spaced", NO_EXPORT: "plain" }
  assert equal ($input | from env) $expected
}

def test-escaped-hash [] {
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

def test-empty-input [] {
  let result = ("" | from env)
  assert equal $result {}
  assert equal ($result | describe) "record"
}

def test-only-comments [] {
  let input = "
# Just a comment
  # Another comment
"
  let result = ($input | from env)
  assert equal $result {}
  assert equal ($result | describe) "record"
}

def test-duplicate-keys [] {
  let input = "
KEY=first
KEY=second
KEY=third
"
  let expected = { KEY: "third" }
  assert equal ($input | from env) $expected
}

def test-blank-lines [] {
  let input = "
KEY1=value1


KEY2=value2

KEY3=value3
"
  let expected = { KEY1: "value1", KEY2: "value2", KEY3: "value3" }
  assert equal ($input | from env) $expected
}

def test-escaped-backslash [] {
  let input = 'KEY="path\\to\\file"'
  let expected = { KEY: "path\\to\\file" }
  assert equal ($input | from env) $expected
}

def test-mixed-escapes [] {
  let input = 'KEY="line1\nline2\\nnotanewline"'
  let expected = { KEY: "line1\nline2\\nnotanewline" }
  assert equal ($input | from env) $expected
}
