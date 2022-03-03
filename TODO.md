
### Adapt to Nushell v0.60.0

```shell
.
├── [x] Justfile
├── [ ] actions
│   ├── [x] [x] brew-speed-up.nu
│   ├── [x] [ ] check-ver.nu
│   ├── [*] [x] dir-batch-exec.nu
│   ├── [x] [x] gaia-release.nu
│   ├── [x] [x] ls-node.nu
│   ├── [x] [x] ls-redev-refs.nu
│   ├── [x] [x] prune-synced-branches.nu
│   ├── [x] [x] pull-redev.nu
│   ├── [x] [x] quick-nav.nu
│   ├── [x] [ ] release.nu
│   ├── [x] [x] show-env.nu
│   ├── [*] [x] tag-redev.nu        # glob expansion错误: https://github.com/nushell/nushell/issues/4404
│   ├── [x] [x] upgrade
│   └── [x] [x] working-hours.nu
├── [ ] git
│   ├── [x] [x] age.nu
│   ├── [x] [x] branch-desc.nu
│   ├── [x] [x] check-desc.nu
│   ├── [x] [x] git-batch-exec.nu
│   ├── [x] [x] git-batch-reset.nu
│   ├── [x] [x] git-proxy.nu
│   ├── [x] [x] pull-all.nu
│   ├── [x] [x] remote-age.nu
│   ├── [x] [x] rename-branch.nu    # 在 gaia-picker 上操作会出现同步信息输出乱序异常
│   ├── [*] [x] repo-transfer.nu    # glob expansion错误: https://github.com/nushell/nushell/issues/4404
│   ├── [x] [x] sync-branch.nu      # 同步其他仓库的时候 Git 本身输出被吞噬 ?
│   └── [x] [x] trigger-sync.nu     # 同步其他仓库的时候 Git 本身输出被吞噬 ?
├── [x] mall
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
└── [x] utils
    ├── [x] [x] common.nu
    ├── [x] [x] compose-cmd.nu
    └── [x] [x] git.nu
```

### Adapt to Nushell v0.60.0 on Windows

```shell
.
├── [ ] Justfile
├── [ ] actions
│   ├── [ ] brew-speed-up.nu
│   ├── [ ] check-ver.nu
│   ├── [ ] dir-batch-exec.nu
│   ├── [ ] gaia-release.nu
│   ├── [ ] ls-node.nu
│   ├── [ ] ls-redev-refs.nu
│   ├── [ ] prune-synced-branches.nu
│   ├── [ ] pull-redev.nu
│   ├── [ ] quick-nav.nu
│   ├── [ ] release.nu
│   ├── [ ] show-env.nu
│   ├── [ ] tag-redev.nu
│   ├── [ ] upgrade
│   └── [ ] working-hours.nu
├── [ ] git
│   ├── [ ] age.nu
│   ├── [ ] branch-desc.nu
│   ├── [ ] check-desc.nu
│   ├── [ ] git-batch-exec.nu
│   ├── [ ] git-batch-reset.nu
│   ├── [ ] git-proxy.nu
│   ├── [ ] pull-all.nu
│   ├── [ ] remote-age.nu
│   ├── [ ] rename-branch.nu
│   ├── [ ] repo-transfer.nu
│   ├── [ ] sync-branch.nu
│   └── [ ] trigger-sync.nu
├── [ ] mall
│   └── [ ] clean-locale.nu
├── [ ] run
│   ├── [ ] git.nu
│   ├── [ ] merge-perf.nu
│   ├── [ ] merge.nu
│   ├── [ ] set-git-alias.nu
│   ├── [ ] setup-conf.nu
│   ├── [ ] setup-mac.nu
│   └── [ ] ts-stat.nu
├── [ ] termix.toml
└── [ ] utils
    ├── [ ] common.nu
    ├── [ ] compose-cmd.nu
    └── [ ] git.nu
```
