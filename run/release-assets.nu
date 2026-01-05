#!/usr/bin/env nu

# REF:
#   - https://terminuscloud.yuque.com/uoaf0k/kah4eq/29b713dc91d6940c0b7b27822a0a7f46
#   - https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/fe-resources/terp-pages/dev/index.html

def main [] {
  cd ($nu.home-dir)/iWork/terminus/terp-ui
  ossutil rm -r --force oss://terminus-new-trantor/fe-resources/terp-pages/dev/
  ossutil cp --recursive -f packages/assets/dist/ oss://terminus-new-trantor/fe-resources/terp-pages/dev/
}
