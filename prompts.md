# TERP Assets Prompt Examples

这些提示词已经在当前仓库里实际验证过，可直接给 AI 参考使用。

原则：

- 涉及 `transfer`、`init`、`revert` 这类会修改远端状态的操作时，先让 AI 收集参数、校验参数、展示待执行命令和参数表。
- 如果缺少关键参数，要求 AI 明确指出缺什么，不要猜。
- 只有在你明确回复“确认执行”后才允许真正执行。

## 1. 同步模块到目标挂载点

适合把指定模块从一个源挂载点同步到目标挂载点。

```text
使用 terp-assets SKILL 把 base 模块从 3.0.2512 同步到 ttt0 存储为 oss
```

如果需要一次同步多个模块：

```text
使用 terp-assets SKILL 把 base & base-mobile 模块从 3.0.2512 同步到 ttt0 存储为 oss
```

## 2. 查看挂载点包含哪些模块

```text
ttt0 上有哪些模块？各模块分别有多少静态资源？
```

## 3. 查看完整 latest.json URL 的模块和资源统计

适合排查网关地址或完整 `latest.json` URL。

```text
https://portal-test.app.terminus.io/latest.json 这个里面有哪些模块？各模块有多少静态资源？
```

## 4. 回滚指定模块

第一步先表达回滚意图：

```text
回滚 oss 上挂载点 ttt0 的 base 模块
```
然后根据 AI 查询到的模块版本列表输入要回滚到的版本并 “确认执行“

## 5. 推荐的一步式安全提示词

如果你希望一开始就把参数说完整，可以直接使用：

```text
使用 terp-assets SKILL 回滚 oss 存储上 ttt0 挂载点的 base 模块到 base-20260408142619。先校验参数并展示待执行命令、参数说明表和执行效果说明，只有在我确认之后才执行。
```

同步操作的一步式写法：

```text
使用 terp-assets SKILL 把 base 和 base-mobile 从 3.0.2512 同步到 ttt0，目标存储为 oss。先做只读校验并展示完整命令、参数说明表和预期影响，等我确认后再执行。
```

## 6. 给 AI 的约束语

如果你担心误操作，可以把下面这段一起带上：

```text
不要猜测任何缺失参数；如果参数不完整或你不确定，就明确告诉我缺什么。所有远端变更操作必须先展示完整待执行命令、参数表和影响说明，等我确认后再执行。
```

# Trantor Artifact Prompt Examples

下面这两条来自当前仓库里已经实际执行过的 `trantor-artifact` 场景，可直接给 AI 参考使用。

原则：

- 先让 AI 用只读方式确认 source、destination、版本是否存在，以及最终应该走 `pack` 还是 `consume`/`deploy`。
- 明确给出版本号、目标环境、目标项目别名，不要让 AI 猜。
- 如果涉及远端变更，要求 AI 先做 `--dry-run` 校验，再执行正式命令。

## 1. 将应用制品转换为项目制品

适合把 FE / Trantor 侧的单应用制品包装成同项目下的项目制品。

```text
使用 trantor-artifact SKILL，把 Portal-53ba74b-dev+260409.111622 从应用制品转换为项目制品。
```

说明：

- 这个场景最终走的是 `t art pack`。
- AI 应先确认默认 source 是否可用；如果默认 source 已经在配置里验证通过，可以说明后直接使用。
- 这个具体案例里，应用制品 `Portal-53ba74b-dev+260409.111622` 被转换成了项目制品 `Ptl-53ba74b-dev+260409.111622`。

如果你想强调“不要直接执行”，可以改成更稳妥的版本：

```text
使用 trantor-artifact SKILL，把 Portal-53ba74b-dev+260409.111622 从应用制品转换为项目制品。先用 dry-run 校验 source、projectId 和目标版本，展示完整命令和预期结果，确认无误后再执行。
```

## 2. 将指定制品部署到 TERP 开发环境

适合把某个已知版本部署到 `terp` 的开发环境。AI 需要先判断该版本在目标项目里是否已存在，若不存在则应自动改走 `consume` 流程。

```text
使用 trantor-artifact SKILL，将 3.0.2603-beta.0228+20260403233102 制品部署到 terp 开发环境
```

说明：

- 这个场景里，目标项目 `terp` 中不存在同版本制品，所以不能直接 `deploy`，需要走 `consume`。
- AI 应先验证目标别名 `terp`、目标环境 `DEV`、默认部署组，以及源项目里是否能找到该版本。
- 如果该版本已经在目标项目里，AI 应改用 `deploy`；如果只在源项目存在，则应使用 `consume`。
- 这个具体案例里，AI 已成功匹配源制品、上传到目标项目并创建部署单；部署单 ID 为 `cddcd9a0-7c61-47ed-8700-d95067fe1af8`。最终部署状态应以 ERDA 实时结果为准。

更强调过程透明的版本可以这样写：

```text
使用 trantor-artifact SKILL，将 3.0.2603-beta.0228+20260403233102 部署到 terp 的 DEV 环境。不要猜 source、deploy group 或动作类型；先只读探测并说明为什么走 deploy 或 consume，再 dry-run，最后执行正式命令并输出关键结果。
```

## 3. 推荐附加约束语

如果你希望 AI 在制品操作里更稳一些，可以把下面这段一起带上：

```text
不要猜测 source、destination、branch、deploy group、version 或目标环境。先做只读探测和 dry-run，明确告诉我将使用哪个默认配置以及为什么，然后再执行真正的制品操作。执行后请返回 projectId、releaseId、deployOrderId、detailUrl 和最终状态。
```
