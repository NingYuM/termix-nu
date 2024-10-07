#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/06/23 12:06:56
# Description: Query and preview TERP assets status.
# [√] Select and query with fzf
# [√] Preview the meta data of selected assets

use terp-assets.nu ['terp assets']
use ../utils/common.nu [ECODE, FZF_KEY_BINDING, FZF_THEME]

const FZF_DEFAULT_OPTS = $'--multi --height 80% --layout=reverse --highlight-line --marker ▏ --pointer ▌ --prompt "▌ " --exact --preview-window=right:90% ($FZF_KEY_BINDING)'

const MOUNT_POINTS = {
  'terp  dev': 'terp-dev'
  'terp test': 'terp-test'
  'terp  pre': 'terp-staging'
  't develop': 'dev'
  't testing': 'test'
  'rls  0330': '2.5.24.0330'
  'rls  0430': '2.5.24.0430'
  'rls  0530': '2.5.24.0530'
  'rls  0630': '2.5.24.0630'
  'rls  0730': '2.5.24.0730'
  'rls  0830': '2.5.24.0830'
  'rls  0930': '2.5.24.0930'
  'fs  foran': 'foran'
  'wqweiqiao': 'weiqiao'
  'mkt  prod': 'market-prod'
  'luq   dev': 'luqiao-dev'
  'luq  test': 'luqiao-test'
  'mgerp prd': 'https://millgrid-public.oss-cn-hongkong.aliyuncs.com/fe-resources/erp-prod/latest.json'
  'mgerp pre': 'https://millgrid-public.oss-cn-hongkong.aliyuncs.com/fe-resources/erp-staging/latest.json'
  'mill  dev': 'https://millgrid-public.oss-cn-hongkong.aliyuncs.com/fe-resources/millgrid-dev/latest.json'
  'mill  prod': 'https://millgrid-public.oss-cn-hongkong.aliyuncs.com/fe-resources/millgrid-prod/latest.json'
  'mill  pre': 'https://millgrid-public.oss-cn-hongkong.aliyuncs.com/fe-resources/millgrid-staging/latest.json'
  'emp   dev': 'https://terminus-emp.oss-cn-hangzhou.aliyuncs.com/fe-resources/dev/latest.json'
  'emp  prod': 'https://terminus-emp.oss-cn-hangzhou.aliyuncs.com/fe-resources/prod/latest.json'
  'xhsd  dev': 'https://xhsd-erp.oss-cn-beijing.aliyuncs.com/fe-resources/xhsd-dev/latest.json'
  'xhsd prod': 'https://xhsd-erp-prod.oss-cn-beijing.aliyuncs.com/fe-resources/xhsd-prod/latest.json'
  'csp  test': 'https://public-go1688-trantor-noprod.oss-cn-hangzhou.aliyuncs.com/fe-resources/csp-test/latest.json'
  'csp   pre': 'https://public-daqihui-noprod-uat.oss-cn-hangzhou.aliyuncs.com/fe-resources/csp-pre/latest.json'
  'csp  prod': 'https://public-go1688-trantor-prod.oss-cn-hangzhou.aliyuncs.com/fe-resources/csp-prod/latest.json'
  'V wq  dev': 'http://minio-tenant.nonprod.hqzc.com/terminus-new-trantor/fe-resources/dev/latest.json'
  'V wq test': 'http://minio-tenant.nonprod.hqzc.com/terminus-new-trantor/fe-resources/test/latest.json'
  'V wq  pre': 'http://minio-tenant.nonprod.hqzc.com/terminus-new-trantor/fe-resources/staging/latest.json'
  'V wq prod': 'http://minio-tenant.inc.ruixinzb.com/terminus-new-trantor/fe-resources/prod/latest.json'
  'V fs  dev': 'http://minio-tenant.terp.fsgas.com/terminus-trantor/fe-resources/fs-dev/latest.json'
  'V fs test': 'http://minio-tenant.terp.fsgas.com/terminus-trantor/fe-resources/fs-test/latest.json'
  'V fs prod': 'http://minio-tenant.terp.fsgas.com/terminus-trantor/fe-resources/fs-prod/latest.json'
}

export def 'check assets' [] {
  cd $env.TERMIX_DIR
  let title = $'Select assets:'
  let PREVIEW_CMD = $"nu actions/check-assets.nu {}"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let selected = $MOUNT_POINTS | columns | str join (char nl) | fzf | complete | get stdout | str trim
  if ($selected | is-empty) { return }
  $selected | lines | each {|it|
    terp assets detect -f ($MOUNT_POINTS | get $it); print -n (char nl)
  } | ignore
}

def main [selected: string] {
  $env.config.table.mode = 'light'
  $env.config.table.index_mode = 'never'
  $env.config.table.padding = { left: 0, right: 0 }
  terp assets detect -f ($MOUNT_POINTS | get $selected)
}
