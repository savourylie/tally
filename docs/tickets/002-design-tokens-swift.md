# [TICKET-002] Design tokens (Swift)

## Status
`pending`

## Dependencies
- Requires: #001 ✅

## Description
Port every named design token from `docs/system-design/colors_and_type.css` into Swift so the SwiftUI codebase can reference tokens by name (e.g., `Color.tally.accent`, `Font.tally.mega`) instead of inline hex/pt values. Every subsequent UI ticket reads from these tokens — getting them right now prevents drift between the design spec and the implementation later.

The CSS file defines colors (brand ramp, status, neutrals, surface tiers, foreground tiers, borders), typography (font stacks, type scale, weights, line heights, letter-spacing), spacing scale, border radii, motion durations + easings, and shadow definitions. Each lands in a separate Swift file grouped under `DesignTokens/`.

## Acceptance Criteria
- [ ] All color tokens from `colors_and_type.css` exist as `Color` extensions and resolve to the documented hex values in both light and dark mode (dark mode uses the `:root[data-theme="dark"]` block in the CSS source)
- [ ] All typography tokens exist as `Font` extensions: `mega` (64), `display` (34), `title1` (22), `title2` (17), `title3` (15), `body` (13), `callout` (12), `caption` (11) — using SF Pro Display / SF Pro Text / SF Mono per the CSS `--font-*` stacks
- [ ] Spacing scale (`s1`–`s16` → 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64 pt) exists as `CGFloat` constants
- [ ] Radius tokens (`r6`, `r8`, `r10`, `r12`) exist as `CGFloat` constants
- [ ] Motion tokens exist: durations (`hover` 150ms, `state` 200ms, `popover` 280ms, `view` 320ms) and easings (`standard` cubic-bezier(0.4, 0, 0.2, 1), `decel` cubic-bezier(0.32, 0.72, 0, 1))
- [ ] A SwiftUI `#Preview` file renders a swatch grid showing every color, type sample, spacing rule, and radius — verifiable side-by-side with `docs/system-design/preview/` HTML demos

## Design Reference
- **Source of truth**: `docs/system-design/colors_and_type.css`
- **Preview references**: `docs/system-design/preview/typography.html`, `spacing.html`, `colors.html`, `motion.html`

## Implementation Notes
- **Files to create**: `DesignTokens/Color+Tally.swift`, `DesignTokens/Font+Tally.swift`, `DesignTokens/Spacing.swift`, `DesignTokens/Radius.swift`, `DesignTokens/Motion.swift`, `DesignTokens/TokensPreview.swift`
- **Color namespacing**: `extension Color { enum tally { static let accent = ... } }` — or a `TallyColor` enum if you prefer; pick one and stay consistent. Avoid polluting `Color` with bare static lets
- **Dark mode**: use `Color(light:dark:)` initializer via `UIColor`/`NSColor` bridging, or asset catalog colors with light/dark variants — whichever is more maintainable
- **Cubic-bezier in SwiftUI**: SwiftUI doesn't expose `CAMediaTimingFunction` directly — wrap as `Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.28)` etc.; expose as `static let decelPopover: Animation`
- **Fonts**: the CSS uses SF Pro Display for `--font-display` and SF Pro Text for `--font-text`. SwiftUI auto-selects optical sizes when you ask for `.system(size:weight:design:)` — confirm visual parity before adding custom font loading
- **Numeric digits**: PRD requires tabular figures for the mega number — add `.monospacedDigit()` on the `.mega` font or set `.featureSettings([.init(tag: "tnum", value: 1)])`
- **Letter-spacing**: `.mega` requires −0.022em tracking; in SwiftUI use `.tracking(-1.4)` (64pt × −0.022 ≈ −1.4) and recompute per type size

## Testing
- Open `TokensPreview.swift` in Xcode's canvas → swatches render
- Open `docs/system-design/preview/colors.html` in a browser at the same display scale — visually compare; hex values must match
- Inspect `Color.tally.accent` in Light mode → `#E89B2F`; in Dark mode → same hue per CSS dark block
- Inspect a `Text("Tally").font(.tally.mega)` preview → 64pt SF Pro Display, weight 600, tracking applied
