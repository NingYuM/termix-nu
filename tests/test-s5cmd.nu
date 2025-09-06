# REF:
#   - https://www.volcengine.com/docs/6349/147050
use std assert
use std/testing *

def --env load-s3-env [s3conf: string] {
  if (".termixrc" | path exists) {
    open .termixrc | from toml | get $s3conf | load-env
    load-env {
      AWS_REGION: $env.OSS_REGION
      AWS_ACCESS_KEY_ID: $env.OSS_AK
      AWS_SECRET_ACCESS_KEY: $env.OSS_SK
      S3_ENDPOINT_URL: $env.OSS_ENDPOINT
    }
  } else {
    error make {msg: ".termixrc configuration file not found"}
  }
}

@before-each
def --env setup [] {
  print $'load env vars for s5cmd'
}

@after-each
def cleanup [] {
}

@test
def 'test s5cmd should be installed' [] {
  assert equal (s5cmd version | complete | get exit_code) 0
}

@test
def 'test s5cmd should be able to list objects' [] {
  load-s3-env hsoss
  let ls = s5cmd --json ls s3://($env.OSS_BUCKET)/terp-assets/js/ | from json -o
  assert greater ($ls | length) 2
  assert equal ($ls | find terp-assets/js/xlsx-0.20.0.full.min.js | length) 1
}

@test
def 'test s5cmd path style should be able to list objects' [] {
  load-s3-env stmio
  let ls = s5cmd --json --addressing-style path ls s3://($env.OSS_BUCKET)/terp-assets/js/ | from json -o
  assert greater or equal ($ls | length) 2
  assert equal ($ls | find terp-assets/js/xlsx-0.20.0.full.min.js | length) 1
}

@test
def 'test s5cmd sync should be able to work with hash-only flag' [] {
  let tmp_dir = $"($env.PWD)/.tmp-test-sync"
  if ($tmp_dir | path exists) { rm -rf $tmp_dir }
  load-s3-env oss
  mkdir $tmp_dir
  let result = (s5cmd sync --hash-only $"s3://($env.OSS_BUCKET)/terp-assets/js/*" $"($tmp_dir)/" | complete)
  if $result.exit_code == 0 {
    assert greater or equal (ls $tmp_dir | length) 2
    assert equal (ls $tmp_dir | find -r 'xlsx-0.20.0.full.min.js$' | length) 1
  } else {
    print $"s5cmd sync failed with exit code ($result.exit_code): ($result.stderr)"
    assert false "s5cmd sync command failed"
  }
  if ($tmp_dir | path exists) { rm -rf $tmp_dir }
}

@test
def 'test s5cmd sync should be able to work with max-delete flag and skip deletion' [] {
  if (".tmp" | path exists) { rm -rf .tmp }
  load-s3-env oss
  mkdir .tmp
  touch .tmp/local-only-file1.txt
  touch .tmp/local-only-file2.txt
  # max-delete 0 意味着不会删除任何本地文件，即使它们在远程不存在
  s5cmd sync --size-only --delete --max-delete 0 $"s3://($env.OSS_BUCKET)/terp-assets/js/*" .tmp/
  # 验证本地仅有的文件没有被删除（因为 max-delete 0）
  if (".tmp" | path exists) {
    assert equal (ls .tmp | find local-only-file1.txt | length) 1
    assert equal (ls .tmp | find local-only-file2.txt | length) 1
    # 但远程文件应该被同步到本地
    assert greater or equal (ls .tmp | find xlsx-0.20.0.full.min.js | length) 1
  }
  if (".tmp" | path exists) { rm -rf .tmp }
}

@test
def 'test s5cmd sync should be able to work with max-delete flag and delete redundant files' [] {
  sleep 500ms
  if (".tmp" | path exists) { rm -rf .tmp }
  load-s3-env oss
  mkdir .tmp
  touch .tmp/local-only-file1.txt
  touch .tmp/local-only-file2.txt
  # max-delete 3 意味着最多删除 3 个本地文件
  s5cmd sync --size-only --delete --max-delete 3 $"s3://($env.OSS_BUCKET)/terp-assets/js/*" .tmp/
  # 验证本地仅有的文件被删除了（因为它们在远程不存在且 max-delete 允许删除）
  assert equal (ls .tmp | find local-only-file1.txt | length) 0
  assert equal (ls .tmp | find local-only-file2.txt | length) 0
  # 远程文件应该被同步到本地
  assert greater or equal (ls .tmp | find xlsx-0.20.0.full.min.js | length) 1
  if (".tmp" | path exists) { rm -rf .tmp }
}

@test
def 'test s5cmd cp should handle non-regular files with exclude patterns' [] {
  # 测试 GitHub issue #775: Non regular files break `cp` even if they are excluded
  # https://github.com/peak/s5cmd/issues/775

  let test_dir = ($env.PWD)/.tmp-test-socket
  if ($test_dir | path exists) { rm -rf $test_dir }
  load-s3-env oss
  mkdir $test_dir
  let oss_prefix = $'s3://($env.OSS_BUCKET)/fe-resources/s5cmd-test'

  try {
    # 创建常规文件
    'test content 1' | save $'($test_dir)/regular1.txt'
    'test content 2' | save $'($test_dir)/regular2.log'

    # 创建子目录和文件
    mkdir $'($test_dir)/subdir'
    'subdir content' | save $'($test_dir)/subdir/file.txt'

    # 尝试创建一个 Unix socket 文件（模拟非常规文件）
    # 注意：在某些系统上可能无法创建 socket，所以我们使用 try-catch
    let socket_created = try {
      # 使用 mkfifo 创建一个命名管道作为非常规文件的替代
      ^mkfifo $'($test_dir)/test.ipc' | complete
      true
    } catch {
      # 如果无法创建 socket，创建一个符号链接作为非常规文件
      ^ln -sf /dev/null $'($test_dir)/test.ipc' | complete
      true
    }

    # 验证非常规文件存在
    let files_before = (ls $test_dir | length)
    # 至少应该有 regular1.txt, regular2.log, subdir, test.ipc
    assert greater or equal $files_before 4

    # 测试 s5cmd cp 命令，排除 .ipc 文件
    # 这个命令应该成功，即使存在非常规文件
    let result = (s5cmd cp --exclude "*.ipc" $"($test_dir)/*" $"($oss_prefix)/test-socket-issue/" | complete)

    assert equal $result.exit_code 0 $"s5cmd cp should succeed even with non-regular files when excluded. Exit code: ($result.exit_code), stderr: ($result.stderr)"

    # 等待S3达到最终一致性
    sleep 2sec

    # 验证常规文件被上传
    let remote_files = (s5cmd --json ls $"($oss_prefix)/test-socket-issue/" | from json -o)
    let uploaded_regular1 = ($remote_files | find -r 'regular1\.txt$' | length)
    let uploaded_regular2 = ($remote_files | find -r 'regular2\.log$' | length)

    assert equal $uploaded_regular1 1 "regular1.txt should be uploaded"
    assert equal $uploaded_regular2 1 "regular2.log should be uploaded"

    # 验证被排除的文件没有上传
    let uploaded_ipc = ($remote_files | find -r 'test\.ipc$' | length)
    assert equal $uploaded_ipc 0 "test.ipc should be excluded and not uploaded"
    print "✅ test passed: s5cmd correctly handles non-regular files with exclude patterns"

  } catch { |e|
    print $"❌ Exclude non-regular files test failed: ($e.msg)"
    assert false $"Test failed: ($e.msg)"
  }

  if ($test_dir | path exists) { rm -rf $test_dir }
  s5cmd rm $"($oss_prefix)/test-socket-issue/*" | complete
}

@test
def 'test s5cmd cp should work with client-copy within same S3 endpoint' [] {
  # Test s5cmd cp --client-copy functionality for S3-to-S3 copy within same endpoint
  # This avoids the complexity of multi-endpoint authentication

  load-s3-env oss
  let source_prefix = $'s3://($env.OSS_BUCKET)/terp-assets/js/'
  let target_prefix = $'s3://($env.OSS_BUCKET)/fe-resources/s5cmd-test/client-copy/'

  try {
    # Verify source files exist
    let source_files = (s5cmd --json ls $"($source_prefix)" | from json -o)
    assert greater ($source_files | length) 0 "Source directory should contain files"

    let source_js_count = ($source_files | find -r '\.js$' | length)
    assert greater $source_js_count 0 "Source should contain JS files"

    # Clean target directory before test and wait for consistency
    s5cmd rm $"($target_prefix)*" | complete
    sleep 1sec  # Wait for S3 eventual consistency

    # Perform client-copy within same endpoint
    let copy_result = (s5cmd cp --client-copy
      $"($source_prefix)*"
      $"($target_prefix)" | complete)

    assert equal $copy_result.exit_code 0 $"Client copy should succeed. Exit code: ($copy_result.exit_code), stderr: ($copy_result.stderr)"

    # Wait for copy operation to complete and S3 consistency
    sleep 2sec

    # Retry verification with backoff in case of S3 eventual consistency issues
    mut target_files = []
    mut attempts = 0
    let max_attempts = 3

    while $attempts < $max_attempts {
      $target_files = (s5cmd --json ls $"($target_prefix)" | from json -o)
      if ($target_files | length) > 0 {
        break
      }
      $attempts = $attempts + 1
      if $attempts < $max_attempts {
        print $"Waiting for S3 consistency, attempt ($attempts)/($max_attempts)..."
        sleep 1sec
      }
    }

    # Verify files were copied to target
    assert greater ($target_files | length) 0 $"Target directory should contain copied files after ($max_attempts) attempts"

    # Verify specific files were copied (check for JS files)
    let copied_js_files = ($target_files | find -r '\.js$' | length)
    assert greater $copied_js_files 0 "Should have copied JS files"

    # Allow for slight differences due to S3 consistency, but ensure reasonable coverage
    let copy_ratio = ($copied_js_files * 100 / $source_js_count)
    assert greater or equal $copy_ratio 80 $"At least 80% of JS files should be copied. Copied: ($copied_js_files)/($source_js_count)"

    let total_files = ($target_files | length)
    print $"✅ Client copy test passed: copied ($total_files) files using client-copy with ($copied_js_files) JS files out of ($source_js_count) total"

  } catch { |e|
    print $"❌ Client copy test failed: ($e.msg)"
    assert false $"Test failed: ($e.msg)"
  }

  # Cleanup target files
  s5cmd rm $"($target_prefix)*" | complete
}

