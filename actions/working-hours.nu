#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/22 15:36:56
# Description: Check working hours filling status
#   [√] Query working hours for multiple teams
#   [√] Query working hours of previous week
#   [√] Don't print the result if --silent is set
#   [√] Notify the members who didn't fill the working hours by Dintalk Robot
#   [√] Add a config file to store the EMP_PROJECT_CODE, etc.
#   [√] EMP global environment setting to turn on or off the notification
#   [√] Create a docker image to run this script in Erda pipeline
#   [√] 只有周五、周六、周日、月底才发送提醒消息
#   [√] 每周一查询上周工时填报情况，如果有人未填报，发送提醒消息
#   [√] 确保该脚本可以每天运行，但是只有符合上述情况才提醒
#   [√] Lastday(Monday and Month end) keep polling and notify with specified interval
#   [√] Ignore some team with `ignore = true` in config file
#   [√] Valid user mobile number before notify
#   [√] Add --debug flag to print more debug info
#   [√] Add --no-ignore flag to query working hours for all teams
#   [√] Add --month flag to query working hours by specified month
#   [√] 考虑调休、补班等情况下工时是否填满的判定: 由 EMP 接口返回的数据中的 `surplusPercentage` 字段判断
#   [√] 团队成员名单及手机号自动从接口更新，免去手动维护
#   [√] Add `atAllMinCount` option to mention all if the count of mention users is above specified number
#   [√] Add `WORKDAYS_TILL_MONTH_END` environment variable to specify total workdays till month end of current week
#   [√] 工时填满后间隔提醒定时任务需要退出
#   [√] 支持通过设置 LAST_DAY, LASTDAY_MSG 将某天设置为最后期限以启动间隔提醒
#   [√] Add `SKIP_UNTIL` env variable to specify the time to start reminding
#   [√] Update the docs
# Usage:
#   t emp
#   t emp-daily
#   0 0 17 * * ?  # 每天下午 5 点执行 working-hours-daily-checking
# Data Source
#   https://emp.app.terminus.io/view/worktime_WorkTimeBO_DepartmentWorkTime

use dingtalk-notify.nu ['dingtalk notify']
use ../utils/common.nu [ECODE, get-conf, get-env, log]

const _WEEK_FMT = '%A'
const _MONTH_FMT = '%m'
const _TIME_FMT = '%Y-%m-%d %H:%M:%S'
const CHECK_DURATION = 0day
const DEFAULT_LASTDAY_MSG = '特别提醒：马上要放假了，请务必在今天完成本周工时填写，因为接下来机器人也要休假了。'

# Run EMP working hours checking job everyday, but only send notifications for Monday, Friday, Saturday, Sunday and Month end
export def working-hours-daily-checking [--debug(-d)] {
  let confEMP = load-emp-conf
  let messages = $confEMP | get settings?.messages? | default {}
  let checkPoint = (date now) + $CHECK_DURATION
  let isMonthEnd = is-month-end $checkPoint
  let isLastDay = $env.LAST_DAY? == 'on'
  # Get monday, ..., friday, saturday, sunday
  let weekday = $checkPoint | format date $_WEEK_FMT | str downcase
  # Skip notify until the specified time
  if (not ($env.SKIP_UNTIL? | is-empty)) and $checkPoint < ($env.SKIP_UNTIL | into datetime) {
    print $'Skip notify until ($env.SKIP_UNTIL)...'
    exit $ECODE.SUCCESS
  }
  # 非周五、六、日、一直接返回
  if not (($weekday in $messages) or $isMonthEnd or $isLastDay) {
    print $'Skip notify at (ansi p)($weekday)(ansi reset)...';
    exit $ECODE.SUCCESS
  }
  if $isLastDay {
    query-hours-by-team-codes --notify --silent --keep-polling --debug=$debug
    return
  }
  if $weekday == 'monday' {
    print $'Query working hours of previous week...'
    query-hours-by-team-codes --show-prev --notify --silent --keep-polling --debug=$debug
    return
  }
  query-hours-by-team-codes --notify --silent --keep-polling=$isMonthEnd --debug=$debug
}

# Query working hours for each team from EMP and display the filling status of each team member
export def query-hours-by-team-codes [
  --debug(-d),        # Print more debug info
  --silent(-s),       # Don't print the result
  --month(-m): int,   # Query working hours by specified month
  --notify(-n),       # Notify the members who didn't fill the working hours by Dintalk Robot
  --show-prev(-p),    # Query working hours of previous week
  --show-all(-a),     # Show all members even if the working hours have been filled correctly
  --no-ignore(-I),    # Don't ignore the team with `ignore = true` in config file
  --keep-polling,     # Keep polling until all members have filled the working hours
] {
  let confEMP = load-emp-conf
  mut teams = $confEMP.teams | values | default false ignore | where ignore != true
  if $no_ignore { $teams = ($confEMP.teams | values | default false ignore) }
  if ($teams | get code | is-empty) {
    print $'(ansi r)Please set the `code` field in all `emp.teams`, bye...(char nl)(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  if not ($month | is-empty) {
    $teams | each { |it| query-monthly-hours-by-team $it --debug=$debug --show-all=$show_all --month=$month }
    return
  }
  if not $keep_polling {
    $teams | each { |it|
      query-hours-by-team $it --show-all=$show_all --show-prev=$show_prev --notify=$notify --silent=$silent --debug=$debug
    } | ignore
    return
  }

  mut teamWatcher = {}
  loop {
    for it in $teams {
      let finished = query-hours-by-team $it --show-all=$show_all --show-prev=$show_prev --notify=$notify --silent=$silent --debug=$debug
      $teamWatcher = ($teamWatcher | upsert $it.code $finished)
    }
    log 'teamWatcher' $teamWatcher
    if ($teamWatcher | values | all { $in == true }) { break }
    let interval = $confEMP.settings?.lastdayNotifyInterval? | default '30min' | into duration
    print $'Wait ($interval) to check again...'
    sleep $interval
  }
}

# Load emp settings and store them to environment variable
def --env load-emp-conf [] {
  let empConf = open $'($env.TERMIX_DIR)/.termixrc' | from toml | get -i emp | default null
  if ($empConf | is-empty) {
    print $'(ansi r)Please set `emp` related configs in `($env.TERMIX_DIR)/.termixrc`, bye...(char nl)(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  $env.EMP_CONF = $empConf
  return $empConf
}

# Query working hours filling status by specified month
export def query-monthly-hours-by-team [
  team: record,       # Team record, contains name,code,alias,users,etc.
  --debug(-d),        # Print more debug info
  --month(-m): int,   # Query working hours by specified month
  --show-all(-a),     # Show all members even if the working hours filled correctly
] {
  if ($month > 12) or ($month < 1) {
    print $'The specified month (ansi r)($month)(ansi reset) should lay in (ansi p)1 ~ 12(char nl)(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  # let currentMonth = date now | format date %m | into int
  # if ($month > $currentMonth) {
  #   print $'(ansi r)The specified month ($month) is greater than the current month ($currentMonth), bye...(char nl)(ansi reset)'
  #   exit $ECODE.INVALID_PARAMETER
  # }
  let monday = get-monday
  let sunday = get-sunday
  let emp = get-conf empWorkingHour
  let staffs = query-staffs-by-team $team.code $monday $sunday

  let iptMonth = $month | fill --alignment right -w 2 -c '0'
  let nextMonth = ($month + 1) | fill --alignment right -w 2 -c '0'
  let monthStart = (date now) | format date $'%Y-($iptMonth)-01 00:00:00'
  let monthEnd = if ($month + 1) == 13 { ($monthStart | into datetime) + 31day } else { ((date now) | format date $'%Y-($nextMonth)-01 00:00:00' | into datetime) }
  let monthEnd = $monthEnd - 1sec | format date $_TIME_FMT
  print $'Query working hours from ($monthStart) to ($monthEnd) for team (ansi p)($team.name)(ansi reset)'
  let title = $"($team.name) (ansi g)($month)(ansi reset) 月工时填报\(人/天\)"
  print $"\n-------------------------> (ansi p)($title) <-------------------------(ansi reset)\n"

  let timeSummaryPayload = $emp.timeSummaryPayload
    | str replace '_last_day_' $monthEnd
    | str replace '_first_day_' $monthStart
    | str replace '_staffs_' $staffs.staffPayload
    | str replace '_department_' ({id: $team.code} | to json -r)
  let summary = curl $emp.timeSummaryUrl -H $emp.type -H $emp.app -s --data-raw $timeSummaryPayload | str join
  let hourSummary = (
      ($summary | from json | get res | select staffWorkTimeFillResponseList | flatten
        | get staffWorkTimeFillResponseList
        | where ($it | describe) =~ 'record' and ($it.staffBO?.id | default 0) > 0
        | rename --column {
            otherPercentage: Other,
            leavePercentage: 请假人天,
            theoryPercentage: 理论人天,
            actualPercentage: 实际人天,
            surplusPercentage: Surplus,
        })
      | upsert 剩余应填 { |it| $it.baseProjectWorkTimeSummaryList | where name == '剩余应填' | get 0 | get percentage }
      | upsert 空闲人天 { |it| $it.baseProjectWorkTimeSummaryList | where name == '空闲工时' | get 0 | get percentage }
      | upsert Name { |it| if $it.空闲人天 > 0 { $'(ansi r)($it.staffBO.name)(ansi reset)' } else { $it.staffBO.name } }
      | reject @id staffBO baseProjectWorkTimeSummaryList Other Surplus
      | move Name --before 理论人天
      | sort-by -r 空闲人天
    )

  if $show_all { $hourSummary | print } else {
    if ($hourSummary | where 空闲人天 > 0 | is-empty) {
      print $'(ansi g)All filled! (char nl)(ansi reset)'
    } else {
      $hourSummary | where 空闲人天 > 0 | print
    }
  }
}

# Query staffs by team code
def query-staffs-by-team [
  code: string,       # Team code
  from: string,       # Start date, like 2023-12-11 00:00:00
  to: string,         # End date, like 2023-12-17 23:59:59
] {
  let emp = get-conf empWorkingHour
  let staffPayload = $emp.staffPayload
      | str replace '_last_day_' $from
      | str replace '_first_day_' $to
      | str replace '_project_code_' $code

  # Week No of now: [(date now)] | dfr into-df | dfr get-week
  let staffs = curl $emp.staffUrl -H $emp.type -s --data-raw $staffPayload | str join

  handle-exception $staffs
  # 此处把中文名字字段过滤掉，否则在Windows下数据传到后端接口会发生解析错误
  let staffPayload = $staffs | from json | get res | select id | to json -r
  let allStaffs = $staffs | from json | get res | select id name | rename id Name
  return { staffPayload: $staffPayload, allStaffs: $allStaffs }
}

# Query working hours of the specified team from EMP and display the filling status of each team member
export def query-hours-by-team [
  team: record,       # Team record, contains name,code,alias,users,etc.
  --debug(-d),        # Print more debug info
  --notify(-n),       # Notify the members who didn't fill the working hours by Dintalk Robot
  --silent(-s),       # Don't print the result
  --show-prev(-p),    # Query working hours of previous week
  --show-all(-a),     # Show all members even if the working hours filled correctly
] {
  let emp = get-conf empWorkingHour
  let monday = get-monday --prev=$show_prev
  let sunday = get-sunday --prev=$show_prev

  if $silent {
    print $'Query working hours from ($monday) to ($sunday) for team (ansi p)($team.name)(ansi reset)'
  } else {
    print $'(char nl)Query working hours from ($monday) to ($sunday) --->'
  }

  let staffs = query-staffs-by-team $team.code $monday $sunday
  let timePayload = $emp.timePayload
      | str replace '_last_day_' $sunday
      | str replace '_first_day_' $monday
      | str replace '_staffs_' $staffs.staffPayload

  let timeSummaryPayload = $emp.timeSummaryPayload
      | str replace '_last_day_' $sunday
      | str replace '_first_day_' $monday
      | str replace '_staffs_' $staffs.staffPayload
      | str replace '_department_' ({id: $team.code} | to json -r)

  let leavePayload = $emp.leavePayload
      | str replace '_last_day_' $sunday
      | str replace '_first_day_' $monday
      | str replace '_staffs_' $staffs.staffPayload

  let allStaffs = $staffs.allStaffs
  let hours = curl $emp.timeUrl -H $emp.type -H $emp.app -s --data-raw $timePayload | str join
  let leaves = curl $emp.leaveUrl -H $emp.type -s --data-raw $leavePayload | str join

  let summary = curl $emp.timeSummaryUrl -H $emp.type -H $emp.app -s --data-raw $timeSummaryPayload | str join
  let hourSummary = (
    $summary | from json | get res | select staffWorkTimeFillResponseList | flatten
      | get staffWorkTimeFillResponseList | where ($it | describe) =~ 'record' and ($it.staffBO?.id | default 0) > 0
      | reject @id | rename --column {
        leavePercentage: leave, otherPercentage: other, theoryPercentage: theory, actualPercentage: actual, surplusPercentage: surplus
    })

  if $debug { log 'hourSummary' ($hourSummary | table -e) }

  let workingHours = $hours | from json | get res
  let workingHours = if ($workingHours | is-empty) {
      $allStaffs | rename -c { id: staffId } | default 0.00 percentage
    } else {(
      $workingHours
        | default 0.00 percentage
        | select percentage fillDate staff
        | upsert staffId { |it| $it.staff.id }
        | reject staff
    )}

  if $debug { log 'allStaffs' $allStaffs; log 'workingHours' $workingHours }
  let leavingHours = $leaves | from json | get res

  # Set a default leaving record
  let leavingHours = if ($leavingHours | is-empty) { [[beginTime, duration, staffId]; [0, 0, 0]] } else {
      $leavingHours | select beginTime duration staff | upsert staffId {|staff| $staff.staff.id } | reject staff
    }

  (
    handle-working-hours $allStaffs $workingHours $leavingHours $hourSummary
                          --team $team --notify=$notify --show-all=$show_all
                          --show-prev=$show_prev --silent=$silent --debug=$debug
  )
}

# 显示工时统计信息
def handle-working-hours [
  allStaffs: table,
  workingHours: table,
  leavingHours: table,
  hourSummary: list,
  --team: record,
  --notify(-n),       # Notify the members who didn't fill the working hours by Dintalk Robot
  --show-all,
  --show-prev,
  --silent,
  --debug,
] {
  let title = $'($team.name)本周工时填报'
  # print ($data | reject id isDeleted week year createdAt updatedAt updatedBy createdBy)
  if not $silent {
    print $'(char nl)  (ansi p)'
    print $'-------------------------> ($title) <-------------------------'
    print $'(ansi reset)(char nl)'
  }
  let week = [Mon, Tue, Wen, Thu, Fri, Sat, Sun]
  # 当前是一年中的第几周
  let weekNo = if $show_prev == true { (date now) - 7day | format date %V } else { date now | format date %V }
  # 此刻是一周中的第几天，周一为第 1 天
  mut weekDay = date now | format date %u | into int
  $weekDay = if $weekDay > 5 { 5 } else { $weekDay }
  let totalDays = $env.WORKDAYS_TILL_MONTH_END? | default '0' | into int
  let totalDays = if $totalDays == 0 { $weekDay } else { $totalDays }
  let isMonthEnd = is-month-end ((date now) + $CHECK_DURATION)

  # Set a default working hour record
  let workingHours = if ($workingHours | compact | length) == 0 { [[fillDate, percentage, staffId]; [0, 0, 0]] } else { $workingHours }

  let hours = $workingHours
      | upsert day { |work|
          if ($work.fillDate? | is-empty) { 'N/A' } else {
            let day = $work.fillDate * 1000_000 | into datetime
            let idx = ([$day] | dfr into-df | dfr get-weekday).0 mod 7
            ($week | select $idx).0
          }
        }
      | upsert Hrs { |work| ($work.percentage * 8) | into int }
      | select staffId day Hrs

  let allMembers = $allStaffs
      | upsert Mon { |staff| get-hr-per-staff $staff.id Mon $hours }
      | upsert Tue { |staff| get-hr-per-staff $staff.id Tue $hours }
      | upsert Wen { |staff| get-hr-per-staff $staff.id Wen $hours }
      | upsert Thu { |staff| get-hr-per-staff $staff.id Thu $hours }
      | upsert Fri { |staff| get-hr-per-staff $staff.id Fri $hours }
      | upsert 'WeekNO.' $weekNo
      | upsert Leave { |staff|
          let leaves = ($leavingHours | where staffId == $staff.id)
          if ($leaves | length) == 0 { 0 } else { ($leaves | get duration | math sum) * 8 | into int }
        }
      | upsert Gap { |staff|
          let staffDetail = $hourSummary | where $it.staffBO.name == $staff.Name | get 0
          let calcRemain = ($totalDays - $staffDetail.actual - $staffDetail.leave) * 8
          if $isMonthEnd { $calcRemain } else { $staffDetail.surplus * 8 }
        }
      | upsert WARN { |it| if ($it.Gap > 0) { $'(ansi r)('*' | fill -a r -w 6 -c $'(char sp)')(ansi reset)' } }
      | sort-by WARN Gap Name
      | reject id

  let result = if $show_all { $allMembers } else { $allMembers | where Gap > 0 }

  if ($result | is-empty) { print $'(ansi g)  Bravo! all filled! Bye...(char nl)(ansi reset)'; return true }

  if not $silent { print $result }
  let empSwitchEnv = $env.EMP_WORKING_HOURS_NOTIFY? | default 'off'
  if $notify and $empSwitchEnv == 'off' {
    print $'WARN: `EMP_WORKING_HOURS_NOTIFY` is (ansi p)off(ansi reset), stop sending notifications...(char nl)'
    return false
  }
  if $notify and $empSwitchEnv == 'on' {
    notify-filling-hours $allMembers --summary $hourSummary --team $team --debug=$debug
  }
  return false
}

# Notify the members who didn't fill the working hours by Dintalk Robot
def notify-filling-hours [hours: any, --summary: list, --team: record, --debug] {
  print 'Try to send notifications by DingTalk Robot...'
  let checkPoint = (date now) + $CHECK_DURATION
  let messages = $env.EMP_CONF | get settings?.messages? | default {}
  # Get monday, ..., friday, saturday, sunday
  let weekday = $checkPoint | format date $_WEEK_FMT | str downcase
  let isMonthEnd = is-month-end $checkPoint
  let isLastDay = $env.LAST_DAY? == 'on'
  # 非周五、六、日、一直接返回
  if not (($weekday in $messages) or $isMonthEnd or $isLastDay) {
    print $'Skip notify at (ansi p)($weekday)(ansi reset)...';
    return $ECODE.SUCCESS
  }
  let users = $team.users? | default []
  valid-user-mobiles $users

  if ($users | is-empty) {
    print $'(ansi y)No users found in team ($team.name), fallback to get users from API...(char nl)(ansi reset)'
  }
  let DINGTALK_KEY = $'($team.alias | str upcase | str replace -a '-' '_')_DINGTALK'
  if $DINGTALK_KEY not-in $env {
    print $'(ansi r)Please set the ($DINGTALK_KEY) in environment variable to send DingTalk notifications...(char nl)(ansi reset)'
    return
  }
  let DINGTALK_AK_SK = $env | get $DINGTALK_KEY | split row ','
  let notifyCandidates = $hours | where Gap > 0
  if $debug { log 'Notify Candidates' $notifyCandidates }
  if ($notifyCandidates | is-empty) {
    print $'(ansi g) All filled! Skip notify...(char nl)(ansi reset)'
    return
  }

  let message = $messages | get -i $weekday | default $messages.monthEnd
  let message = if $isLastDay { $env.LASTDAY_MSG? | default $DEFAULT_LASTDAY_MSG } else { $message }
  let notifyCount = $notifyCandidates | length
  load-env { DINGTALK_ROBOT_AK: $DINGTALK_AK_SK.0, DINGTALK_ROBOT_SECRET: $DINGTALK_AK_SK.1, DINGTALK_NOTIFY: 'on' }
  if ($notifyCount == ($hours | length) or $notifyCount >= ($team.atAllMinCount? | default 30)) {
    dingtalk notify --text $message --at-all; return
  }
  let mentions = $notifyCandidates | upsert Mobile {|m|
    let mobileFetched = $summary | where $it.staffBO.name == $m.Name | get 0 | get staffBO.phone
    let mobileFilled = $users | where name == $m.Name | get -i 0 | get -i mobile
    ($mobileFilled | default $mobileFetched)
  }
  if $debug { log 'mentions' $mentions }
  let mobiles = $mentions | get Mobile | str join ','
  dingtalk notify --text $message --at-mobiles $mobiles
}

# Validate the mobile number of each user, display a warning message if the mobile is invalid
def valid-user-mobiles [users: any] {
  if ($users | is-empty) { return }
  for user in $users {
    let valid = $user.mobile | str replace -r '1\d{10}' '' | is-empty
    if not $valid {
      print $'WARNING: (ansi r)($user.name)(ansi reset) has invalid mobile number (ansi r)($user.mobile)(ansi reset), please check it again...'
    }
  }
}

def get-hr-per-staff [
  id: int,
  weekDay: string,
  hours: any,
] {
  let hour = $hours | default 'N/A' day | where staffId == $id and day == $weekDay
  if ($hour | length) == 0 { 0 } else { ($hour | select 0).0.Hrs }
}

# Get the beginning time of monday, like 2021-12-06 00:00:00
def get-monday [
  --prev
] {
  let today = date now | format date %u | into int
  let monday = (date now) - ($'($today - 1)day' | into duration )
  let beginOfMonday = $monday | format date '%Y-%m-%d 00:00:00' | into datetime
  let queryBegin = if $prev == true { $beginOfMonday - 7day } else { $beginOfMonday }
  ($queryBegin | format date $_TIME_FMT)
}

# Get the ending time of sunday, like 2021-12-12 23:59:59
def get-sunday [
  --prev
] {
  let sunday = (get-monday | into datetime) + 7day - 1sec
  let sunday = if $prev == true { $sunday - 7day } else { $sunday }
  ($sunday | format date $_TIME_FMT)
}

# 判断是否是月底
def is-month-end [time: datetime] {
  ($time | format date $_MONTH_FMT) != (($time + 1day) | format date $_MONTH_FMT)
}

# 处理未登录、超时、服务器错误等
def handle-exception [
  res: string
] {

  # 未登录或者Cookie过期提示, use `do -i` to ignore 'error: Coercion error'
  do -i {
    if ($res | is-empty) or ($res | from json | get status) == 401 {
      print $'(ansi r)You did`t have permission to call this API !(char nl)(ansi reset)'
      exit $ECODE.AUTH_FAILED
    }
    if (($res | from json | get status) == 500) {
      print $'(ansi r)Backend internal server error，please try again later!(char nl)(ansi reset)'
      exit $ECODE.SERVER_ERROR
    }
  }
}

alias main = working-hours-daily-checking
