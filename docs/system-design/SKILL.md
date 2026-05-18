---
name: tally-design
description: Use this skill to generate well-branded interfaces and assets for Tally — a macOS menu-bar app for tracking network data usage with a friendly Traditional-Chinese voice. Use for production code, throwaway prototypes, mocks, slides, or visual artifacts.
user-invocable: true
---

# Tally · design skill

Tally is a macOS menu bar app that tells the user, in plain Chinese (Traditional / Taiwan), how much network data their Mac used this month, which apps are the culprits, and how much budget is left. The brand is **warm, conversational, native-Mac, number-first**.

## How to use this skill

1. Read `README.md` for the full context — product overview, content fundamentals (voice / vocabulary), visual foundations (colors / type / motion), and iconography rules.
2. Inspect `colors_and_type.css` for the canonical color and type tokens. Always reuse these CSS variables rather than redefining values.
3. Browse `preview/` to see live examples of every foundation card (typography scale, color ramps, spacing, motion, all component states).
4. Open `ui_kits/macos_app/index.html` for a clickable prototype showing how the foundations compose into the menu bar popover, 960×640 main window, and three-step onboarding.
5. Visit `assets/` for logo, mark, and menu bar template icon SVGs.

## Working with this skill

- **If creating visual artifacts** (slides, mocks, throwaway prototypes, screenshots, marketing material): copy assets out of `assets/` and reference `colors_and_type.css`. Build static HTML files for the user to view. Use the JSX components in `ui_kits/macos_app/` as a starting point.
- **If working on production code**: this is a SwiftUI app. Treat the JSX in `ui_kits/macos_app/` as visual spec, not source. Replace Lucide icons with real `Image(systemName:)` SF Symbols — every icon stand-in carries a `data-sf-symbol` attribute with the correct name. Replace placeholder `AppIcon` letters with `NSWorkspace` icons. Lift hex codes, spacing tokens, and copy directly from `colors_and_type.css` and `README.md`.

## Critical voice rules (do not violate)

- Always **你** (second-person, casual). Never 您, 我們, passive voice.
- Plain Chinese only in product UI. **Never** show `mDNSResponder`, bundle IDs, SSIDs, or technical terms (see `README.md` § Content Fundamentals → vocabulary table for the substitutions).
- Big numbers are the loudest element on every screen.
- No emoji in product UI.

## If invoked without specific guidance

Ask the user what they want to build, then ask 3–5 design questions (audience, surface — popover vs main window vs marketing, light vs dark, the specific message), then build a static HTML artifact in this project. Act as an expert macOS designer who knows the Sonoma idiom and Tally's warm-amber palette by heart.
