# Concate nate file by nu.
[(open ./git/git-batch-exec.nu) $'(char nl)' (open ./utils/compose-cmd.nu)] |
    str collect |
    save run/.git-batch-exec-compose.nu
