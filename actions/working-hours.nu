# Author: hustcer
# Created: 2021/10/22 15:36:56
# Description: Check working hours filling status
# Usage:
#   working-hours
# Data Source
#   https://gateway.app.terminus.io/compass/emp/emp-project/api/trantor/data-source

def 'working-hours' [] {
    let emp = (open $'($nu.env.TERMIX_DIR)/termix.toml' | get empWorkingHour)
    # 先从环境变量里面查找用户在 emp Cookie 里面的登陆信息
    let empUserCookie = (get-env EMP_UC_COOKIE)
    let userCookie = ($emp.cookie | str find-replace '_EMP_UC_COOKIE_' $empUserCookie)
    let weekNo = ([(date now)] | dataframe to-df | dataframe get-week).0
    let payload = ($emp.payload | str find-replace '_week_no_' $'($weekNo)')
    # Week No of now: [(date now)] | dataframe to-df | dataframe get-week
    let hours = (curl $emp.url -H $emp.type -H $userCookie -s --data-raw $payload | str collect)
    let data = ($hours | query json 'res.data')
    # echo ($data | reject id isDeleted week year createdAt updatedAt updatedBy createdBy)
    $'(char nl)  (ansi p)'
    $'-------------------------> 电商前端本周工时填报 <-------------------------'
    $'(ansi reset)(char nl)(char nl)'
    $data |
      select staff.name mondayWorkTime tuesdayWorkTime wednesdayWorkTime thursdayWorkTime fridayWorkTime week leavePercentage |
      rename Name Mon Tue Wen Thu Fri WeekNO. Leave |
      default Mon 0 | update Mon { |it| $it.Mon * 8 | into int } |
      default Tue 0 | update Tue { |it| $it.Tue * 8 | into int } |
      default Wen 0 | update Wen { |it| $it.Wen * 8 | into int } |
      default Thu 0 | update Thu { |it| $it.Thu * 8 | into int } |
      default Fri 0 | update Fri { |it| $it.Fri * 8 | into int } |
      update Leave { |it| $it.Leave * 8 | into int } |
      where Mon < 8 || Tue < 8 || Wen < 8 || Thu < 8 || Fri < 8 |
      insert Warn { |it|
        if ( $it.Mon + $it.Tue + $it.Wen + $it.Thu + $it.Fri + $it.Leave < 40) {
            $'(ansi r)('*' | str lpad -l 6 -c $'(char sp)')(ansi reset)'
        } {}
      }
}
