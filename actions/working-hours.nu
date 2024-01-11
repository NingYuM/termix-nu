#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/22 15:36:56
# Description: Check working hours filling status
#   [√] Query working hours for muliple teams
#   [√] Query working hours of previous week
#   [ ] Notify the members who didn't fill the working hours by Dintalk Robot
#   [ ] Add a config file to store the EMP_PROJECT_CODE, EMP_WORKING_HOUR_TITLE, etc.
#   [ ] Add a crontab config example to run this script automatically
#   [ ] Create a docker image to run this script in Erda pipeline
#   [ ] Update the docs
# Usage:
#   t emp
# Data Source
#   https://emp.app.terminus.io/view/worktime_WorkTimeBO_DepartmentWorkTime

use ../utils/common.nu [ECODE, get-conf, get-env]

const _TIME_FMT = '%Y-%m-%d %H:%M:%S'

# Query working hours from EMP and display the filling status of each team member
export def query-hours-by-team-codes [
  codes: string,      # Team codes, like '123,567,890'
  --show-all(-a),     # Show all members even if the working hours filled correctly
  --show-prev(-p),    # Query working hours of previous week
  --notify(-n),       # Notify the members who didn't fill the working hours by Dintalk Robot
] {
  if ($codes | is-empty) {
    print $'(ansi r)Not enough parameters, make sure you have set the EMP_PROJECT_CODE var in .env file, bye...(char nl)(ansi reset)'
    exit $ECODE.INVALID_PARAMETER
  }
  $codes | split row ',' | each { |it|
    query-hours-by-team-code $it --show-all=$show_all --show-prev=$show_prev --notify=$notify
  } | ignore
}

export def query-hours-by-team-code [
  code: string,       # Team code, like '123'
  --show-all(-a),     # Show all members even if the working hours filled correctly
  --show-prev(-p),    # Query working hours of previous week
  --notify(-n),       # Notify the members who didn't fill the working hours by Dintalk Robot
] {

  let monday = get-monday --prev=$show_prev
  let sunday = get-sunday --prev=$show_prev
  let emp = get-conf empWorkingHour
  let staffPayload = ($emp.staffPayload
      | str replace '_last_day_' $sunday
      | str replace '_first_day_' $monday
      | str replace '_project_code_' $code
    )
  # Week No of now: [(date now)] | dfr into-df | dfr get-week
  let staffs = (curl $emp.staffUrl -H $emp.type -s --data-raw $staffPayload | str join)

  handle-exception $staffs

  print $'(char nl)Query working hours from ($monday) to ($sunday) --->'
  # 此处把中文名字字段过滤掉，否则在Windows下数据传到后端接口会发生解析错误
  let staffPayload = ($staffs | query json 'res' | select id | to json -r)
  let timePayload = ($emp.timePayload
      | str replace '_last_day_' $sunday
      | str replace '_first_day_' $monday
      | str replace '_staffs_' $staffPayload
    )

  let leavePayload = ($emp.leavePayload
      | str replace '_last_day_' $sunday
      | str replace '_first_day_' $monday
      | str replace '_staffs_' $staffPayload
    )

  let allStaffs = ($staffs | query json 'res' | select id name | rename id Name)
  let hours = (curl $emp.timeUrl -H $emp.type -H $emp.app -s --data-raw $timePayload | str join)
  let leaves = (curl $emp.leaveUrl -H $emp.type -s --data-raw $leavePayload | str join)
  let workingHours = ($hours | query json 'res')
  let workingHours = if ($workingHours | is-empty) { null } else {(
      $workingHours
        | default 0.00 percentage
        | select percentage fillDate staff
        | upsert staffId { |it| $it.staff.id }
        | reject staff
    )}

  let leavingHours = ($leaves | query json 'res')

  # Set a default leaving record
  let leavingHours = if ($leavingHours | is-empty) { [[beginTime, duration, staffId]; [0, 0, 0]] } else {
      (
        $leavingHours
          | select beginTime duration staff
          | upsert staffId {|staff| $staff.staff.id }
          | reject staff
      )
    }

  handle-working-hours $allStaffs $workingHours $leavingHours --show-all=$show_all --show-prev=$show_prev
}

# 显示工时统计信息
def handle-working-hours [
  allStaffs: any,
  workingHours: any,
  leavingHours: any,
  --show-all,
  --show-prev,
] {
  let title = (get-env EMP_WORKING_HOUR_TITLE '本周工时填报')
  # echo ($data | reject id isDeleted week year createdAt updatedAt updatedBy createdBy)
  print $'(char nl)  (ansi p)'
  print $'-------------------------> ($title) <-------------------------'
  print $'(ansi reset)(char nl)'
  let week = [Mon, Tue, Wen, Thu, Fri, Sat, Sun]
  # 当前是一年中的第几周
  let weekNo = if $show_prev == true { ([((date now) - 7day)] | dfr into-df | dfr get-week).0 } else { ([(date now)] | dfr into-df | dfr get-week).0 }
  # 此刻是一周中的第几天，周一为第 0 天
  let weekDay = ([(date now)] | dfr into-df | dfr get-weekday).0
  # 正常情况下一周工作 5 天
  let total = if ($weekDay >= 5 or $show_prev == true) { 5 } else { $weekDay }

  # Set a default working hour record
  let workingHours = if ($workingHours | compact | length) == 0 { [[fillDate, percentage, staffId]; [0, 0, 0]] } else { $workingHours }

  let hours = ($workingHours | upsert day { |work|
        let day = ($work.fillDate * 1000_000 | into datetime)
        let idx = ([$day] | dfr into-df | dfr get-weekday).0 mod 7
        ($week | select $idx).0
      } | upsert Hrs { |work|
        ($work.percentage * 8) | into int
      } | select staffId day Hrs
    )

  let allMembers = ($allStaffs
      | upsert Mon { |staff| (get-hr-per-staff $staff.id 'Mon' $hours) }
      | upsert Tue { |staff| (get-hr-per-staff $staff.id 'Tue' $hours) }
      | upsert Wen { |staff| (get-hr-per-staff $staff.id 'Wen' $hours) }
      | upsert Thu { |staff| (get-hr-per-staff $staff.id 'Thu' $hours) }
      | upsert Fri { |staff| (get-hr-per-staff $staff.id 'Fri' $hours) }
      | upsert 'WeekNO.' $weekNo
      | upsert Leave { |staff|
        let leaves = ($leavingHours | where staffId == $staff.id)
        if ($leaves | length) == 0 { 0 } else { ($leaves | get duration | math sum) * 8 | into int }
      } | reject id
    )

  let result = (if $show_all { $allMembers } else {
    ($allMembers | where { |it| $it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8 })
  })

  if ($result | is-empty) { print $'(ansi g)  Bravo! all filled! Bye...(char nl)(ansi reset)'; exit $ECODE.SUCCESS }

  let hourMap = (
    $result | upsert Gap { |it| $total * 8 - ($it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave) }
      | upsert WARN { |it|
          if ($it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8) {
            $'(ansi r)('*' | fill -a r -w 6 -c $'(char sp)')(ansi reset)'
          }
        }
      | sort-by WARN Gap Name
    )
  print $hourMap
}

# Get the beginning time of monday, like 2021-12-06 00:00:00
def get-monday [
  --prev
] {
  let today = (date now | date to-table | select year month day)
  let pastDays = ([(date now)] | dfr into-df | dfr get-weekday).0 - 1
  let duration = ($'($pastDays)day' | into duration)
  let beginOfToday = ($'($today.year.0)-($today.month.0)-($today.day.0)' | into datetime)
  let beginOfToday = if $prev == true { $beginOfToday - 7day } else { $beginOfToday }
  (($beginOfToday - $duration) | format date $_TIME_FMT)
}

# Get the ending time of sunday, like 2021-12-12 23:59:59
def get-sunday [
  --prev
] {
  let sunday = ((get-monday | into datetime) + 7day - 1sec)
  let sunday = if $prev == true { $sunday - 7day } else { $sunday }
  ($sunday | format date $_TIME_FMT)
}

def get-hr-per-staff [
  id: string,
  weekDay: string,
  hours: any,
] {
  let hour = ($hours | where staffId == $id and day == $weekDay)
  if ($hour | length) == 0 { 0 } else { ($hour | select 0).0.Hrs }
}

# 处理未登录、超时、服务器错误等
def handle-exception [
  res: string
] {

  # 未登录或者Cookie过期提示, use `do -i` to ignore 'error: Coercion error'
  do -i {
    if ($res | is-empty) or ($res | query json 'status') == 401 {
      print $'(ansi r)You did`t have permission to call this API !(char nl)(ansi reset)'
      exit $ECODE.AUTH_FAILED
    }
    if (($res | query json 'status') == 500) {
      print $'(ansi r)Backend internal server error，please try again later!(char nl)(ansi reset)'
      exit $ECODE.SERVER_ERROR
    }
  }
}
