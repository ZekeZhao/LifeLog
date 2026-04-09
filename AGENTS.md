# LifeLog - 健康生活记录应用

## 项目概述

LifeLog 是一款基于 HarmonyOS (OpenHarmony) 开发的个人健康生活记录应用。用户可以通过该应用记录每日饮食情况（三餐的清淡程度）和身体数据（体重、体脂率），并通过热力图和趋势图表直观地查看历史记录和健康趋势。

### 核心功能

1. **今日记录页 (TodayPage)**：记录昨天的三餐饮食情况和今天的体重、体脂数据
2. **热力图页 (HeatmapPage)**：以日历热力图形式展示每月的饮食健康程度
3. **趋势统计页 (TrendPage)**：展示体重变化趋势图表和健康统计数据

## 技术栈

- **平台**: HarmonyOS / OpenHarmony
- **开发语言**: ArkTS (TypeScript 的超集，支持声明式 UI 语法)
- **UI 框架**: ArkUI (声明式 UI 框架)
- **构建工具**: Hvigor (HarmonyOS 专用构建工具)
- **包管理器**: OHPM (OpenHarmony Package Manager)
- **目标 SDK**: 6.0.2(22)
- **兼容 SDK**: 6.0.2(22)
- **运行系统**: HarmonyOS
- **状态管理**: ArkUI ComponentV2 (@ObservedV2, @Trace, @Local)

## 项目结构

```
.
├── AppScope/                       # 应用级配置和资源
│   ├── app.json5                   # 应用清单（包名、版本、图标、标签）
│   └── resources/base/             # 全局资源（应用名称、图标）
│
├── entry/                          # 主入口模块（HarmonyOS 应用必需）
│   ├── src/main/
│   │   ├── ets/                    # ArkTS 源代码
│   │   │   ├── entryability/       # UI Ability 生命周期管理
│   │   │   │   └── EntryAbility.ets
│   │   │   ├── entrybackupability/ # 备份/恢复扩展
│   │   │   │   └── EntryBackupAbility.ets
│   │   │   ├── pages/              # UI 页面
│   │   │   │   └── Index.ets       # 主页面（包含三个标签页）
│   │   │   ├── view/               # 可复用 UI 组件
│   │   │   │   └── MealSegment.ets # 三餐选择组件
│   │   │   ├── viewmodel/          # 业务逻辑和数据管理
│   │   │   │   ├── TodayViewModel.ets    # 今日记录视图模型
│   │   │   │   ├── HeatmapViewModel.ets  # 热力图视图模型
│   │   │   │   └── TrendViewModel.ets    # 趋势统计视图模型
│   │   │   ├── database/           # 数据访问层
│   │   │   │   ├── DbHelper.ets    # 数据库连接管理
│   │   │   │   └── DailyRecordDao.ets    # 日常记录数据访问对象
│   │   │   ├── model/              # 数据模型
│   │   │   │   └── DailyRecord.ets # 日常记录数据模型
│   │   │   └── common/             # 公共常量
│   │   │       └── Constants.ets   # 颜色、尺寸、枚举等常量
│   │   ├── resources/              # 模块级资源
│   │   │   ├── base/element/       # 字符串、颜色、尺寸（JSON 格式）
│   │   │   ├── base/media/         # 图片和图标
│   │   │   └── base/profile/       # 页面路由、备份配置
│   │   └── module.json5            # 模块配置（abilities、设备类型）
│   │
│   ├── src/test/                   # 本地单元测试（Hypium 框架）
│   │   ├── LocalUnit.test.ets
│   │   └── List.test.ets
│   │
│   ├── src/ohosTest/               # 集成/仪器测试
│   │   └── ets/test/
│   │       ├── Ability.test.ets
│   │       └── List.test.ets
│   │
│   ├── src/mock/                   # 测试 mock 配置
│   │   └── mock-config.json5
│   │
│   ├── oh-package.json5            # Entry 模块包信息
│   ├── build-profile.json5         # Entry 模块构建选项
│   └── obfuscation-rules.txt       # 代码混淆规则
│
├── hvigor/                         # Hvigor 构建配置
│   └── hvigor-config.json5         # 构建执行设置
│
├── .hvigor/                        # Hvigor 缓存和构建输出（gitignored）
├── oh_modules/                     # 安装的依赖（gitignored）
│
├── oh-package.json5                # 根包依赖
├── build-profile.json5             # 根构建配置（产物、模块）
├── hvigorfile.ts                   # Hvigor 构建脚本入口
├── code-linter.json5               # 代码检查和安全规则
└── .gitignore                      # Git 忽略配置
```

## 关键配置文件

### 1. `build-profile.json5` (根目录)
- 定义构建产物（debug/release）
- 配置签名、SDK 版本
- 列出项目中的模块
- `runtimeOS`: HarmonyOS
- 已配置自动签名（debug 证书）

### 2. `oh-package.json5` (根目录)
- 项目开发依赖：`@ohos/hypium` (测试框架)、`@ohos/hamock` (mock 库)
- Entry 模块依赖单独配置

### 3. `entry/src/main/module.json5`
- 模块类型：`entry`（主应用模块）
- 设备类型：`phone`
- 主 Ability：`EntryAbility`
- 扩展 Ability：`EntryBackupAbility`（用于备份/恢复）
- 权限请求：`ohos.permission.VIBRATE`（振动反馈）
- 页面路由：引用 `$profile:main_pages`

### 4. `AppScope/app.json5`
- Bundle 名称：`com.example.lifelog`
- 版本：`1.0.0`（code: 1000000）
- 应用图标和标签引用

### 5. `code-linter.json5`
- 应用 TypeScript ESLint 和性能规则
- 包含加密操作的安全规则
- 忽略测试文件和构建目录

## 数据模型

### DailyRecord (日常记录)

```typescript
interface DailyRecord {
  date: string           // YYYY-MM-DD，主键
  breakfast: number|null // 0=清淡, 1=正常, 2=放纵
  lunch: number|null
  dinner: number|null
  weight: number|null    // 体重 (kg)
  bodyFat: number|null   // 体脂率 (%)
}
```

### 饮食评分系统

- **清淡 (LIGHT = 0)**: 健康饮食
- **正常 (NORMAL = 1)**: 普通饮食
- **放纵 (INDULGENT = 2)**: 高热量饮食

热力图颜色从绿色（健康，总分 0）渐变到红色（放纵，总分 6）。

## 构建和开发命令

本项目使用 **Hvigor** 作为构建系统。可通过 DevEco Studio 或 CLI 使用以下命令：

| 命令 | 描述 |
|------|------|
| `hvigor clean` | 清理构建输出 |
| `hvigor assembleDebug` | 构建 debug HAP |
| `hvigor assembleRelease` | 构建 release HAP（支持代码混淆） |
| `hvigor build` | 完整构建 |
| `hvigor test` | 运行测试 |

### 构建特性
- **API 类型**: Stage Model（现代 HarmonyOS 架构）
- **代码混淆**: 在 release 模式下可通过 `obfuscation-rules.txt` 配置
- **严格模式**: 已启用（大小写敏感检查、规范化 OHM URL）

## 测试策略

项目使用 **Hypium** 测试框架（类似 Jest/Mocha）。

### 测试类型

1. **本地单元测试** (`entry/src/test/`)
   - 在开发机器上运行
   - 快速执行
   - 示例：`LocalUnit.test.ets`

2. **集成/仪器测试** (`entry/src/ohosTest/`)
   - 在设备或模拟器上运行
   - 测试 UI 组件和 Ability
   - 示例：`Ability.test.ets`

### 测试框架：Hypium

```typescript
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
```

- `describe()`: 定义测试套件
- `it()`: 定义测试用例（名称、过滤器、函数）
- `expect().assertXxx()`: 断言（assertContain、assertEqual 等）
- 生命周期钩子：`beforeAll`、`beforeEach`、`afterEach`、`afterAll`

### 运行测试
- 测试组织在 `List.test.ets` 文件中，导入其他测试文件
- 使用 DevEco Studio 测试运行器或 `hvigor` 测试任务

## 代码风格指南

### ArkTS/TypeScript 约定

1. **文件扩展名**: 使用 `.ets` 作为 ArkTS 文件扩展名
2. **导入**: 使用 `@kit/XXX` 导入 HarmonyOS SDK 套件
3. **装饰器**:
   - `@Entry` 标记页面入口点
   - `@Component` 定义可复用 UI 组件
   - `@ComponentV2` 使用新版本组件模型（推荐）
   - `@State` 用于组件状态管理（ComponentV1）
   - `@Local` 用于组件本地状态（ComponentV2）
   - `@Trace` 用于可观察对象属性（ComponentV2）
   - `@ObservedV2` 用于可观察类（ComponentV2）

### UI 开发模式（ArkUI 声明式语法）

```typescript
@Entry
@ComponentV2
struct PageName {
  @Local variable: Type = initialValue;
  @Trace observedProperty: Type = initialValue;
  
  build() {
    // 声明式 UI 布局
  }
}
```

### 日志记录

使用 `@kit.PerformanceAnalysisKit` 中的 `hilog`：
```typescript
import { hilog } from '@kit.PerformanceAnalysisKit';
const DOMAIN = 0x0000;
hilog.info(DOMAIN, 'tag', 'message: %{public}s', value);
hilog.error(DOMAIN, 'tag', 'Failed. Cause: %{public}s', JSON.stringify(err));
```

### 状态管理

项目使用 **ComponentV2** 状态管理：
- `@Local`: 组件本地状态，不与其他组件共享
- `@Trace`: 使类属性可观察，配合 `@ObservedV2` 使用
- `@ObservedV2`: 标记类为可观察，内部属性使用 `@Trace`

### 数据库操作

使用 `@kit.ArkData` 中的关系型数据库：
```typescript
import { relationalStore } from '@kit.ArkData';
```

## 资源管理

资源定义在 `resources/base/` 下的 JSON 文件中：

- `element/string.json`: 本地化字符串
- `element/color.json`: 颜色值
- `element/float.json`: 尺寸值（fp、px、vp）
- `media/`: 图片和图标
- `profile/main_pages.json`: 页面路由注册
- `profile/backup_config.json`: 备份配置

### 访问资源

```typescript
// 在 ArkTS 代码中
$r('app.string.app_name')
$r('app.color.start_window_background')
$media:layered_image
```

## 安全考虑

`code-linter.json5` 包含安全规则：

| 规则 | 级别 | 描述 |
|------|------|------|
| `@security/no-unsafe-aes` | error | 防止不安全的 AES 加密 |
| `@security/no-unsafe-hash` | error | 防止不安全的哈希算法 |
| `@security/no-unsafe-rsa-encrypt` | error | 防止不安全的 RSA 加密 |
| `@security/no-unsafe-rsa-sign` | error | 防止不安全的 RSA 签名 |
| `@security/no-unsafe-mac` | warn | 警告不安全的 MAC |
| `@security/no-unsafe-dh` | error | 防止不安全的 DH 操作 |
| `@security/no-unsafe-dsa` | error | 防止不安全的 DSA |
| `@security/no-unsafe-ecdsa` | error | 防止不安全的 ECDSA |
| `@security/no-unsafe-3des` | error | 防止不安全的 3DES |

**实现安全功能时始终使用经过批准的加密 API。**

## Ability 和生命周期

### UIAbility 生命周期 (EntryAbility)

```
onCreate() → onWindowStageCreate() → onForeground()
                                          ↓
onBackground() ← onWindowStageDestroy() ← onDestroy()
```

EntryAbility 配置为全屏沉浸式模式，隐藏导航栏但保留状态栏。

### ExtensionAbility

- `EntryBackupAbility`: 通过 `BackupExtensionAbility` 处理应用数据备份/恢复

## 部署

1. **HAP (HarmonyOS Ability Package)**: 构建输出格式
2. **签名**: 已配置自动签名（debug 证书路径在 `build-profile.json5` 中）
3. **安装**: 通过 DevEco Studio 或 `hdc` (HarmonyOS Device Connector)

## 开发环境

- **IDE**: DevEco Studio（华为官方 IDE）
- **Node.js**: Hvigor 构建系统需要
- **SDK**: HarmonyOS SDK 6.0.2(22)
- **目标设备**: 手机形态

## 依赖

| 包 | 版本 | 用途 |
|----|------|------|
| `@ohos/hypium` | 1.0.25 | 测试框架 |
| `@ohos/hamock` | 1.0.0 | Mock 库 |

## 给 AI Agent 的注意事项

1. **始终使用 `.ets` 扩展名**创建新源文件
2. **使用 `@kit/XXX` 语法**导入 SDK 套件（例如 `@kit.AbilityKit`、`@kit.ArkUI`、`@kit.ArkData`）
3. **添加新页面**时，需同时添加到 `pages/` 目录**和** `resources/base/profile/main_pages.json`
4. **UI 组件**应适当使用 `@Entry` 和 `@Component`/`@ComponentV2` 装饰器
5. **状态变量**在 ComponentV2 中使用 `@Local` 或 `@Trace` 装饰器以实现响应式
6. **测试文件**应遵循 `src/test/` 或 `src/ohosTest/` 中的现有 Hypium 模式
7. **资源引用**使用 `$r('app.type.name')` 语法
8. **日志记录**应使用带 DOMAIN 常量的 `hilog`
9. **错误处理**应包含 try-catch 和适当的错误日志
10. **数据库操作**是异步的，始终使用 `async/await`
11. **颜色常量**定义在 `AppColors` 类中，保持 UI 一致性
12. **数据验证**使用 `ValidationRanges` 中的范围检查
13. **振动反馈**在用户交互时提供，需要 `ohos.permission.VIBRATE` 权限
