
### Adapt to nushell v0.60.0

.
├── [x] Justfile
├── [ ] actions
│   ├── [x] brew-speed-up.nu
│   ├── [x] check-ver.nu        // Variable Capture: https://github.com/nushell/nushell/issues/4402
│   ├── [*] dir-batch-exec.nu   // `to json`转换错误: https://github.com/nushell/nushell/issues/4403
│   ├── [?] gaia-release.nu     // Match 现在还不支持: https://github.com/nushell/nushell/issues/4356
│   ├── [x] ls-node.nu
│   ├── [x] ls-redev-refs.nu
│   ├── [x] prune-synced-branches.nu
│   ├── [x] pull-redev.nu
│   ├── [x] quick-nav.nu        // Variable Capture: https://github.com/nushell/nushell/issues/4402
│   ├── [x] release.nu
│   ├── [x] show-env.nu
│   ├── [*] tag-redev.nu        // glob expansion错误: https://github.com/nushell/nushell/issues/4404
│   ├── [x] upgrade
│   └── [?] working-hours.nu    // `to json`转换错误: https://github.com/nushell/nushell/issues/4403
├── [ ] git
│   ├── [x] age.nu
│   ├── [x] branch-desc.nu      // `to json`转换错误: https://github.com/nushell/nushell/issues/4403
│   ├── [x] check-desc.nu       // `to json`转换错误: https://github.com/nushell/nushell/issues/4403
│   ├── [*] git-batch-exec.nu   // `to json`转换错误: https://github.com/nushell/nushell/issues/4403
│   ├── [x] git-batch-reset.nu
│   ├── [x] git-proxy.nu
│   ├── [*] pull-all.nu         // 终端输入异常: https://github.com/nushell/nushell/issues/4384
│   ├── [x] remote-age.nu
│   ├── [x] rename-branch.nu
│   ├── [*] repo-transfer.nu    // glob expansion错误: https://github.com/nushell/nushell/issues/4404
│   ├── [x] sync-branch.nu
│   └── [x] trigger-sync.nu
├── [ ] mall
│   └── [x] clean-locale.nu
├── [ ] run
│   ├── [x] git.nu
│   ├── [ ] merge-perf.nu
│   ├── [ ] merge.nu
│   ├── [x] set-git-alias.nu
│   ├── [ ] setup-conf.nu
│   ├── [ ] setup-mac.nu
│   └── [x] ts-stat.nu
├── [x] termix.toml
└── [ ] utils
    ├── [ ] common.nu
    ├── [?] compose-cmd.nu      // `to json`转换错误: https://github.com/nushell/nushell/issues/4403
    └── [x] git.nu
