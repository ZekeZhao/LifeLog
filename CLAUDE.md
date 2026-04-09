# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LifeLog is a HarmonyOS native app (ArkTS/ArkUI) for logging daily meals and body measurements, with heatmap and trend visualizations. Target: phone, SDK 6.0.2(22), Stage Model.

## Build Commands

| Command | Purpose |
|---------|---------|
| `hvigor clean` | Clean build outputs |
| `hvigor assembleDebug` | Build debug HAP |
| `hvigor assembleRelease` | Build release HAP with obfuscation |
| `hvigor test` | Run tests |

Tests are run via DevEco Studio or `hvigor test`. Local unit tests are in `entry/src/test/`; device/emulator integration tests in `entry/src/ohosTest/`.

## Architecture

Three-tier: **Pages → ViewModels → Database**

- `entry/src/main/ets/pages/Index.ets` — Single page with 3-tab UI (Today, Heatmap, Trends)
- `entry/src/main/ets/viewmodel/` — `TodayViewModel`, `HeatmapViewModel`, `TrendViewModel` (business logic, reactive state)
- `entry/src/main/ets/database/` — `DbHelper.ets` (RDB connection/schema), `DailyRecordDao.ets` (CRUD)
- `entry/src/main/ets/model/DailyRecord.ets` — Core data interface (date PK, breakfast/lunch/dinner 0-2, weight, bodyFat)
- `entry/src/main/ets/view/MealSegment.ets` — Reusable meal selection component
- `entry/src/main/ets/common/Constants.ets` — `AppColors`, `AppDimens`, `ValidationRanges`, meal enums

## ArkTS / ArkUI Patterns

**State management uses ComponentV2** (not the older ComponentV1):
- `@ObservedV2` on classes, `@Trace` on their properties
- `@ComponentV2` for components, `@Local` for component-local state
- `@Entry` marks the page entry point

**SDK imports** use the `@kit.XXX` syntax:
```typescript
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
```

**Logging pattern:**
```typescript
const DOMAIN = 0x0000;
hilog.info(DOMAIN, 'Tag', 'message: %{public}s', value);
```

**Resource references:** `$r('app.string.key')`, `$r('app.color.key')`, `$r('app.float.key')`

## Key Conventions

- New source files use `.ets` extension
- New pages must be added to both `pages/` and `entry/src/main/resources/base/profile/main_pages.json`
- All database operations are async — always use `async/await`
- Colors come from `AppColors`; validation ranges from `ValidationRanges`
- Haptic feedback uses `ohos.permission.VIBRATE` (already declared in `module.json5`)

## Data Storage Architecture

**Local:** RelationalStore (SQLite) — 优先操作本地数据库，保证离线可用。

**Cloud:** Supabase 作为同步后端，通过 REST API 同步数据。
- HTTP 请求使用 `@ohos.net.http`
- Authorization header 携带 Supabase anon key

**Sync Strategy:** Last-write-wins（以更新时间戳为准，取最新记录）

**Sync Timing:**
- App 启动时：拉取云端增量更新
- 本地保存后：推送记录到云端
- 网络不可用时：仅操作本地，下次启动自动恢复同步

**Supabase Schema:**
- 表结构与本地 RelationalStore 保持一致
- 新增 `user_id` 字段用于多用户隔离
- 使用 Supabase 匿名 auth 或固定设备 ID（无需登录功能）

## Meal Scoring

Meals are scored: `LIGHT=0` (healthy), `NORMAL=1`, `INDULGENT=2`. Daily total (0–6) maps to heatmap color (green → red).

## Tool Usage Notes

- When using the Read tool, `limit` must always be a positive integer representing the number of lines to read forward from `offset`. Never pass a negative value.

## Language

- **始终用中文回复用户**，禁止使用韩语或其他语言。
