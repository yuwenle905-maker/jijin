# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**定投管家** — iOS 基金定投跟踪 App，TrollStore 免签，iOS 15.0+。

用户定投计划：
| 基金 | 代码 | 计划 |
|---|---|---|
| 标普500ETF联接 | 513500 | 周一 14:50 限时卖一价买入100手（场内ETF） |
| 天弘中证红利低波100A | 008114 | 周二定投250元 |
| 易方达增强回报债券A | 110017 | 周二定投300元 |
| 华安黄金ETF联接A | 000216 | 周二定投100元 |
| 易方达中证A500ETF联接A | 022459 | 周四定投200元 |

再平衡目标：标普500 20-30%、红利低波 18-28%、A500 13-22%。债券+黄金只调结构不主动减仓。

## 构建

```bash
# 生成 xcodeproj（修改 project.yml 或新增文件后执行）
xcodegen generate --spec project.yml

# 本地构建
xcodebuild -project JiJin.xcodeproj -scheme JiJin -configuration Release \
  -sdk iphoneos ARCHS=arm64 CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

CI 在 push 到 main/master 时自动构建 IPA，从 GitHub Actions Artifacts 下载后用 TrollStore 安装。

## 核心架构

**`DataStore`**（`@EnvironmentObject`）— 全局数据仓库，JSON 持久化到 Documents：
- `funds_v1.json` — 基金配置（首次启动自动播种默认5只基金）
- `records_v1.json` — 投资记录

**数据模型：**
- `Fund` — 基金定义，含 `isETF`/`etfTime`/`etfLots` 区分场内/场外，`targetMinPct`/`targetMaxPct` 为再平衡目标区间
- `InvestmentRecord` — 每次操作记录，`status` 可为 success/failed/partial/skipped（余额不足时标 failed）

**四个 Tab：**
- `TodayView` — 今日任务，按 weekday 过滤应操作基金；场内ETF显示倒计时到操作时间
- `RecordsView` — 记录列表，按日期分组，点击可编辑
- `RebalanceView` — 再平衡计算器，输入各仓市值，自动计算占比和操作建议
- `SettingsView` — 修改定投金额、ETF操作时间、手数、再平衡目标区间

**`NotificationManager`** — 每次启动重新注册所有本地通知（定投提醒早9点、ETF精确到操作时间、每年12月1日再平衡提醒）。

## iOS 15 注意事项

- `.onChange(of:)` 只能用单参数闭包 `{ newVal in }`
- `Picker` 的 `.segmented` 样式在 iOS 15 上需确保 tag 类型匹配
- `LabeledContent` 在 iOS 16+，iOS 15 需用 HStack 替代
