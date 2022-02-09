# Author: hustcer
# Created: 2021/10/05 09:36:56
# To beautify toml file: code (config path) --> Format in VS Code --> Save
# Usage:
#   nu actions/setup-conf.nu
# REF:
#   https://www.nushell.sh/book/configuration.html

def 'setup-conf' [] {

    $'Current config path: `(config path)`'
    config set ctrlc_exit $true
    config set table_mode 'light'
    config set prompt 'starship_prompt'
    config set line_editor.edit_mode 'vim'
    # config remove line_editor.edit_mode
    echo [
        'mkdir ~/.cache/starship',
        'starship init nu | save ~/.cache/starship/init.nu',
        'source ~/.cache/starship/init.nu',
        'zoxide init nushell --hook prompt | save ~/.zoxide.nu',
        'source ~/.zoxide.nu',
        'alias ll = ls --long',
    ] | config set_into startup

    # config set startup (
    #     config get startup |
    #     append 'alias nuopen = open' |
    #     append 'alias open = ^open' |
    #     append 'alias ll = ls --long'
    # )

    # config set env  $env
    config set path $nu.path

    $'Config file content as below:'
    bat (config path)
}

setup-conf
