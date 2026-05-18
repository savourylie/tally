# Tally Design System

> Design system for **Tally** — a macOS menu bar app that tells you, in plain language, how much data your Mac used this month, which apps are the culprits, and how much you have left.

**Version**: v0.3 (MVP spec era — May 2026)
**Platform**: macOS 14 (Sonoma)+, SwiftUI, MenuBarExtra + Window
**Locale**: Traditional Chinese (Taiwan), conversational tone

---

## Source materials

This design system was built from a single source:

- **PRD** — `tally/docs/PRD.md` (provided locally; mirrored at `source/PRD.md` in this project for reference)

**What was NOT provided** (and would meaningfully improve this system if it existed):
- No codebase, no SwiftUI views, no Figma, no logos, no icons, no screenshots.
- No existing color tokens or type ramp.

Everything here is designed _from scratch_ rooted in the PRD's principles, native macOS Sonoma conventions, and the friendly Chinese voice the PRD models. **Treat this as a v0 proposal, not an extraction.**

---

## At a glance

Tally is two surfaces stitched together:

1. **Menu bar popover** — the 3-second glance. Big number, progress bar, top 5 apps, "open full window" button.
2. **Main window** — a fixed 960×640 NSWindow with a 200px sidebar and 760px content area. Sections: **總覽** (Overview), **設定** (Settings) for MVP; **Apps / 歷史 / 網路** added in v0.2.

There is also a three-step full-screen onboarding (welcome → grant Network Extension permission → set billing cycle + cap).

### Design priorities (from PRD §15)

1. **數字優先** — the biggest element on screen is always "how much you used this month."
2. **不要 dashboard 化** — no five-chart dashboards. One screen, one answer.
3. **永遠用人話** — never `mDNSResponder`, never bundle IDs. iCloud, Spotlight, 軟體更新, etc.
4. **App 用真名+icon** — pulled from `NSWorkspace`.
5. **Scope 守門** — Advanced mode is a future toggle; MVP is one mode only.

---

## CONTENT FUNDAMENTALS

### Voice

Tally talks to the user the way a calm, plain-spoken friend would. Casual, second-person (**你**), direct. Never corporate, never technical, **never cute**.

**Examples of Tally's voice:**

> 這個月用了 **12.4 GB**
> 還可以用 **7.6 GB**（到 6 月 1 日重置）
> 以目前的速度，月底大概會用到 **18 GB**

> 你現在連在 **家裡的 Wi-Fi**

> 你現在用的是 **iPhone 的熱點**，這裡的流量會算進電信費

> Chrome 用了 4.2 GB（佔 34%）

The PRD's seed examples included a few sentence-final 哦 / 啦 modal particles ("要小心一點哦"). **We've dropped those.** They read cute, and Tally should sound calm and direct, not chummy.

### Rules of thumb

- **Person**: always **你**. Never 您 (too formal), never 我們 (too corporate), never passive voice.
- **No sentence-final particles** — drop 哦 / 啦 / 喔 / 喲. They tip into cute. Say what's true plainly.
- **No anthropomorphizing Tally** — don't write 「Tally 會默默幫你…」 / 「靜悄悄打開」. State the behavior directly.
- **Casing in English fragments**: app names and brand terms keep their canonical case (Chrome, iCloud, Wi-Fi, Mbps). All caps reserved for short technical tokens like **GB** / **MB** / **CSV** / **VPN**.
- **Numbers**: always tabular, always with units. Format: `12.4 GB`, `7.6 GB`, `34%`. Never `12.4GB` (need the space).
- **Dates**: locale-aware Chinese form. `6 月 1 日` not `June 1` or `6/1`.
- **Emoji**: **none in product UI**. The PRD doesn't use any. Tally's warmth comes from word choice, not emoji.
- **Punctuation**: full-width Chinese punctuation (，。「」) when in Chinese sentences. Half-width inside English fragments.

### Vocabulary (per PRD §7 terminology table)

The PRD has an explicit translation table from "Advanced mode" technical terms to "General mode" plain language. **General mode wins in MVP.**

| Concept | ❌ Don't say | ✅ Do say |
|---|---|---|
| Upload / Download | Upload / Download | **傳出 / 收進** |
| Billing cycle start day | Billing cycle | **每月從幾號開始算** |
| Monthly cap | Monthly data cap | **每月可以用多少** |
| Tethering | Hotspot / Tethering | **手機熱點** |
| Threshold | Threshold | **提醒時機** |
| Process | Process | **app** or **程式** |
| Aggregate by app | Aggregate by app | **依 app 分類** |
| Throughput / Mbps | Mbps | **目前速度（用 MB/s）** |
| Network Extension permission | Network Extension | **允許 Tally 看到網路使用情況** |

Bundle IDs, process names, SSIDs **never appear in general-mode UI**. They're allowed in Advanced mode only (v0.3+).

### The "我媽看得懂嗎" test

PRD §1: every term and label must pass "would my mom understand this?" If you're tempted to use a term of art, find a plain-language version first.

---

## VISUAL FOUNDATIONS

### Vibe

Native macOS Sonoma, **leaning warmer than Activity Monitor**. The competitors (Activity Monitor, TripMode, Bandwidth+) are cold and technical; Tally's job is to feel like a friendly counter on your menu bar — tally marks scratched on a wall, not a system dashboard.

The brand color is a **warm honey/amber** (`#E89B2F`). It plays well against macOS's neutral chrome, reads as "counting / running tally," and feels human compared to the typical purple-blue data-viz palette.

### Color

- **Brand**: a single warm amber. One accent, used sparingly — on primary CTAs, the progress bar fill, and the menu bar icon when over budget.
- **Status**:
  - `success` (green) — "you're well within limits."
  - `warning` (amber, same family as brand) — "80% used."
  - `danger` (red) — "over the cap."
- **Neutrals**: a 12-step warm grey ramp from near-white (`#FAF9F7`) to near-black (`#15130F`), tuned to feel slightly cream rather than pure cool grey. Foreground tiers: `fg1` (primary), `fg2` (secondary), `fg3` (tertiary / hints), `fg4` (disabled).
- **Surface tiers**:
  - `bg-app` — the main window background.
  - `bg-sidebar` — slightly more vibrant, mimics `.sidebar` material.
  - `bg-card` — elevated card surface inside content.
  - `bg-popover` — menu bar popover (with subtle translucency in implementation).
- **Dark mode** is a first-class peer. Defined as a sibling `:root[data-theme="dark"]` block in `colors_and_type.css`. Tally's amber stays the same hue in dark; neutrals invert.

### Type

System fonts only — that's what makes it feel native.

- **Display / large numbers**: `-apple-system, "SF Pro Display"` — tabular numerals, weight 600, tracked tighter (-0.02em) at large sizes.
- **Body / UI**: `-apple-system, "SF Pro Text"` at 13–15px.
- **Monospaced (numbers in tables, technical strings)**: `"SF Mono", ui-monospace`.
- **Chinese**: relies on the OS's CJK fallback (PingFang TC on macOS). No custom CJK fonts; matches every other Mac app.

The **big number** on Overview is the single largest type element in the whole app: **64px / weight 600 / tabular**. Nothing else competes with it.

### Spacing & rhythm

4-px base unit. Tokens: `s1=4, s2=8, s3=12, s4=16, s5=20, s6=24, s8=32, s10=40, s12=48, s16=64`. Most card padding is `s4` (16). Sidebar items have `s3` vertical / `s4` horizontal.

### Corners

Soft. **8px** for cards, **6px** for buttons and inputs, **10px** for the popover and window-rounded surfaces, **12px** for the largest hero card on Overview. Never sharp 0px corners except inside data tables.

### Borders

`1px solid` of a low-contrast neutral (`#E8E5DE` in light, `#2A2722` in dark). Borders are the primary way Tally separates surfaces — heavier than dividers, lighter than shadows. **Cards are bordered, never floated with shadow.**

### Shadows

Used **only** in two places, and never decoratively:

1. **Menu bar popover** — system-style elevation: `0 12px 32px -8px rgba(0,0,0,0.18), 0 2px 6px -2px rgba(0,0,0,0.10)`.
2. **Onboarding modal** — same elevation, heavier.

No shadow on cards, buttons, or sidebar items. macOS isn't a Material Design surface.

### Backgrounds

- Plain. No gradients. No textures. No hand-drawn illustrations.
- Implementation-side: the main window uses `.windowBackground`; the sidebar uses `.sidebar` material; the popover uses `.menu` / `.hudWindow` material. CSS approximates with flat fills + subtle border.
- **No emoji as iconography. No gradient hero backgrounds.**

### Animation

Native macOS easing, native macOS speed.

- **Easing**: `cubic-bezier(0.4, 0.0, 0.2, 1)` (standard) for most things. `cubic-bezier(0.32, 0.72, 0, 1)` (springy decel) for the popover open.
- **Duration**: 150ms for hovers, 200ms for state changes, 280ms for the popover, 320ms for view transitions inside the main window.
- **Bounce**: none. No overshoot.
- **Big number on Overview** animates from previous value to new value with a tween on first paint of the session (then static).

### Hover / press

- **Hover** on rows and list items: a 5% darken of the background (`bg-hover` token). On buttons: 7% darken.
- **Press**: another 4% darker than hover, no scale transform. macOS apps don't shrink-on-press.
- **Focus**: the system `accentColor` outline, `2px` with `2px` offset.

### Cards

A Tally card is: **1px border, 8px radius, `bg-card` fill, no shadow, padding 16px**. App-row cards on Overview are 56px tall, with a 32px app icon at left, name + subcopy in the middle, and a right-aligned `GB / %` cluster.

### Layout rules

- **Fixed sizes**: the main window is **not resizable**. 960 × 640. Sidebar is exactly 200px; content is exactly 760px wide minus padding.
- **Density**: medium-comfortable, matching Apple's `.regular` control size. Not as dense as Finder list view, not as airy as a marketing site.
- **Sidebar** is always visible. No collapse.

### Iconography (full section below)

Stick to **SF Symbols**. See [ICONOGRAPHY](#iconography).

---

## ICONOGRAPHY

### Strategy

Tally is a native macOS app. **SF Symbols is the entire icon system.** Don't introduce a second icon set. SF Symbols ships with macOS, matches the system font's weight axis, and is what every other Mac app uses — that's exactly the consistency we want.

In SwiftUI: `Image(systemName: "chart.bar.fill")`.

In this design system's HTML mocks: we don't have access to SF Symbols' actual font file (it's licensed for use _in_ apps, not for arbitrary web hosting). We use **two substitutes**, both clearly flagged:

1. **SF Symbol names** in our component code as comments — so when the Swift implementation happens, the exact symbol name is recorded.
2. **Lucide** ([lucide.dev](https://lucide.dev)) loaded from CDN as the visual stand-in. Lucide's 1.5px-stroke outline style is the closest open-source match to SF Symbols' regular weight.

> ⚠️ **Substitution flag for the user**: SF Symbols isn't installed; the HTML previews use Lucide as a visual proxy. The SF Symbol name to use in Swift is recorded as `data-sf-symbol` on each icon, e.g. `data-sf-symbol="chart.bar.fill"`. When you ship the real app, replace with `Image(systemName:)` calls.

### System-process category icons (PRD §8)

These appear in the Top-N list when a system process is rolled up. Each category has its own symbol:

| Category | SF Symbol | Lucide stand-in |
|---|---|---|
| **iCloud** | `icloud.fill` | `cloud` |
| **Time Machine 備份** | `externaldrive.fill.badge.timemachine` | `hard-drive` |
| **軟體更新** | `arrow.down.circle.fill` | `arrow-down-circle` |
| **Spotlight 搜尋** | `magnifyingglass` | `search` |
| **系統其他** | `gearshape.fill` | `settings` |

App icons (Chrome, Slack, etc.) come from `NSWorkspace` at runtime — not in this design system. The HTML mocks use **flat colored squares with the app's initial** as a placeholder, with a `data-app-icon="<bundle-id>"` attribute marking where the real icon goes.

### Emoji

**Not used in product UI.** The PRD doesn't use any.

### Unicode glyphs as iconography

Allowed only for one place: the **menu bar icon** itself, which is a tally-mark glyph (`||||̸` or a custom-drawn equivalent). Everywhere else uses SF Symbols.

### Logo

Tally has no logo in source. **I've designed a placeholder logo** (in `assets/logo.svg`): four tally marks with the fifth as a crossing stroke — the universal "5" tally. Honey-amber on a light cream square. Treat this as **a proposal**, not a final mark.

---

## Files in this project

```
README.md                   ← you are here
SKILL.md                    ← agent-skill entry point
colors_and_type.css         ← all CSS variables + typography rules
fonts/                      ← (empty — Tally uses system fonts only)
source/PRD.md               ← mirror of the source PRD
assets/
  logo.svg                  ← proposed Tally logo
  logo-mark.svg             ← logo glyph alone (no wordmark)
  menubar-icon.svg          ← menu bar template icon
  app-icon-placeholder.svg  ← stand-in for app icons pulled from NSWorkspace
preview/                    ← design-system tab cards (one per concept)
ui_kits/
  macos_app/
    README.md
    index.html              ← interactive prototype: popover → main window → onboarding
    *.jsx                   ← reusable components
```

### Index

- **Foundations**: see `colors_and_type.css` and the `preview/` cards in the Design System tab.
- **Iconography**: see [#iconography](#iconography); SF Symbols in production, Lucide for HTML mocks.
- **Components**: `ui_kits/macos_app/` — open `index.html` for the click-through.
- **Brand**: `assets/`.

---

## Caveats

- **Designed from a PRD with no visual assets.** No codebase, no Figma, no screenshots — so the visual direction (honey-amber accent, warm-neutral ramp, macOS-Sonoma idiom) is a _proposal_. The user should review and steer.
- **Logo is a placeholder.** I drew it from the "tally marks" concept; a real designer should do a pass.
- **SF Symbols substituted with Lucide** in HTML; the SwiftUI implementation should use real SF Symbols. Every icon stand-in carries `data-sf-symbol` for the lookup.
- **Fonts**: macOS system fonts, so there's nothing to ship in `fonts/`. If the OS-fallback PingFang TC isn't acceptable for marketing material, a brand CJK face will need sourcing.
