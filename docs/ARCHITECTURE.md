# Crystal Slash — Architecture Overview

Hyper-casual arcade slicer. Godot 4.7 (GDScript, typed), Android-first, portrait, 60 FPS.

## Folder layout

| Folder | Purpose |
|---|---|
| `assets/` | Raw content: sprites, sounds, music, particles, fonts |
| `scenes/` | Reusable `.tscn` scenes, grouped by domain (menu, game, ui, player, crystals, effects) |
| `scripts/` | GDScript files, mirroring the scene domains + `managers/` |
| `autoload/` | Singleton managers registered in Project Settings → Autoload |
| `addons/` | Third-party plugins (ads SDK wrapper later) |
| `docs/` | Design + architecture notes |

## Core principles

- **Signals up, calls down** — children emit signals, parents call methods. No child ever reaches up the tree.
- **Composition over inheritance** — crystals are one scene configured by resource data, not 11 subclasses.
- **Singleton managers** (autoload): GameManager, AudioManager, SaveManager, UIManager, EffectsManager, AdsManager (stub until launch).
- **Object pooling** for crystals and particles — zero allocations during gameplay.
- **Typed GDScript everywhere** — catches bugs at parse time, faster at runtime.

## Display / rendering decisions

- Base viewport **720×1280**, stretch mode `canvas_items`, aspect `expand` — crisp UI on every phone aspect ratio.
- Renderer: **Mobile** — best fill-rate on Android GPUs.
- `emulate_touch_from_mouse` ON — swipe gameplay is testable on desktop with the mouse.

## Deferred integrations (architecture prepared, implemented later)

- Ads: rewarded / interstitial / banner behind an `AdsManager` interface.
- Google Play Games: achievements, leaderboards, cloud save behind a services facade.
