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

點 menu bar icon 打開的小視窗：

- 本月總用量（大數字）
- 距離上限的進度條（若有設上限）
- Top 5 app 卡片
- 「打開完整畫面」按鈕
- 齒輪 → 設定

設計原則：popover 是「快速一瞥」，不放任何需要思考的東西。

### 6.2 Main window（detail）

固定尺寸 **960 × 640**，可移動但不可 resize。Sidebar 寬約 200，內容區 760。

Sidebar 結構（MVP）：
- **總覽**
- **設定**

Sidebar 結構（v0.2+）：
- **總覽**
- **Apps**（完整列表）
- **歷史**
- **網路**
- 分隔線
- **設定**

### 6.3 各頁面內容（MVP）

#### 總覽（Overview）

- **大數字區**：本月總用量 / 上限 / 剩餘
- **進度條**：「以目前速度月底會用到 X GB」預估
  - 若使用者沒設上限：改顯示「上個月用了 Y GB」當作比較基準
- **目前網路**：一句話，例如「你現在連在 家裡的 Wi-Fi」
- **Top 10 卡片**：含 app icon、名稱、本月用量、佔比

#### 設定（Settings）

- 每月從幾號開始算（預設 1 號）
- 每月可以用多少（GB；或選「沒有上限」）
- 快用完時提醒我（checkbox：80% / 95% / 100%）
- 開機自動啟動
- （Advanced 模式 toggle 保留位置，但 MVP 不解鎖任何東西）

---

## 7. 一般模式 vs Advanced 模式

MVP 只做一般模式。Advanced 模式 toggle 預設關，UI 位置先留好。

### 術語對照表

| 概念 | ❌ Advanced（技術詞） | ✅ 一般模式（人話） |
|---|---|---|
| Bytes in / out | Upload / Download | 傳出 / 收進 |
| Data usage | Data usage | 流量 |
| Billing cycle start | Billing cycle start day | 每月從幾號開始算 |
| Monthly cap | Monthly data cap | 每月可以用多少 |
| Network Extension permission | Network Extension | 允許 Tally 看到網路使用情況 |
| Bundle identifier | Bundle ID | （隱藏，只顯示 app 名字和 icon） |
| Process | Process | app 或 程式 |
| Aggregate | Aggregate by app | 依 app 分類 |
| Throughput | Throughput / Mbps | 目前速度（用 MB/s） |
| Cellular tethering | Tethering / Hotspot | 手機熱點 |
| Threshold | Threshold | 提醒時機 |
| SSID | SSID | Wi-Fi 名稱 |
| VPN | VPN tunnel | VPN（保留，VPN 用戶通常知道） |

### 文案範例

> 這個月用了 **12.4 GB**
> 還可以用 **7.6 GB**（到 6 月 1 日重置）
> 以目前的速度，月底大概會用到 **18 GB**

> 你現在連在 **家裡的 Wi-Fi**

> 你現在用的是 **iPhone 的熱點**，要小心一點哦

> Chrome 用了 4.2 GB（佔 34%）
> iCloud 用了 2.1 GB（佔 17%）

> 這個月的流量已經用了 80% 了

**語氣定錨**：用「你」、輕鬆親切、口語化。

---

## 8. System Process 分類

背景系統流量不能全丟一桶。一般模式裡只看得到友善名字的類別：

| 類別（一般模式） | 包含的 process |
|---|---|
| **iCloud** | `bird`, `cloudd`, `cloudphotod`, `CloudKit`, `apsd` |
| **Time Machine 備份** | `backupd`, `backupd-helper` |
| **軟體更新** | `softwareupdated`, `osinstallersetupd` |
| **Spotlight 搜尋** | `mds`, `mdworker_shared`, `mds_stores` |
| **系統其他** | `mDNSResponder`, `trustd`, `nsurlsessiond`, 其他 daemon |

每個類別有自訂 icon（雲、磁碟、齒輪等等）以區別於一般 app。

Mapping 不到的 process 統一進「系統其他」並記錄下來方便迭代時補上。

一般使用者**永遠不會**看到 `mDNSResponder` 這種字串。Advanced 模式才解鎖細項。

---

## 9. Onboarding

首次啟動三步驟全螢幕 modal：

### Step 1: Welcome
- 簡短說明「Tally 會追蹤你 Mac 的流量使用」
- 一句話講不做什麼：「不擋網、不上傳任何資料到雲端」

### Step 2: 給權限
- 說明需要安裝 System Extension
- 引導去 System Settings → Privacy & Security 批准
- 提供「為什麼需要這個權限」的展開說明
- 這步要寫清楚，因為 macOS 對 SE 的批准流程不直覺

### Step 3: 基本設定
- 選計費週期起始日（預設 1 號）
- 每月可以用多少 GB（可選「我沒有上限，只想追蹤」）

完成後進主畫面，顯示「資料正在收集中，數據會在幾分鐘後開始顯示」。

Onboarding 完成狀態存 UserDefaults。Settings 裡留一顆「重新跑一次 onboarding」方便 debug。

---

## 10. 技術架構

### 資料來源
- **主要**：`NEFilterDataProvider`（System Extension）拿 per-flow bytes + bundle id
- **降級方案**：開發初期可用 `nettop -P -x` 跑通 UI/資料 layer，最後再接 NE

### UI
- SwiftUI
- `MenuBarExtra` + `Window` scene 共存
- 狀態管理：`@Observable` ViewModel，menu bar 和 main window 共用同一個 store
- Main window lifecycle：lazy 建立，關掉就釋放，避免常駐記憶體

### 儲存
- SQLite（GRDB）

### App metadata
- `NSWorkspace` + `LSCopyApplicationURLsForBundleIdentifier` 拿 icon 和 display name

---

## 11. 資料模型

```
flow_samples (raw, 保留 7 天)
  - timestamp
  - bundle_id (or executable_name for daemons)
  - bytes_in, bytes_out
  - network_id (FK → networks)

daily_aggregates (UI 查詢用，永久保留)
  - date
  - bundle_id
  - category (nullable, 對應 system process 分類)
  - network_id
  - total_in, total_out

networks
  - id
  - ssid / interface_type (wifi / ethernet / hotspot)
  - is_hotspot (bool)
  - monthly_limit_gb (nullable, v0.2 才用)

process_categories (mapping table)
  - process_identifier
  - category_name
  - icon_name
  - display_name
```

---

## 12. 已知限制 / 待釐清

- **VPN**：開 VPN 時 NE 看到的可能全是 VPN process 流量，無法 per-app 細分。Onboarding 或 Settings 加一行 known limitation 註記，v1 不處理。
- **資料準確度**：和路由器 / ISP 帳單會有些微差距（NE 看不到 ARP 之類的底層流量），預期誤差 < 5%。
- **Helper process**：例如 Chrome 的 renderer process roll-up 到 Chrome 本體，靠 parent bundle id 判斷。

---

## 13. Roadmap

### MVP（v0.1）— 一般模式 only
- Menu bar popover
- Main window：總覽 + 設定
- System process 分類（5 大類別）
- Onboarding 三步
- 通知（80/95/100%）
- 卡片版型 Top 10

### v0.2
- App 詳細頁 / per-app 歷史曲線
- Apps tab（完整列表，搜尋、排序）
- History tab（日週月柱狀圖）
- Networks tab（多網路分開計算）
- 自動偵測熱點切 profile
- 預估月底用量算法優化
- 「沒有上限」時的上個月比較顯示優化

### v0.3 / Advanced 模式
- Advanced 模式 toggle 解鎖
- 顯示 bundle id、process name、interface 名稱
- Mbps 顯示選項
- 即時速度數字顯示在 menu bar
- Helper process 展開（Chrome renderer 等）
- 自訂分類規則 / 編輯 process category mapping
- 列表版型切換（卡片 / 列表）
- Export CSV / 截圖分享
- VPN 相關處理

---

## 14. Sprint 規劃（MVP）

| Sprint | 內容 |
|---|---|
| **Sprint 1** | 資料管線：NE / nettop + SQLite + ViewModel。UI 只做 menu bar popover 跑通端到端。 |
| **Sprint 2** | Main window + sidebar + 總覽頁，含 system process 分類邏輯。 |
| **Sprint 3** | 設定 + Onboarding + 通知 + 整體打磨。 |

---

## 15. 設計原則（避免做歪的提醒）

- **數字優先**：主畫面最大的元素永遠是「本月用了多少」，不是圖表
- **不要 dashboard 化**：一般人不需要 5 個圖表
- **永遠用人話**：MVP 不會出現任何 process name、bundle id、技術術語
- **App 顯示用真名+icon**：絕對不要出現 `mDNSResponder` 這種東西在主畫面
- **Scope 守門**：任何想加的功能，先問「一般模式真的需要嗎？」否則丟去 Advanced
