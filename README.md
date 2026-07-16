# Carrom Clash 🎯

Desi carrom on your phone — flick the striker, pocket your goti, grab the rani.
**2 players, one phone, fully offline.**

Built with **Godot 4.7** (GDScript) for Android-first release. Targeted at the
Indian mass market: tiny footprint, no tutorial needed, pass-and-play social.

## How to play
- Drag the **striker** sideways along your baseline to position it
- **Flick** (drag toward your target) anywhere else to shoot — longer drag = more power
- The aim guide shows exactly where the striker will connect; the tick on the
  target coin is **green** for your goti, **red** for the opponent's
- **P1 = white (safed), P2 = black (kali)** — pocket your own color for +10,
  pocket theirs and the points go to them ("galat goti!")
- The red **rani** is worth 50, open to both
- Pocket the striker = foul, −20. Turns alternate every shot; each player
  shoots from their own side of the board.

## Project layout
| Folder | Purpose |
|---|---|
| `autoload/` | Singleton managers: Save, Audio, Effects, Game |
| `scripts/game/` | The carrom game (board, physics, turns — procedurally built) |
| `assets/sounds/` | Procedurally synthesized SFX (see `tools/generate_sfx.gd`) |
| `docs/` | Design doc, architecture notes, market research |
| `tools/` | Dev tooling (sound generator) |

## Development
- Open with Godot 4.7+ (`project.godot`)
- Headless smoke test: `godot --headless --path . --quit-after 120`
- Regenerate sounds: `godot --headless --path . -s res://tools/generate_sfx.gd`

## Roadmap
- [ ] Vs-computer opponent (solo play)
- [ ] WhatsApp challenge share (beat-my-score link)
- [ ] Main menu, modes, settings
- [ ] Android export + Play Store release

---
*History: this repo began as swipe-arcade prototypes (Crystal Slash → Pani Puri
Panic) before pivoting to carrom — see git history and `docs/MARKET_RESEARCH.md`
for the evidence behind the pivot.*
