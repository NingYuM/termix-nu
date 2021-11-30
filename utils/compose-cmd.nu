# Author: hustcer
# Created: 2021/10/03 09:39:52

# Compose command with the shell to execute it
def 'compose-cmd' [
  cmd: string       # The command to compose
] {
  let actionConf = (open $TERMIX_CONF | to json)
  # 先从环境变量里面查找用于执行命令的 shell 及其相关配置
  let selectedShellOfEnv = (get-env SHELL_TO_RUN_CMD)
  let shellOption = ($actionConf | query json $'shellToRunCmd.($selectedShellOfEnv)')
  # '------------------ Before ------------------'; char nl
  # 'Selected shell from .env: '; echo $selectedShellOfEnv; char nl
  # $'Shell options: ($shellOption)'; char nl
  if ($selectedShellOfEnv != '' && $shellOption != '') {
    # $'Run command with ($selectedShellOfEnv) from .env conf:(char nl)'
    # Output / return composed command
    echo $"($selectedShellOfEnv) ($shellOption) '($cmd)'"
  } {
    # 如果环境变量里面没有找到则从 termix.toml 里面查找 shell 及其参数
    let selectedShell = ($actionConf | query json 'shellToRunCmd.currentSelected')
    # echo $'Run command with ($selectedShell) from termix.toml conf:(char nl)'
    let shellOption = ($actionConf | query json $'shellToRunCmd.($selectedShell)')
    echo $"($selectedShell) ($shellOption) '($cmd)'"
  }
  # char nl; '------------------ After ------------------'
}
