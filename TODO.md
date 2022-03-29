
### From sh to nu

- [x] get-icon.sh
- [x] upload-image.sh
- [x] compress-images.sh
- [ ] clean-locale.sh
- [x] get-locale.sh
- [ ] upload-locale.sh
- [ ] watch-dev.sh
- [ ] gen_redevelop_repos
- [ ] gen_redevelop_main

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
│   ├── [x] tag-redev.nu
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
│   ├── [x] rename-branch.nu
│   ├── [x] repo-transfer.nu
│   ├── [x] sync-branch.nu
│   └── [x] trigger-sync.nu
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
├── [x] actions
│   ├── [-] brew-speed-up.nu
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
│   ├── [x] remote-age.nu
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
