#!/usr/bin/env nu

# Author: hustcer
# Created: 2024/12/07 17:52:00
# Description:
#   [√] Create gradle cache tarball and upload to OSS.
#   [√] Download and extract the tarball to local cache directory.
#   [√] Create a cache sha256sum file and upload to OSS.
#   [√] Don't upload cache if the tarball already exists in OSS.
#   [√] Use --force to upload cache even if it exists in OSS.
# Usage:
#   nu gradle-cache.nu --cache-key=gradle-cache --oss-path=fe-resources/app-pod --cache-dir=/opt/android/gradle/caches
#   nu gradle-cache.nu --cache-key=gradle-cache --oss-path=fe-resources/app-pod --cache-dir=/opt/android/gradle/caches --force
#   nu gradle-cache.nu --download --cache-key=gradle-cache --oss-path=fe-resources/app-pod --cache-dir=/opt/android/gradle/caches
#   依赖环境变量：
#     - OSS_BUCKET  : OSS bucket name
#     - OSS_AK      : OSS access key id
#     - OSS_SK      : OSS access key secret
#     - OSS_ENDPOINT: OSS endpoint, default is https://oss-cn-hangzhou.aliyuncs.com
# REF:
#   - https://docs.erda.cloud/next/manual/dop/guides/reference/pipeline.html

use common.nu [hr-line, is-installed, get-env]

const TABLE_MODE = 'psql'

# Gradle cache manager can be used to speed up the build process by caching the downloaded dependencies.
export def main [
  --force(-f),      # Force to create and upload the tarball even if it exists.
  --download(-d),   # Download the tarball from OSS and extract to local cache directory.
  --cache-key(-k): string = 'gradle-cache',                 # Cache key to download or upload the tarball, same as the tarball file name.
  --oss-path(-p): string = 'fe-resources/app-pod',          # OSS bucket path to upload the tarball.
  --cache-dir(-c): string = '/opt/android/gradle/caches',   # Local directory to extract the tarball or create the tarball from.
  --ignore-missing, # Don't raise error if the cache file is missing
] {
  if $download {
    download-and-setup-cache --cache-key $cache_key --oss-path $oss_path --cache-dir $cache_dir --ignore-missing=$ignore_missing
  } else {
    upload-gradle-cache --cache-key $cache_key --oss-path $oss_path --cache-dir $cache_dir --force=$force
  }
}

# Download and extract the tarball to local cache directory.
def download-and-setup-cache [
  --oss-path: string,   # OSS bucket path to upload the tarball.
  --cache-key: string,  # Cache key to download or upload the tarball, same as the tarball file name.
  --cache-dir: string,  # Local directory to extract the tarball or create the tarball from.
  --ignore-missing,     # Ignore the missing cache file
] {
  print $'(ansi g)Downloading and setting up gradle cache...(ansi rst)'

  # Prepare cache directory
  rm -rf $cache_dir; mkdir $cache_dir
  let cache_url = build-oss-url $oss_path $cache_key
  print $'Fetching: (ansi g)($cache_url)(ansi rst)'

  # Check if cache file exists before downloading
  let http_code = (do -i { curl -sSL -w "%{http_code}" -o /dev/null $cache_url } | complete | get stdout | str trim)

  match $http_code {
    "200" => {
      curl -sSL $cache_url | tar -xz -C $cache_dir
      print 'Gradle cache is ready with the following contents:'; hr-line
      ls $cache_dir | table -w 200 -t $TABLE_MODE | print; print -n (char nl)
    },
    "404" => {
      handle-download-error $cache_url $http_code $ignore_missing "Cache file not found"
    },
    _ => {
      handle-download-error $cache_url $http_code $ignore_missing $"Failed to download cache"
    }
  }
}

# Build OSS URL for cache file
def build-oss-url [
  oss_path: string,
  cache_key: string,
  --suffix: string = '.tar.gz'  # File suffix, default is .tar.gz
] {
  $'https://($env.OSS_BUCKET).oss-cn-hangzhou.aliyuncs.com/($oss_path)/($cache_key)($suffix)'
}

# Handle download errors with optional ignore
def handle-download-error [
  url: string,
  http_code: string,
  ignore_missing: bool,
  message: string
] {
  if $ignore_missing {
    print $'(ansi y)($message) （HTTP ($http_code)）, but --ignore-missing is set. Continuing...(ansi rst)'
  } else {
    error make { msg: $'($message) at ($url), HTTP status: ($http_code)' }
  }
}

# Create and upload the tarball to OSS.
def upload-gradle-cache [
  --force,              # Force to create and upload the tarball even if it exists.
  --oss-path: string,   # OSS bucket path to upload the tarball.
  --cache-key: string,  # Cache key to download or upload the tarball, same as the tarball file name.
  --cache-dir: string,  # Local directory to extract the tarball or create the tarball from.
] {
  # Ensure ossutil is installed
  if not (is-installed ossutil) {
    let endpoint = get-env OSS_ENDPOINT 'https://oss-cn-hangzhou.aliyuncs.com'
    setup-oss-util -e $endpoint -k $env.OSS_AK -s $env.OSS_SK
  }

  # Check if cache already exists in OSS
  let hash_url = build-oss-url $oss_path $cache_key --suffix '.tar.gz.sha256.txt'
  let sha256sum = http get -e -r $hash_url

  if not $force and not ($sha256sum | str contains 'NoSuchKey') {
    print $'(ansi g)The cache file already exists in OSS, skip uploading.(ansi rst)'
    return
  }

  # Create and upload cache
  print $'(ansi g)Creating and uploading gradle cache for the following contents:(ansi rst)'; hr-line
  ls $cache_dir | table -w 200 -t $TABLE_MODE | print; print -n (char nl)

  let temp_dir = mktemp -d
  let tarball = $'($temp_dir)/($cache_key).tar.gz'

  tar -czf $tarball -C $cache_dir .
  open -r $tarball | hash sha256 | save -rf $'($tarball).sha256'

  let oss_tarball = $'oss://($env.OSS_BUCKET)/($oss_path)/($cache_key).tar.gz'
  let oss_hash = $'oss://($env.OSS_BUCKET)/($oss_path)/($cache_key).tar.gz.sha256.txt'

  ossutil cp --force $tarball $oss_tarball
  ossutil cp --force $'($tarball).sha256' $oss_hash
}

# Setup ossutil
export def setup-oss-util [
  --endpoint(-e): string,    # The endpoint of OSS
  --ak-id(-k): string,       # The access key id of OSS
  --ak-secret(-s): string,   # The access key secret of OSS
  --sts-token(-t): string,   # The STS token of OSS
] {
  sudo -v; curl https://gosspublic.alicdn.com/ossutil/install.sh | sudo bash
  if ($sts_token | is-empty) {
    ossutil config --endpoint $endpoint --access-key-id $ak_id --access-key-secret $ak_secret
  } else {
    ossutil config --endpoint $endpoint --access-key-id $ak_id --access-key-secret $ak_secret --sts-token $sts_token
  }
}
