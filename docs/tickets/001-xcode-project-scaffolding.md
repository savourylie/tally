# [TICKET-001] Xcode project scaffolding

## Status
`pending`

## Dependencies
- Requires: None

## Description
Create the foundation Xcode project for Tally — a macOS 14+ SwiftUI app with both a `MenuBarExtra` and a `Window` scene. This is the bootstrap ticket: every other ticket depends on it. The shell does nothing yet beyond rendering placeholder content in both scenes; subsequent tickets fill in tokens, data, and views.

The project must be a native Xcode project (not a pure Swift Package) because the v0.3 roadmap requires a Network Extension target with entitlements (TICKET-023), and entitlements + provisioning profiles need an Xcode project structure.

## Acceptance Criteria
- [ ] `Tally.xcodeproj` exists at repo root, opens in Xcode, builds with no warnings or errors targeting macOS 14.0 minimum
- [ ] `App.swift` (or equivalent entry) declares both a `MenuBarExtra` and a `Window` scene, each rendering placeholder content
- [ ] `Assets.xcassets/AppIcon.appiconset/` is populated with PNGs at all required macOS sizes (16, 32, 64, 128, 256, 512, 1024 @1x/@2x) generated from `docs/system-design/assets/` logo source
- [ ] Running the built app shows a tally-mark menu bar icon in the menu bar
- [ ] `.gitignore` covers `*.xcuserdata/`, `DerivedData/`, `.build/`, `.swiftpm/`, build outputs

## Design Reference
- **Logo / AppIcon source**: `docs/system-design/assets/` (logo SVG)
- **Menu bar icon source**: `docs/system-design/assets/` (menu bar icon SVG — the tally-mark glyph) — fall back to an SF Symbol placeholder if the asset is not ready

## Visual Reference
After build + run, a tally-mark icon appears in the macOS menu bar. Clicking it opens an empty popover (the placeholder for TICKET-010). The app icon visible in the Finder / Dock is the honey-amber tally-mark glyph on the cream square per the design system proposal. The placeholder `Window` scene is reachable via a debug menu entry or auto-shown on launch.

## Implementation Notes
- **Bundle identifier**: suggest `com.calvinku.Tally` — confirm before first build/signing
- **Language**: Swift 5.9+ (we need `@Observable`)
- **Interface**: SwiftUI
- **Deployment target**: macOS 14.0
- **Scenes**: `MenuBarExtra("Tally", systemImage: "chart.bar.fill") { Text("Placeholder") }` and `Window("Tally", id: "main") { Text("Placeholder") }` — real content arrives in later tickets
- **AppIcon generation**: use `sips` from the SVG, or `rsvg-convert`/Sketch/Figma. The design system describes the logo as proposal-grade — treat it as a working stub, not final art
- **Folder layout**: prefer `Tally/Sources/` and `Tally/Resources/` over Xcode's flat default; document in a top-level `README.md` if you reshape the template
- This ticket explicitly does NOT touch network or storage — that's TICKET-003 / TICKET-006

## Testing
- Open `Tally.xcodeproj` in Xcode → ⌘B succeeds, zero warnings
- ⌘R launches the app → menu bar icon appears
- Quit and relaunch → icon comes back (no state expected to persist yet)
- Verify the AppIcon shows in the Dock and in `Finder > Applications` after archiving a build
