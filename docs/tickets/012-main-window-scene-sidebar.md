# [TICKET-012] Main window scene + sidebar

## Status
`blocked`

## Dependencies
- Requires: #002 ✅, #011

## Description
Build the main window — a 960×640 non-resizable, draggable `Window` scene with a 200pt sidebar on the left and a 760pt content area on the right. PRD §6.2 specifies the fixed dimensions; PRD §10 specifies lazy lifecycle: "Main window lifecycle：lazy 建立，關掉就釋放，避免常駐記憶體".

The sidebar exposes two items in MVP: **總覽** (Overview) and **設定** (Settings). Tapping each routes the content area. v0.2 adds Apps / 歷史 / 網路 — PRD §6.2 reserves them as future entries; do not stub them in this ticket.

The content area is empty for this ticket (`Text("Overview placeholder")` and `Text("Settings placeholder")`). Subsequent tickets fill in the Overview (TICKET-013/014/015) and Settings (TICKET-018) bodies.

## Acceptance Criteria
- [ ] `Window("Tally", id: "main")` in the app scene tree, fixed 960×640 size (`.windowResizability(.contentSize)` with frame modifier) — non-resizable, draggable
- [ ] On close, the window scene and its view tree deallocate (verified via Instruments / a `deinit` log on the root content view); on reopen (via popover button or `openWindow(id:)`), the scene rebuilds
- [ ] Menu bar continues to run after main window close — closing main does NOT quit the app (`.windowResizability(.contentSize)` + `.windowToolbarStyle` + no explicit `NSApp.terminate` link)
- [ ] Sidebar fills 200pt width with `--bg-sidebar` background (`#F4F2EC` light / dark equivalent), uses `NSVisualEffectView` material `.sidebar` for native look
- [ ] Sidebar items: 總覽 (icon `chart.bar`), 設定 (icon `gearshape`). Selected item has accented background; hover has 5% darken; tap selects
- [ ] Selected sidebar item drives content area: 總覽 → Overview placeholder, 設定 → Settings placeholder
- [ ] Selection persists across window close/reopen within a session (in-memory; restoration across app restart is out of MVP scope per PRD §3 implicit)

## Design Reference
- **Layout**: `docs/system-design/ui_kits/macos_app/Sidebar.jsx`, `MainWindow.jsx`, `OverviewScreen.jsx` (for placeholder content area shape)
- **Tokens**: `--bg-app`, `--bg-sidebar`, `--fg-2`, `Spacing.s4` (sidebar item padding), `Radius.r6` (selected item)

## Visual Reference
Opening the main window shows a fixed-size 960×640 window. Left 200pt is a slightly warmer-cream sidebar that says "Tally" in small caps at the top (optional logo lockup), then two stacked rows: a chart icon + "總覽" and a gear icon + "設定". The selected row has a muted honey-amber tint background. The right 760pt area shows whichever pane was selected — for now, just placeholder text. The window has a draggable title bar but no resize handles. Closing the window does NOT quit the app; the menu bar icon stays visible.

## Implementation Notes
- **Files to create**: `MainWindow/MainWindowScene.swift` (the `Window` scene struct or its content view), `MainWindow/Sidebar.swift`, `MainWindow/SidebarItem.swift`, `MainWindow/SidebarSelection.swift` (an enum)
- **Fixed size in SwiftUI**: `.frame(width: 960, height: 640).windowResizability(.contentSize)` on the scene, combined with `.fixedSize()` on the content. Or use `NSWindow` overrides via `NSWindowAccessor` if the SwiftUI API leaks
- **Lazy lifecycle**: SwiftUI `Window` scenes are lazy by default — content closure not invoked until first `openWindow`. To enforce dealloc on close, ensure the content view does NOT capture `AppState` strongly through closures that outlive the view (use weak captures in `Task`s; cancel observations in `.onDisappear`)
- **Sidebar selection state**: `@State private var selection: SidebarSelection = .overview` on the root content view. Use `NavigationSplitView` only if it gives you the look — otherwise a simple HSplit of two views with manual selection is simpler and more controllable for a fixed-size window
- **Sidebar item style**:
  ```swift
  HStack {
      Image(systemName: icon).frame(width: 16)
      Text(title).font(.tally.body)
      Spacer()
  }
  .padding(.horizontal, Spacing.s4)
  .padding(.vertical, Spacing.s3)
  .background(selected ? Color.tally.accentSubtle : Color.clear)
  .cornerRadius(Radius.r6)
  ```
- **Visual effect for sidebar**: small `NSViewRepresentable` wrapping `NSVisualEffectView(material: .sidebar)` — same helper as the popover translucency from TICKET-010 (reuse it)
- **Routing the popover gear button**: the gear in TICKET-010's popover footer should pass a `Settings` initial selection. Approach options: a) `openWindow(id: "main")` and have the window read a shared `@AppStorage("lastSidebarSelection")` value (simplest); b) a custom URL handler. Wire (a) for now; document trade-off
- **Window menu**: configure `WindowGroup`-style menu commands so `Cmd-N` etc. behave sanely (or disable them — MVP only has the one window). Out of scope: state restoration

## Testing
- ⌘R → click "打開完整畫面" in popover → main window opens at 960×640
- Try to resize by dragging edges → cursor doesn't change, window stays fixed
- Click "設定" in sidebar → right pane shows Settings placeholder
- Click "總覽" → switches back to Overview placeholder
- Close window → menu bar icon still functional; click it → click "打開完整畫面" again → window reopens at same position with last selection
- Open Activity Monitor → memory snapshot before close, after close, after reopen → no growth beyond noise
- Add temporary `print("MainWindow deinit")` in the root content view's `deinit` → fires on close
- Visually compare with `docs/system-design/ui_kits/macos_app/index.html` main-window view
