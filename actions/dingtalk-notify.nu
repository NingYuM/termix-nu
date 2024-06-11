#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/10/08 13:56:56
# Description:
#   DingTalk Notification Tool, 依赖流水线环境变量:
#   `DINGTALK_NOTIFY`: 'on' 打开, 'off' 关闭, 未设置也是关闭, `DINGTALK_ROBOT_AK`, `DINGTALK_ROBOT_SECRET`
# REF:
#   - [DingTalk Robot API](https://open.dingtalk.com/document/robots/custom-robot-access)
# TODO:
#   - [x] 支持同时向多个机器人发送消息, 多个 Token 用 `,` 分隔
#   - [x] 支持通过手机号码 @指定人
#   - [ ] 支持 `actionCard`, `feedCard` 类型消息
#   - [ ] 升级 OR 创建对应 Erda Action
# Usage:
#   t ding-msg --text 你好啊
#   t ding-msg --text 你好啊 --at-all
#   t ding-msg --text 你好啊 --at-mobiles 13800138000,13800138001
#   t ding-msg --type link --title 欢迎访问端点科技 --msg-url https://terminus.io/ --text '作为国内领先的新商业软件提供商，致力于用平台化、端到端的软件生态方式，为全球各行各业的客户提供全方位的软件产品、解决方案和技术服务'
#   t ding-msg --type markdown --title 欢迎访问端点科技 --text `'## 端点科技 <br/> 欢迎访问 <br/> 友情链接 <br/> [端点科技](https://terminus.io/)'`

use ../utils/common.nu [ECODE, get-env, is-installed]

const DINGTALK_API = 'https://oapi.dingtalk.com/robot/send'
# 链接类型消息的默认图片
const DEFAULT_PIC = 'https://img.alicdn.com/imgextra/i3/O1CN014pnilM25N0WkhbzTq_!!6000000007513-2-tps-1385-1249.png'

# Send a message to DingTalk Group by a custom robot
# 依赖环境变量:
#   - `DINGTALK_NOTIFY`: 'on' 打开, 'off' 关闭, 未设置也是关闭;
#   - `DINGTALK_ROBOT_AK`, `DINGTALK_ROBOT_SECRET`: 钉钉群通知机器人的 `Access Token` 和 `Secret`;
export def 'dingtalk notify' [
  --type(-t): string = 'text',  # 消息类型，默认为：`text`, 其他可选类型：`link`, `markdown`
  --title: string,              # 消息标题, 对 `link`, `markdown` 类型消息有效
  --text: string,               # 消息内容, 对 `text`, `link`, `markdown` 类型消息有效
  --msg-url: string,            # 消息链接, 对 `link` 类型消息有效
  --pic-url: string,            # 图片链接, 对 `link` 类型消息有效
  --at-all,                     # 是否@所有人, 若是则不再单独@指定人, 不支持 'link' 类型消息
  --at-mobiles: string = '',    # 被@人的手机号,多个手机号用 `,` 分隔, 不支持 'link' 类型消息
] {
  let enableNotify = (get-env DINGTALK_NOTIFY 'off' | str trim | str downcase) == 'on'
  let notifyTip = $'DingTalk notification is (ansi r)disabled(ansi reset), to enable it (ansi g)set `DINGTALK_NOTIFY` to `on`(ansi reset) in pipeline environment. Bye~'
  if not $enableNotify { print $notifyTip; exit $ECODE.SUCCESS }
  if $type not-in ['text', 'link', 'markdown'] {
    print $'(ansi r)Invalid message type. Bye~(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }

  check-envs
  let tokens = $env.DINGTALK_ROBOT_AK | str trim | split row ','
  let secrets = $env.DINGTALK_ROBOT_SECRET | str trim | split row ','
  if ($tokens | length) != ($secrets | length) {
    print 'Invalid DINGTALK_ROBOT_AK or DINGTALK_ROBOT_SECRET config, length mismatch!'
    exit $ECODE.INVALID_PARAMETER
  }

  for tk in ($tokens | enumerate) {
    let sign = get-sign ($secrets | get $tk.index)
    let query = { access_token: $tk.item, timestamp: $sign.timestamp, sign: $sign.sign }
    let payload = get-msg-payload --type $type --title $title --text $text --msg-url $msg_url --pic-url $pic_url --at-all $at_all --at-mobiles $at_mobiles
    let ding = http post -t application/json $'($DINGTALK_API)?($query | url build-query)' $payload
    if ($ding.errcode != 0) { print $ding.errmsg; exit $ECODE.INVALID_PARAMETER }
  }
  print 'Bravo, DingTalk message sent successfully.'
}

# Get message payload for DingTalk Robot
def get-msg-payload [
  --type(-t): string = 'text',  # 消息类型，默认为：`text`, 其他可选类型：`link`, `markdown`
  --title: string,              # 消息标题, 对 `link`, `markdown` 类型消息有效
  --text: string,               # 消息内容, 对 `text`, `link`, `markdown` 类型消息有效
  --msg-url: string,            # 消息链接, 对 `link` 类型消息有效
  --pic-url: string,            # 图片链接, 对 `link` 类型消息有效
  --at-all: any = false,        # 是否@所有人, 若是则不再单独@指定人, 不支持 'link' 类型消息
  --at-mobiles: string = '',    # 被@人的手机号,多个手机号用 `,` 分隔, 不支持 'link' 类型消息
] {
  let mention = {
    atMobiles: ($at_mobiles | str replace -a ' ' '' | split row ',')
    isAtAll: $at_all,     # 是否@所有人, 若是则不再单独@指定人, 不支持 'link' 类型消息
  }

  let TEXT_MSG = {
    at: $mention, msgtype: 'text', text: { 'content': $text }
  }

  let picUrl = if ($pic_url | str trim | is-empty) { $DEFAULT_PIC } else { $pic_url }
  let LINK_MSG = {
    msgtype: 'link',
    link: { title: $title, text: $text, messageUrl: $msg_url, picUrl: $picUrl }
  }

  let MARKDOWN_MSG = {
    at: $mention, msgtype: 'markdown', markdown: { title: $title, text: $text }
  }

  match $type { 'text' => $TEXT_MSG, 'link' => $LINK_MSG, 'markdown' => $MARKDOWN_MSG, _ => $TEXT_MSG }
}

# Get signature and timestamp for DingTalk query params by secret
def get-sign [secret: string] {
  if not (is-installed openssl) { print 'Please install `openssl` first.'; exit $ECODE.MISSING_BINARY }
  let timestamp = date now | format date '%s000'
  let sign = $'($timestamp)(char nl)($secret)' | openssl dgst -sha256 -hmac $secret -binary | encode base64
  { timestamp: $timestamp, sign: $sign }
}

# Check if the required environment variable was set, quit if not
def check-envs [] {
  let envs = ['DINGTALK_ROBOT_AK' 'DINGTALK_ROBOT_SECRET']
  let empties = ($envs | filter {|it| $env | get -i $it | is-empty })
  if ($empties | length) > 0 {
    print $'Please set (ansi r)($empties | str join ',')(ansi reset) in your environment first...'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }
}

alias main = dingtalk notify
