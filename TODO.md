
### Adapt to Nushell v0.60.0

```shell
.
├── [x] Justfile
├── [x] actions
│   ├── [x] brew-speed-up.nu
│   ├── [x] check-ver.nu
│   ├── [x] dir-batch-exec.nu
│   ├── [x] gaia-release.nu
│   ├── [x] ls-node.nu
│   ├── [x] ls-redev-refs.nu
│   ├── [x] prune-synced-branches.nu
│   ├── [x] pull-redev.nu
│   ├── [x] quick-nav.nu
│   ├── [x] release.nu
│   ├── [x] show-env.nu
│   ├── [x] tag-redev.nu        # glob expansion错误: https://github.com/nushell/nushell/issues/4404
│   ├── [x] upgrade
│   └── [x] working-hours.nu
├── [x] git
│   ├── [x] age.nu
│   ├── [x] branch-desc.nu
│   ├── [x] check-desc.nu
│   ├── [x] git-batch-exec.nu
│   ├── [x] git-batch-reset.nu
│   ├── [x] git-proxy.nu
│   ├── [x] pull-all.nu
│   ├── [x] remote-age.nu
│   ├── [x] rename-branch.nu    # 在 gaia-picker 上操作会出现同步信息输出乱序异常
│   ├── [x] repo-transfer.nu    # glob expansion错误: https://github.com/nushell/nushell/issues/4404
│   ├── [x] sync-branch.nu      # 同步其他仓库的时候 Git 本身输出被吞噬 ?
│   └── [x] trigger-sync.nu     # 同步其他仓库的时候 Git 本身输出被吞噬 ?
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
    ├── [x] common.nu
    ├── [x] compose-cmd.nu
    └── [x] git.nu
```

### Adapt to Nushell v0.60.0 on Windows

```shell
.
├── [x] Justfile
├── [ ] actions
│   ├── [-] brew-speed-up.nu
│   ├── [x] check-ver.nu
│   ├── [x] dir-batch-exec.nu
│   ├── [x] gaia-release.nu
│   ├── [x] ls-node.nu
│   ├── [x] ls-redev-refs.nu    # t ls-redev-refs pik true 输出布局异常
│   ├── [x] prune-synced-branches.nu
│   ├── [x] pull-redev.nu
│   ├── [x] quick-nav.nu
│   ├── [x] release.nu
│   ├── [x] show-env.nu     # 输出布局异常
│   ├── [x] tag-redev.nu
│   ├── [x] upgrade
│   └── [x] working-hours.nu
├── [x] git
│   ├── [x] age.nu
│   ├── [x] branch-desc.nu
│   ├── [x] check-desc.nu
│   ├── [x] git-batch-exec.nu
│   ├── [x] git-batch-reset.nu
│   ├── [-] git-proxy.nu
│   ├── [x] pull-all.nu
│   ├── [x] remote-age.nu   # 输出布局异常
│   ├── [x] rename-branch.nu
│   ├── [x] repo-transfer.nu
│   ├── [x] sync-branch.nu
│   └── [x] trigger-sync.nu
├── [x] termix.toml
└── [x] utils
    ├── [x] common.nu
    ├── [x] compose-cmd.nu
    └── [x] git.nu
```
