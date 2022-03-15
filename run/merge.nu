#!/usr/bin/env nu
# Concate nate file by nu.
[(open --raw ./git/git-batch-exec.nu) $'(char nl)' (open --raw ./utils/compose-cmd.nu)] |
    str collect |
    save --raw run/.git-batch-exec-compose.nu
