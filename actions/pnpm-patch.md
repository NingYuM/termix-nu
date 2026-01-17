# pnpm-patch.nu 离线补丁工具

一个用于创建 pnpm 兼容补丁的离线工具，无需网络访问即可完成补丁创建和应用。

---

## 一、功能特性与 PRD

### 1.1 核心功能

| 功能               | 描述                                                          |
| ------------------ | ------------------------------------------------------------- |
| **离线补丁创建**   | 无需网络连接，直接从 `node_modules/.pnpm` 中提取包并创建补丁  |
| **累积补丁模式**   | 新补丁自动包含旧补丁的所有变更 + 新增变更，符合 pnpm 原生行为 |
| **自动 Hash 计算** | 自动计算补丁文件的 hash 并更新到 `pnpm-lock.yaml`             |
| **跨版本兼容**     | 同时支持 pnpm 9.x (MD5) 和 pnpm 10.x (SHA256)                 |
| **完整配置更新**   | 自动更新 `package.json` 和 `pnpm-lock.yaml` 的相关配置        |
| **混合原始包获取** | 优先从 pnpm store 恢复原始包，失败时降级到补丁反向应用        |

### 1.2 功能详情

#### 离线补丁创建

- 从本地 `node_modules/.pnpm` 目录中读取已安装的包
- 支持作用域包 (`@scope/package@version`) 和普通包 (`package@version`)
- 支持不指定版本的包 (`@scope/package` 或 `package`)
- 生成符合 pnpm 标准格式的 `.patch` 文件

#### 累积补丁模式

当目标包已存在补丁时，工具会自动进入累积模式：

1. **original/ 目录**：获取真正的原始版本（优先从 pnpm store 恢复，失败时反向应用现有补丁）
2. **modified/ 目录**：保留现有补丁的变更，用户在此基础上添加新变更
3. **最终补丁**：包含 旧补丁变更 + 新变更，形成完整的累积补丁

这与 pnpm 原生 `pnpm patch-commit` 行为一致：每个 `package@version` 只能有一个补丁文件。

#### 混合原始包获取策略

为了更可靠地获取原始包，工具**始终优先**尝试从 pnpm store 恢复原始包：

**策略 1: pnpm Store 恢复（始终优先尝试）**

- 无论是新建补丁还是累积补丁，都会首先尝试从 store 恢复
- 从 `pnpm-lock.yaml` 获取包的 integrity hash
- 通过 `pnpm store path` 定位 store 目录
- 解析 store 中的 `*-index.json` 文件，获取所有文件的 integrity
- 根据每个文件的 integrity 从 store 的内容寻址存储中复制文件

**策略 2: node_modules 复制（第一降级）**

- 如果 store 恢复失败，从 `node_modules/.pnpm` 复制包
- 适用于新建补丁场景（node_modules 中的包即为原始版本）

**策略 3: 补丁反向应用（最终降级，仅累积模式）**

- 仅在累积模式下，当 store 恢复失败时使用
- 使用 `patch -R` 反向应用现有补丁
- 将已打补丁的版本还原为原始版本

这种混合策略的优势：

- Store 恢复更可靠：直接读取原始文件，不依赖补丁格式
- Store 恢复更准确：内容寻址保证 100% 准确
- 多级降级保证可用性：即使 store 不可用也能正常工作

#### Hash 自动更新

- 自动检测 lockfile 版本 (pnpm 9.x 或 10.x)
- pnpm 9.x 使用 MD5 算法，pnpm 10.x 使用 SHA256 算法
- 自动更新 `pnpm-lock.yaml` 中的 `patchedDependencies` 配置
- 自动注入 `patch_hash` 到所有版本引用中，确保离线安装正常工作

### 1.3 使用场景

| 场景             | 说明                                   |
| ---------------- | -------------------------------------- |
| 修复第三方库 Bug | 无需等待上游发布，直接在本地修复问题   |
| 临时功能定制     | 为特定需求定制第三方库的行为           |
| 离线环境开发     | 在无网络环境中创建和管理补丁           |
| CI/CD 集成       | 补丁文件可提交到代码库，确保构建可重现 |

### 1.4 产品约束

- 每个 `package@version` 只能有一个补丁文件（pnpm 限制）
- 补丁基于 git diff 格式生成
- 需要先执行 `pnpm install` 确保包已安装到 `node_modules`

---

## 二、使用说明

### 2.1 基本用法

```bash
# 为作用域包创建补丁
nu tools/pnpm-patch.nu @alife/stage-supplier-selector@2.5.0

# 为普通包创建补丁
nu tools/pnpm-patch.nu lodash@4.17.21

# 指定项目根目录
nu tools/pnpm-patch.nu @alife/u-touch@2.1.5 --project-root /path/to/project
```

### 2.2 工作流程

1. **运行工具**：执行上述命令，工具会自动：
   - 定位 `node_modules/.pnpm` 中的目标包
   - 创建临时目录 `.pnpm-patch-tmp`
   - 复制包到 `original/` 和 `modified/` 目录

2. **编辑文件**：在 `modified/` 目录中修改需要补丁的文件

3. **完成编辑**：按 Enter 键确认完成，或按 Esc 键取消

4. **自动处理**：工具会自动：
   - 生成 diff 补丁文件到 `patches/` 目录
   - 更新 `package.json` 的 `pnpm.patchedDependencies` 配置
   - 更新 `pnpm-lock.yaml` 中的 hash 值

5. **验证补丁**：运行 `pnpm install --offline` 验证补丁是否正常应用

### 2.3 累积补丁模式

当目标包已有补丁时，工具会自动启用累积模式：

```
============================================
Found existing patch, reverting to get original version...
Successfully reverted to original version
Cumulative mode: existing patch preserved in modified/, reverted in original/
============================================
Ready for editing!
============================================

Edit the files in:
  /path/to/.pnpm-patch-tmp/modified/package-name

Original (unpatched) version is at:
  /path/to/.pnpm-patch-tmp/original/package-name

Note: The modified directory contains the existing patch changes.
      Your new changes will be ADDED to the existing patch (cumulative).

Press Enter when you have finished editing, or press Esc to cancel...
```

在此模式下：

- `modified/` 目录已包含旧补丁的变更
- 你的新修改会叠加在旧变更之上
- 最终生成的补丁包含所有变更

### 2.4 输出文件

| 文件                                    | 说明                     |
| --------------------------------------- | ------------------------ |
| `patches/@scope__package@version.patch` | 生成的补丁文件           |
| `package.json`                          | 更新的补丁配置           |
| `pnpm-lock.yaml`                        | 更新的 hash 值和版本引用 |

### 2.5 完成后步骤

```bash
# 1. 验证补丁应用
pnpm install --offline

# 2. 测试变更
pnpm test

# 3. 提交变更
git add patches/ package.json pnpm-lock.yaml
git commit -m "feat: add patch for @scope/package@version"
```

---

## 三、开发者说明

### 3.1 架构设计

工具采用函数式设计，将纯函数与副作用函数分离：

```
┌─────────────────────────────────────────────────────────────┐
│                    Pure Functions (可测试)                   │
├─────────────────────────────────────────────────────────────┤
│ hash-md5, hash-sha256        │ 计算补丁 hash                 │
│ parse-package-spec           │ 解析包名和版本                 │
│ build-patch-filename         │ 构建补丁文件名                 │
│ build-patch-key              │ 构建配置键名                   │
│ find-package-dir             │ 查找包目录                     │
│ generate-patch               │ 生成 diff 补丁                 │
│ merge-patch-config           │ 合并 package.json 配置         │
│ update-lock-content          │ 更新 lockfile 内容             │
│ insert-lock-entry            │ 插入新的补丁条目               │
│ inject-patch-hash-to-versions│ 注入 patch_hash 到版本引用     │
│ detect-lockfile-version      │ 检测 lockfile 版本             │
│ calculate-patch-hash         │ 计算补丁 hash（版本感知）      │
│ integrity-to-store-path      │ 转换 integrity 为 store 路径   │
│ get-package-integrity        │ 从 lockfile 获取包的 integrity │
│ restore-from-store           │ 从 pnpm store 恢复原始包       │
│ revert-patch                 │ 反向应用补丁（导出用于测试）   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                 Side-effect Functions (副作用)               │
├─────────────────────────────────────────────────────────────┤
│ check-dependencies           │ 检查 git/patch 是否安装        │
│ update-package-json          │ 更新 package.json 文件         │
│ update-lock-hash             │ 更新 pnpm-lock.yaml 文件       │
│ cleanup                      │ 清理临时目录                   │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 关键实现细节

#### Hash 计算

```nushell
# pnpm 9.x: MD5 + Base32 (无 padding)
$content | hash md5 --binary | encode base32 --nopad | str downcase

# pnpm 10.x: SHA256 + Hex (小写)
$content | hash sha256 --binary | encode hex | str downcase
```

**注意**：计算 hash 前需要统一换行符 (CRLF -> LF)，确保跨平台一致性。

#### 补丁生成

使用 `git diff --no-index --full-index` 生成补丁：

```nushell
git diff --no-index --text --full-index $"original/($basename)" $"modified/($basename)"
```

**`--full-index` 参数**：确保输出完整的 40 字符 SHA-1 哈希，避免因环境差异导致的哈希缩写不一致。

#### 补丁反向应用

使用 `patch -R` 命令而非 `git apply -R`：

```nushell
^patch -R -p1 --no-backup-if-mismatch -i $patch_file
```

**原因**：`git apply -R` 在某些情况下会静默跳过补丁（返回成功但不执行），而 `patch -R` 更可靠。

#### 版本引用注入

pnpm 在 lockfile 中使用 `patch_hash` 后缀标识已打补丁的版本：

```yaml
# importers 部分
'@alife/package':
  specifier: ^2.5.0
  version: 2.5.0(patch_hash=abc123...)

# snapshots 部分
'@alife+package@2.5.0(patch_hash=abc123...)': {}
```

工具通过正则表达式在多个位置注入 `patch_hash`：

1. importer 的 version 字段
2. snapshot 键名
3. 作为 peer dependency 被引用的位置
4. dependencies 值中的版本号

#### pnpm Store 结构与恢复

pnpm store 采用内容寻址存储（Content Addressable Storage）：

```
~/.local/share/pnpm/store/v3/
├── files/
│   ├── 00/
│   │   ├── <hash>              # 实际文件内容
│   │   └── <hash>-index.json   # 包的文件索引
│   ├── 01/
│   └── ...
```

**恢复流程**：

```nushell
# 1. 从 lockfile 获取包的 integrity
let pkg_integrity = "sha512-v2kDEe..."

# 2. 将 sha512-base64 转换为 hex，取前2位作为 bucket
let hex = $integrity | str replace "sha512-" "" | decode base64 | encode hex | str downcase
let bucket = $hex | str substring 0..<2
let hash = $hex | str substring 2..

# 3. 定位 index.json
let index_file = $"($store_path)/files/($bucket)/($hash)-index.json"

# 4. 解析 index.json，按每个文件的 integrity 从 store 复制
for file in $files {
  let file_hex = $file.integrity | decode ... | encode hex
  cp $"($store_path)/files/($file_hex.bucket)/($file_hex.hash)" $"($target)/($file.name)"
}
```

### 3.3 注意事项

#### 路径处理

- 所有路径操作使用绝对路径
- `revert-patch` 函数内部会转换相对路径为绝对路径，因为 `cd` 后相对路径会失效

#### 正则表达式

- 使用 `(?m)` 多行模式匹配行首行尾
- 版本号中的 `.` 需要转义：`$pkg_version | str replace -a '.' '\\.'`
- 作用域包名和普通包名需要分别处理（引号差异）

#### 原始包获取逻辑

```
# 无论是否存在旧补丁，始终优先尝试从 store 恢复
1. 尝试从 pnpm store 恢复原始包到 original/
   - 成功: 使用 store 中的原始版本
   - 失败: 从 node_modules 复制

2. 准备 modified/ 目录:
   if 存在旧补丁:
       复制 node_modules 中的已打补丁版本到 modified/
   else:
       复制 original/ 到 modified/

3. 累积模式特殊处理 (存在旧补丁且 store 恢复失败):
   - 使用 patch -R 反向应用补丁，还原 original/ 为真正的原始版本

4. 用户在 modified/ 中进行修改

5. 生成 diff(original/, modified/)
   - 累积模式: = 旧补丁变更 + 新变更
   - 新建模式: = 新变更
```

#### 错误处理

- 补丁反向应用失败时，返回 `false` 并显示详细错误信息
- 无法找到包目录时，显示明确的错误提示
- 检测到无变更时，不创建空补丁文件

### 3.4 测试

测试文件位于 `tools/tests/test-pnpm-patch.nu`，包含 62 个测试用例：

```bash
# 运行所有测试（需要在项目根目录执行）
nu tools/tests/test-pnpm-patch.nu

# 或通过环境变量指定项目根目录
PROJECT_ROOT=/path/to/project nu tools/tests/test-pnpm-patch.nu
```

关键测试用例：

- `test-revert-patch-success`: 验证补丁反向应用成功
- `test-revert-patch-failure`: 验证不匹配内容时反向应用失败（会输出预期的错误信息）
- `test-cumulative-patch-generation`: 验证累积模式完整工作流
- `test-integrity-to-store-path`: 验证 integrity 到 store 路径的转换
- `test-get-package-integrity`: 验证从 lockfile 提取 integrity
- `test-get-package-integrity-quoted`: 验证引号包裹的作用域包处理
- `test-get-package-integrity-skip-patched`: 验证跳过 patchedDependencies 部分
- `test-restore-from-store`: 验证从 pnpm store 恢复包

### 3.5 外部依赖

| 依赖    | 用途                                   |
| ------- | -------------------------------------- |
| `git`   | 生成 diff 补丁 (`git diff --no-index`) |
| `patch` | 反向应用补丁 (`patch -R`)              |
| `pnpm`  | 获取 store 路径 (`pnpm store path`)    |

### 3.6 文件结构

```
tools/
├── pnpm-patch.nu          # 主工具脚本
├── pnpm-patch.md          # 本文档
└── tests/
    └── test-pnpm-patch.nu # 测试文件

patches/                    # 生成的补丁文件存放目录
└── @scope__package@version.patch
```

### 3.7 已知限制

1. **单补丁限制**：每个 `package@version` 只能有一个补丁（pnpm 限制）
2. **版本匹配**：累积模式要求已安装的包版本与现有补丁版本一致
3. **二进制文件**：不支持对二进制文件打补丁
4. **符号链接**：不支持包含符号链接的补丁
5. **Store 依赖**：从 store 恢复需要 store 未被 `pnpm store prune` 清理

### 3.8 扩展开发

如需添加新功能，请遵循以下原则：

1. **纯函数优先**：尽可能将逻辑实现为纯函数，便于测试
2. **导出可测试函数**：使用 `export def` 导出需要测试的函数
3. **编写测试用例**：为新功能添加对应的测试用例
4. **保持向后兼容**：不破坏现有的命令行接口和输出格式
