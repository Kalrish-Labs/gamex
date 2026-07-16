# PANI PURI PANIC — Game Design Document

**Pivot date:** 2026-07-16 (previously "Crystal Slash" — engine retained, theme & loop replaced)

## One-liner
You are a street pani puri vendor. Puris fly from the karahi — swipe to catch
them and serve the queue before customers lose patience. Survive the rush!

## Why this game (for the Indian mass market)
- Instantly recognizable: everyone has stood at a pani puri stall
- Zero tutorial: "catch puri, serve customer" is understood in 3 seconds
- Shareable bragging: "I served 87 plates!" / angry-customer fail moments
- Festival/event potential: Diwali rush, shaadi season, monsoon specials
- Offline, portrait, one thumb, 60 FPS on budget Androids

## Core loop (v1)
1. Puris launch into the air from the karahi at the bottom (ballistic arcs)
2. Player SWIPES through flying puris to catch them → they fill the plate
3. The front customer in the queue needs N puris; plate full → auto-served
   → coins + tip (tip scales with combo), next customer steps up
4. Hazards fly among the puris:
   - RED CHILI — swiping it burns the current plate (lose plate progress)
   - FLY (makkhi) — swiping it disgusts the customer (patience drops hard)
5. Every customer has a PATIENCE bar draining in real time
   - Served in time → happy, coins, tips
   - Patience empty → storms off angrily; 3 angry customers = GAME OVER
6. The rush ramps: more simultaneous customers, faster patience drain,
   more hazards mixed in

## Scoring & currency
- Score = plates served, streak bonuses ("Combo" = consecutive catches
  without touching a hazard or dropping a puri)
- Coins (tips) = soft currency → stall upgrades in the shop (later phase)

## Progression (later phases)
- Endless "rush" mode first (replaces Classic)
- Stall upgrades: bigger plate, faster puris, patience boosters, decorations
- Special items: dahi puri (bonus points), masala boost (slow-motion),
  golden puri (coin burst) — reuses the power-up architecture
- Festival events: seasonal reskins + limited leaderboards

## What survives from Crystal Slash (everything below is DONE)
- Swipe input + glowing trail (SlashController)
- Ballistic flying-object system + object pooling (Crystal → FlyingItem)
- Data-driven item types (.tres resources)
- GameManager (score/combo/lives → re-mapped to plates/streak/angry-customers)
- SaveManager (coins, high score, stats), AudioManager (procedural SFX),
  EffectsManager (bursts, popups, camera shake)
- Difficulty ramp, Game Over flow, HUD wiring

## What gets built new
1. Re-theme flying items: puri, chili, fly (+ specials later)
2. CustomerQueue system: queue slots, orders, patience bars, moods
3. Serving logic: plate fill → serve → tip calculation
4. Stall backdrop (bazaar evening ambience, warm colors)
5. New SFX: crunch, water splash, coin clink, angry huff, vendor bell

## Art plan
Phase 1 (now): code-drawn vector placeholders — prove the fun.
Phase 2 (polish): swap PNG art (AI-generated or commissioned), same names.

## Tone
Warm, funny, slightly chaotic. Hinglish flavor text ("Bhaiya jaldi!",
"Ek plate aur!"). Never mean — angry customers are comic, not stressful.
