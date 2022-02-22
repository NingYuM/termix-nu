
### Adapt to nushell v0.60.0

```shell
.
├── [x] Justfile
├── [ ] actions
│   ├── [x] [x] brew-speed-up.nu
│   ├── [x] [ ] check-ver.nu
│   ├── [*] [ ] dir-batch-exec.nu   # 输出色彩丢失
│   ├── [?] [ ] gaia-release.nu     # Match 现在还不支持: https://github.com/nushell/nushell/issues/4356
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
│   ├── [x] [ ] git-batch-exec.nu
│   ├── [x] [ ] git-batch-reset.nu
│   ├── [x] [ ] git-proxy.nu
│   ├── [x] [x] pull-all.nu         # 终端输入异常: https://github.com/nushell/nushell/issues/4384
│   ├── [x] [x] remote-age.nu
│   ├── [x] [ ] rename-branch.nu
│   ├── [*] [ ] repo-transfer.nu    # glob expansion错误: https://github.com/nushell/nushell/issues/4404
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
    ├── [x] [ ] common.nu
    ├── [x] [ ] compose-cmd.nu
    └── [x] [ ] git.nu
```
