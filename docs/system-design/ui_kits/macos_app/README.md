# Tally · macOS App UI Kit

The single UI kit in this design system — Tally is one product (a macOS menu bar app).

## What's here

- **`index.html`** — a clickable prototype. Click the **menu bar tally icon** to open the popover, **"打開完整畫面"** to bring up the 960×640 main window, or **"重新跑一次 onboarding"** in Settings to walk through the three-step welcome.
- **`MenuBar.jsx`** — the fake desktop menu bar at top (with status icons + clock + tally icon).
- **`Popover.jsx`** — the menu bar popover. Big number, progress, top-5 apps, "open full window" button.
- **`MainWindow.jsx`** — the 960×640 NSWindow with traffic lights, sidebar, content router.
- **`OverviewScreen.jsx`** — the **總覽** screen: hero big-number, top-10 apps.
- **`SettingsScreen.jsx`** — the **設定** screen: billing cycle, cap, alerts, autostart.
- **`Onboarding.jsx`** — full-screen three-step modal (Welcome → Permission → Settings).
- **`shared.jsx`** — small primitives reused across screens (`AppIcon`, `Progress`, `Card`, `Row`).

## What it's NOT

- It is **not** the real Swift code. It's a visual + interaction recreation in HTML/JSX, intended to specify the look and feel for the actual SwiftUI implementation.
- Data is hardcoded mock data drawn from PRD §7 examples (12.4 GB, Chrome 4.2 GB, etc.).
- App icons are placeholders (initial letter + deterministic hue). Real Mac app would use `NSWorkspace` icons.

## How to read it as a spec

Open `index.html`. Compare side-by-side with PRD §6 (UI architecture) and §7 (copy). Every visible string is lifted from the PRD where possible.
