# Author: hustcer
# Created: 2021/10/22 15:36:56
# Description: Check working hours filling status
# Usage:
#   working-hours
# Data Source
#   https://emp.app.terminus.io/view/worktime_WorkTimeBO_DepartmentWorkTime

def 'working-hours' [
  --show-all: string   # Set true to show all members even if the working hours filled correctly
] {

  let monday = (get-monday)
  let sunday = (get-sunday)
  let emp = (get-conf empWorkingHour)
  let code = (get-env EMP_PROJECT_CODE '')
  # 先从环境变量里面查找用户在 emp Cookie 里面的登陆信息
  let empUserCookie = (get-env EMP_UC_COOKIE '')
  if ($code == '' || $empUserCookie == '') {
    $'(ansi r)Not enough parameters, make sure you have set the EMP_UC_COOKIE and EMP_PROJECT_CODE var in .env file, bye...(char nl)(ansi reset)'
    exit --now
  } {}
  let title = (get-env EMP_WORKING_HOUR_TITLE '本周工时填报')
  let userCookie = ($emp.cookie | str find-replace '_EMP_UC_COOKIE_' $empUserCookie)
  let staffPayload = ($emp.staffPayload | str find-replace '_first_day_' $monday |
      str find-replace '_last_day_' $sunday |
      str find-replace '_project_code_' $code )
  # Week No of now: [(date now)] | dataframe to-df | dataframe get-week
  let staffs = (curl $emp.staffUrl -H $emp.type -H $userCookie -s --data-raw $staffPayload | str collect)

  handle-exception $staffs

  $'Query working hours from ($monday) to ($sunday) ---> (char nl)'
  let timePayload = ($emp.timePayload |
      str find-replace '_first_day_' $monday |
      str find-replace '_last_day_' $sunday |
      str find-replace '_staffs_' ($staffs | query json 'res' | to json))

  let leavePayload = ($emp.leavePayload |
      str find-replace '_first_day_' $monday |
      str find-replace '_last_day_' $sunday |
      str find-replace '_staffs_' ($staffs | query json 'res' | to json))

  let allStaffs = ($staffs | query json 'res' | select id name | rename id Name)
  let hours = (curl $emp.timeUrl -H $emp.type -H $emp.app -H $userCookie -s --data-raw $timePayload | str collect)
  let leaves = (curl $emp.leaveUrl -H $emp.type -H $userCookie -s --data-raw $leavePayload | str collect)
  let workingHours = (
      $hours | query json 'res'| select fillDate percentage staff |
        insert staffId { get staff | each { $it.id } } | reject staff
    )
  let leavingHours = (
      $leaves | query json 'res'| select beginTime duration staff |
        insert staffId { get staff | each { $it.id } } | reject staff
    )

  # Set a default leaving record
  let leavingHours = (if ($leavingHours | compact | length) == 0 { [[beginTime, duration, staffId]; [0, 0, 0]] } { $leavingHours })

  handle-working-hours $allStaffs $workingHours $leavingHours
}

# 显示工时统计信息
def 'handle-working-hours' [
  staffs: any
  workingHours: any
  leavingHours: any
] {

  # echo ($data | reject id isDeleted week year createdAt updatedAt updatedBy createdBy)
  $'(char nl)  (ansi p)'
  $'-------------------------> ($title) <-------------------------'
  $'(ansi reset)(char nl)(char nl)'
  let week = [Mon, Tue, Wen, Thu, Fri, Sat, Sun]
  # 当前是一年中的第几周
  let weekNo = ([(date now)] | dataframe to-df | dataframe get-week).0
  # 此刻是一周中的第几天，周一为第 0 天
  let weekDay = ([(date now)] | dataframe to-df | dataframe get-weekday).0
  # 正常情况下一周工作 5 天
  let total = (if $weekDay >= 5 { 5 } { $weekDay + 1 })

  # Set a default working hour record
  let workingHours = (if ($workingHours | compact | length) == 0 { [[fillDate, percentage, staffId]; [0, 0, 0]] } { $workingHours })

  let hours = ($workingHours | insert day {
        get fillDate | each {
          let day = (($it / 1000) | into string | str to-datetime -o 8)
          let idx = ((([$day] | dataframe to-df | dataframe get-weekday).0 + 1) mod 7)
          echo ($week | nth $idx)
        }
      } | insert Hrs {
        get percentage | each { ($it * 8) | into int }
      } | select staffId day Hrs
    )

  let allMembers = ($allStaffs |
      insert Mon { get id | each { |id| (get-hr-per-staff $id 'Mon') } } |
      insert Tue { get id | each { |id| (get-hr-per-staff $id 'Tue') } } |
      insert Wen { get id | each { |id| (get-hr-per-staff $id 'Wen') } } |
      insert Thu { get id | each { |id| (get-hr-per-staff $id 'Thu') } } |
      insert Fri { get id | each { |id| (get-hr-per-staff $id 'Fri') } } |
      insert 'WeekNO.' $weekNo |
      insert Leave {
        get id | { each { |id|
          let leaves = ($leavingHours | where staffId == $id)
          # FIXME: Very hackable here, `nth 0` is required
          if ($leaves | empty? | nth 0) { 0 } { ($leaves | get duration | math sum) * 8 | into int }
        }}
      } | reject id
    )

  let result = (if ($show-all == 'true') { $allMembers } {
    ($allMembers | where { |it| $it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8 })
  })

  do -i { # Ignore `error: Coercion error`
    if ($result == $nothing) { $'(ansi g)  Bravo! all filled! Bye...(char nl)(ansi reset)'; exit --now } {}
  }

  $result | insert Gap { $total * 8 - ($it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave) } |
    insert WARN { |it|
      if ($it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8) {
        $'(ansi r)('*' | str lpad -l 6 -c $'(char sp)')(ansi reset)'
      } {}
    } | sort-by -r WARN Gap Name
}

# Get the beginning time of monday, like 2021-12-06 00:00:00
def 'get-monday' [] {
  let today = (date to-table|select year month day)
  # Currently convert string to duration is not supported
  let durations = [0day, 1day, 2day, 3day, 4day, 5day, 6day]
  let weekDay = ([(date now)] | dataframe to-df | dataframe get-weekday).0
  let beginOfToday = ($'($today.year)-($today.month)-($today.day)' | str to-datetime)
  echo (($beginOfToday - ($durations | nth $weekDay)) | date format $_TIME_FMT)
}

# Get the ending time of sunday, like 2021-12-12 23:59:59
def 'get-sunday' [] {
  let sunday = (((get-monday) | str to-datetime) + 7day - 1sec)
  echo ($sunday | date format $_TIME_FMT)
}

def 'get-hr-per-staff' [
  id: string
  weekDay: string
] {
  let hour = ($hours | where staffId == $id && day == $weekDay)
  if ($hour | empty?) { 0 } { ($hour | nth 0).Hrs }
}

# 处理未登录、超时、服务器错误等
def 'handle-exception' [
  res: string
] {

  # 未登录或者Cookie过期提示, use `do -i` to ignore 'error: Coercion error'
  do -i {
    if (($res | query json 'status') == 401) {
      $'(ansi r)Your login COOKIE info is outdated or empty，please update it and try again!(char nl)(ansi reset)'
      exit --now
    } {}
    if (($res | query json 'status') == 500) {
      $'(ansi r)Backend internal server error，please try again later!(char nl)(ansi reset)'
      exit --now
    } {}
  }
}
