#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/22 15:36:56
# Description: Check working hours filling status
# Usage:
#   working-hours
# Data Source
#   https://emp.app.terminus.io/view/worktime_WorkTimeBO_DepartmentWorkTime

def 'working-hours' [
  code: string
  --show-all: any   # Set true to show all members even if the working hours filled correctly
  --show-prev: any   # Set true to query working hours of previous week
] {

  let monday = get-monday --prev=$show-prev
  let sunday = get-sunday --prev=$show-prev
  let emp = get-conf empWorkingHour
  # 先从环境变量里面查找用户在 emp Cookie 里面的登陆信息
  let empUserCookie = get-env EMP_UC_COOKIE ''
  if ($code == '' || $empUserCookie == '') {
    $'(ansi r)Not enough parameters, make sure you have set the EMP_UC_COOKIE and EMP_PROJECT_CODE var in .env file, bye...(char nl)(ansi reset)'
    exit --now
  }
  let userCookie = ($emp.cookie | str replace '_EMP_UC_COOKIE_' $empUserCookie)
  let staffPayload = ($emp.staffPayload
      | str replace '_last_day_' $sunday
      | str replace '_first_day_' $monday
      | str replace '_project_code_' $code
    )
  # Week No of now: [(date now)] | into df | get-week
  let staffs = (curl $emp.staffUrl -H $emp.type -H $userCookie -s --data-raw $staffPayload | str collect)

  handle-exception $staffs

  $'(char nl)Query working hours from ($monday) to ($sunday) --->'
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
  let hours = (curl $emp.timeUrl -H $emp.type -H $emp.app -H $userCookie -s --data-raw $timePayload | str collect)
  let leaves = (curl $emp.leaveUrl -H $emp.type -H $userCookie -s --data-raw $leavePayload | str collect)
  let workingHours = (
      $hours
        | query json 'res'
        | default 0.00 percentage
        | select percentage fillDate staff
        | upsert staffId { |it| $it.staff.id }
        | reject staff
    )

  let leavingHours = (
      $leaves | query json 'res'| select beginTime duration staff
        | upsert staffId {|staff| $staff.staff.id } | reject staff
    )

  # Set a default leaving record
  let leavingHours = if ($leavingHours | compact | length) == 0 { [[beginTime, duration, staffId]; [0, 0, 0]] } else { $leavingHours }

  handle-working-hours $allStaffs $workingHours $leavingHours --show-all=$show-all --show-prev=$show-prev
}

# 显示工时统计信息
def 'handle-working-hours' [
  allStaffs: any
  workingHours: any
  leavingHours: any
  --show-all: any
  --show-prev: any
] {

  let title = get-env EMP_WORKING_HOUR_TITLE '本周工时填报'
  # echo ($data | reject id isDeleted week year createdAt updatedAt updatedBy createdBy)
  $'(char nl)  (ansi p)'
  $'-------------------------> ($title) <-------------------------'
  $'(ansi reset)(char nl)'
  let week = [Mon, Tue, Wen, Thu, Fri, Sat, Sun]
  # 当前是一年中的第几周
  let weekNo = if $show-prev == true { ([((date now) - 7day)] | into df | get-week).0 } else { ([(date now)] | into df | get-week).0 }
  # 此刻是一周中的第几天，周一为第 0 天
  let weekDay = ([(date now)] | into df | get-weekday).0
  # 正常情况下一周工作 5 天
  let total = if ($weekDay >= 5 || $show-prev == true) { 5 } else { $weekDay + 1 }

  # Set a default working hour record
  let workingHours = if ($workingHours | compact | length) == 0 { [[fillDate, percentage, staffId]; [0, 0, 0]] } else { $workingHours }

  let hours = ($workingHours | upsert day { |work|
        let day = (($work.fillDate / 1000) | into string | into datetime -o 8)
        let idx = (([$day] | into df | get-weekday).0 mod 7)
        echo ($week | select $idx).0
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

  let result = (if $show-all { $allMembers } else {
    ($allMembers | where { |it| $it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8 })
  })

  if ($result | empty?) { $'(ansi g)  Bravo! all filled! Bye...(char nl)(ansi reset)'; exit --now }

  let hourMap = (
    $result | upsert Gap { |it| $total * 8 - ($it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave) }
      | upsert WARN { |it|
          if ($it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8) {
            $'(ansi r)('*' | str lpad -l 6 -c $'(char sp)')(ansi reset)'
          }
        }
      | sort-by WARN Gap Name
    )
  print $hourMap
}

# Get the beginning time of monday, like 2021-12-06 00:00:00
def 'get-monday' [
  --prev: any
] {
  let today = (date to-table | select year month day)
  let weekDay = ([(date now)] | into df | get-weekday).0
  let duration = ($'($weekDay)day' | into duration)
  let beginOfToday = ($'($today.year.0)-($today.month.0)-($today.day.0)' | into datetime)
  let beginOfToday = if $prev == true { $beginOfToday - 7day } else { $beginOfToday }
  echo (($beginOfToday - $duration) | date format $_TIME_FMT)
}

# Get the ending time of sunday, like 2021-12-12 23:59:59
def 'get-sunday' [
  --prev: any
] {
  let sunday = (((get-monday) | into datetime) + 7day - 1sec)
  let sunday = if $prev == true { $sunday - 7day } else { $sunday }
  echo ($sunday | date format $_TIME_FMT)
}

def 'get-hr-per-staff' [
  id: string
  weekDay: string
  hours: any
] {
  let hour = ($hours | where staffId == $id && day == $weekDay)
  if ($hour | length) == 0 { 0 } else { ($hour | select 0).0.Hrs }
}

# 处理未登录、超时、服务器错误等
def 'handle-exception' [
  res: string
] {

  # 未登录或者Cookie过期提示, use `do -i` to ignore 'error: Coercion error'
  do -i {
    if ($res | empty?) || ($res | query json 'status') == 401 {
      $'(ansi r)Your login COOKIE info is outdated or empty，please update it and try again!(char nl)(ansi reset)'
      exit --now
    }
    if (($res | query json 'status') == 500) {
      $'(ansi r)Backend internal server error，please try again later!(char nl)(ansi reset)'
      exit --now
    }
  }
}
