# Author: hustcer
# Created: 2021/10/22 15:36:56
# Description: Check working hours filling status
# Usage:
#   working-hours
# Data Source
#   https://gateway.app.terminus.io/compass/emp/emp-project/api/trantor/data-source

def 'working-hours' [
  --show-all: string   # Set true to show all members even if the working hours filled correctly
] {

  let emp = (open $'($nu.env.TERMIX_DIR)/termix.toml' | get empWorkingHour)
  let outerId = (get-env EMP_OUTER_ID '')
  # 先从环境变量里面查找用户在 emp Cookie 里面的登陆信息
  let empUserCookie = (get-env EMP_UC_COOKIE '')
  if ($outerId == '' || $empUserCookie == '') {
    $'(ansi r)Not enough parameters, make sure you have set the EMP_UC_COOKIE and EMP_OUTER_ID var in .env file, bye...(char nl)(ansi reset)'
    exit --now
  } {}
  let title = (get-env EMP_WORKING_HOUR_TITLE '本周工时填报')
  let userCookie = ($emp.cookie | str find-replace '_EMP_UC_COOKIE_' $empUserCookie)
  let year = (date to-table).year
  # 当前是一年中的第几周
  let weekNo = ([(date now)] | dataframe to-df | dataframe get-week).0
  # 此刻是一周中的第几天，周一为第 0 天
  let weekDay = ([(date now)] | dataframe to-df | dataframe get-weekday).0
  # 正常情况下一周工作 5 天
  let total = (if $weekDay >= 5 { 5 } { $weekDay + 1 })
  let payload = ($emp.payload | str find-replace '_week_no_' $'($weekNo)' |
      str find-replace '_outer_id_' $'($outerId)' | str find-replace '_current_year_' $'($year)' )
  # Week No of now: [(date now)] | dataframe to-df | dataframe get-week
  let hours = (curl $emp.url -H $emp.type -H $userCookie -s --data-raw $payload | str collect)

  handle-exception $hours
  handle-working-hours $hours
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

# 显示工时统计信息
def 'handle-working-hours' [
  res: string
] {

  let data = ($res | query json 'res.data')
  # echo ($data | reject id isDeleted week year createdAt updatedAt updatedBy createdBy)
  $'(char nl)  (ansi p)'
  $'-------------------------> ($title) <-------------------------'
  $'(ansi reset)(char nl)(char nl)'
  let allMembers = ($data |
    select staff.name mondayWorkTime tuesdayWorkTime wednesdayWorkTime thursdayWorkTime fridayWorkTime week leavePercentage |
    rename Name Mon Tue Wen Thu Fri WeekNO. Leave |
    default Mon 0 | update Mon { |it| $it.Mon * 8 | into int } |
    default Tue 0 | update Tue { |it| $it.Tue * 8 | into int } |
    default Wen 0 | update Wen { |it| $it.Wen * 8 | into int } |
    default Thu 0 | update Thu { |it| $it.Thu * 8 | into int } |
    default Fri 0 | update Fri { |it| $it.Fri * 8 | into int } |
    update Leave { |it| $it.Leave * 8 | into int })

  let result = (if ($show-all == 'true') { $allMembers } {
    # ($allMembers | where Mon < 8 || Tue < 8 || Wen < 8 || Thu < 8 || Fri < 8)
    ($allMembers | where { |it| $it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8 })
  })

  do -i { # Ignore `error: Coercion error`
    if ($result == $nothing) { $'(ansi g)  Bravo! all filled! Bye...(char nl)(ansi reset)'; exit --now } {}
  }

  $result | insert WARN { |it|
    if ($it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < $total * 8) {
      $'(ansi r)('*' | str lpad -l 6 -c $'(char sp)')(ansi reset)'
    } {}
  } | sort-by -r WARN Name
}
