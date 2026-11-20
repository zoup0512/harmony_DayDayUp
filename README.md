# harmony_DayDayUp — 聪聪学堂 HarmonyOS 原生端

> 独立仓库。文中 `apps/mobile`、`apps/web`、`packages/core` 等路径指 congcong-school 主仓库（本仓库在其中位于 `apps/harmony/harmony_DayDayUp`，被主仓库 `.gitignore` 忽略）。

`apps/mobile`（iOS SwiftUI 原生版）的逐层移植：同一个 Duolingo 式课本学习应用，
用 **ArkTS / ArkUI** 原生实现，不是 WebView 壳。领域规则与 `packages/core`、
`apps/mobile` 保持一致（同一组经济常数、同一存档信封、同一确定性算法）。

## 构建

需要本机安装 DevEco Studio（已在本机 `C:\Program Files\Huawei\DevEco Studio` 验证，
SDK API 26 / HarmonyOS 6.x）。

```bash
scripts/build.sh            # 调试 HAP → entry/build/default/outputs/default/
scripts/errors.sh           # 构建并只打印 ArkTS 编译错误（排查用）
```

产物为未签名 debug HAP。真机安装请在 DevEco Studio 中
File › Project Structure › Signing Configs 勾选自动签名后运行。

## 目录

```
entry/src/main/ets/
  domain/        纯业务逻辑（无 UI/IO）：Economy(经济) SRS(间隔复习) Dates
                 Grade(判分) MathText(数学渲染) Seeded(任务/联赛/跳级确定性)
                 Catalog(课本/成就/装扮/宝箱/阅读id) Backup(存档信封v1)
  models/        数据类型（Book/Outline/Lesson/Question/UserProgress…）
  services/      Files(文件/哈希/沙箱) DataLoader(种子+课本加载) SeedInstaller
                 AssetDownloader(GitHub Release 资源) Audio(播放/队列) SFXEngine
                 Feedback(触感/提醒) WidgetSync(桌面卡片快照)
  stores/        ProgressStore(进度·@ObservedV2) SettingsStore(偏好)
  design/        Theme(调色板/字号/圆角/动效) —— Palette 是 @ObservedV2，
                 主题/暗黑切换全局响应式
  components/    Kit(图标/厚底按钮/进度条/弹层) Mascot(Canvas 熊猫)
                 Effects(彩纸/星 reveal/XP 飞字/宝箱) Widgets(日历/目标环/任务卡)
                 PathMap(蛇形路径) ShareCard(分享卡截图)
  features/      Router(AppRoute+NavPathStack) Index 下每页一文件：
                 Onboarding Books(学习Tab/课本/手册/跳级) Lesson(做题) LessonResult
                 Questions(五类题型) ReviewLeagueShop Stories(故事/课文) Profile(我的/成就/设置)
  entryability/  EntryAbility（AppEnv 注入、前后台钩子）
  entryformability/ EntryFormAbility（桌面连胜卡片）
  widget/pages/  WidgetCard（服务卡片 UI）
```

## 与 iOS 版的行为对应

- 红心 5 颗 / 5 分钟回一颗 / 350 宝石补满；护盾 2 个 / 200 宝石；补卡 50 宝石
- 课程 XP：每题 +10，满分 +5，首次满星 +5，周末 ×2，单元挑战 ×2（可叠加）
- 宝石 drip：完成 +3 / 二星 +5 / 三星 +10 / 首满 +15 / 越日目标 +20
- 复习 ≥5 题全对 → +1 红心；SRS 箱子间隔同 iOS
- 联赛 16 人本地榜、周一结算、晋级/降级区与宝石奖励均为确定性种子生成
- 每日任务/跳级测验同样种子化 —— 同一天所有平台出的题一致
- 存档：BackupEnvelope v1，`platform: 'harmony'`，可与 iOS/Web 互导

## 资源与离线

- `resources/rawfile/seed-index.json` + `seed-data.zip`：首启解压进
  `filesDir/cstf/data/`，离线即可学第一本书（stamp 幂等，升级只补缺文件）
- 线上资源沿用 iOS 的 GitHub Release（`ios-manifest.json` +
  `data-<id>.zip` / `audio-ios-<id>.zip`，AAC/m4a  Harmony 可直接播放）
- 音频文件落到 `filesDir/cstf/audio/`，加载器先查本地再走网络

## 桌面卡片

`EntryFormAbility` + `WidgetCard`（2×2）：火苗、连胜天数、今日 XP 环、
按时段切换的提醒文案（和 iOS StreakDisplay 同一套派生逻辑）。
每次 `ProgressStore` 存档时 `WidgetSync` 顺手刷新所有已安装卡片。

## 有意未做 / 差异

- 不接 iCloud —— 跨设备迁移用「设置 › 导出/导入存档」
- 麦克风权限保留（跟读录音占位），通知权限走运行时 `requestEnableNotification`
- 分享卡走系统分享面板（`systemShare`），导出 PNG 到 cacheDir
