# Tally — PRD

> macOS menu bar app，讓使用者一眼看出本月用了多少流量、誰是兇手、還剩多少額度。

**版本**：v0.3（MVP spec）
**最後更新**：2026-05-18
**狀態**：Spec freeze，準備開工

---

## 1. 產品定位

一款 macOS menu bar app，自用優先，未來可考慮上架。

**設計取向**：
- 比 Activity Monitor 漂亮
- 比 TripMode 簡單
- 比 Bandwidth+ 多 per-app 維度

**核心承諾**：一般人不用懂技術也能用。所有術語、UI 文案都要過「我媽看得懂嗎」這關。

---

## 2. 目標使用者

- **Primary**：本人，自用
- **Secondary**（若上架）：在意流量但不想搞防火牆規則的一般 Mac 使用者，特別是常用熱點、出國漫遊的人

---

## 3. Non-Goals

明確不做的事情，避免 scope creep：

- 不擋 app 上網（不做 firewall）
- 不分析 domain / server / 連線目的地
- 不做跨裝置同步、iCloud 同步
- 不監控 CPU / RAM / 電池 / 風扇
- 不做家長監控、員工監控
- v1 不支援 iOS

---

## 4. 系統需求

- macOS 14（Sonoma）以上
- 需要 Apple Developer 帳號申請 Network Extension entitlement（已備）

---

## 5. 核心使用情境

1. 打開 menu bar，3 秒內知道「本月用了 X GB，距離上限還有 Y%」
2. 想知道某個 app 是不是在偷流量 → 看 Top 排行
3. 出門接手機熱點 → 自動切到熱點 profile（v0.2）
4. 快達到上限時收到通知（80% / 95% / 100%）
5. 月底要對帳 → 看歷史趨勢（v0.2）

---

## 6. UI 架構

### 6.1 Menu bar popover（glance）
- 本月總用量（大數字）
- 距離上限的進度條
- Top 5 app 卡片
- 「打開完整畫面」按鈕
- 齒輪 → 設定

### 6.2 Main window（detail）
固定尺寸 **960 × 640**，可移動但不可 resize。Sidebar 寬約 200，內容區 760。

MVP sidebar：**總覽 / 設定**
v0.2+：總覽 / Apps / 歷史 / 網路 / 設定

### 6.3 各頁面內容（MVP）

**總覽**：大數字區、進度條、目前網路一句話、Top 10 卡片
**設定**：每月起算日、月用量上限、提醒 checkbox、開機啟動、Advanced toggle

---

## 7. 一般模式 vs Advanced 模式

MVP 只做一般模式。

| 概念 | ❌ Advanced | ✅ 一般模式 |
|---|---|---|
| Bytes in / out | Upload / Download | 傳出 / 收進 |
| Billing cycle start | Billing cycle start day | 每月從幾號開始算 |
| Monthly cap | Monthly data cap | 每月可以用多少 |
| Network Extension | Network Extension | 允許 Tally 看到網路使用情況 |
| Process | Process | app 或 程式 |
| Throughput | Throughput / Mbps | 目前速度（用 MB/s） |
| Tethering | Hotspot | 手機熱點 |
| SSID | SSID | Wi-Fi 名稱 |

文案範例：
- 「這個月用了 12.4 GB」「還可以用 7.6 GB（到 6 月 1 日重置）」
- 「以目前的速度，月底大概會用到 18 GB」
- 「你現在連在 家裡的 Wi-Fi」
- 「你現在用的是 iPhone 的熱點，要小心一點哦」
- 「Chrome 用了 4.2 GB（佔 34%）」

語氣：用「你」、輕鬆親切、口語化。

---

## 8. System Process 分類

| 類別 | 包含的 process |
|---|---|
| iCloud | bird, cloudd, cloudphotod, CloudKit, apsd |
| Time Machine 備份 | backupd, backupd-helper |
| 軟體更新 | softwareupdated, osinstallersetupd |
| Spotlight 搜尋 | mds, mdworker_shared, mds_stores |
| 系統其他 | mDNSResponder, trustd, nsurlsessiond, etc |

---

## 9. Onboarding

Step 1 Welcome / Step 2 Permission / Step 3 Settings

---

## 10–14. 技術 / 資料模型 / Roadmap

SwiftUI, MenuBarExtra + Window, GRDB SQLite, NEFilterDataProvider System Extension.

MVP → v0.2 → v0.3 (Advanced mode).

---

## 15. 設計原則

- **數字優先**
- **不要 dashboard 化**
- **永遠用人話**
- **App 顯示用真名+icon**
- **Scope 守門**

(Full PRD lives in user's `tally/docs/PRD.md`.)
