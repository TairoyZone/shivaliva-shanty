# Shivaliva Shanty — Project Report

_Last updated: 2026-06-06_

## What it is
A single-player-first, retro-charming **puzzle-skill adventure** among floating sky-islands — a
spiritual successor to *Puzzle Pirates*, but its own thing. Solo dev (Troy). **Godot 4.6, GDScript, GL
Compatibility, 1280×720, no build step** (run `main.tscn`, or any `puzzles/*/<name>.tscn` standalone).
Windows / OneDrive, git-backed. Sky-pirates among floating islands (not sailors on water) — every water
term is reskinned to a sky/Stardust equivalent ("the Stardust" = the abyss below).

## Status: MVP LOCKED → polishing for a public demo
**Locked 2026-06-05:** the core loop is done. **7 puzzles is the final count — no more puzzles.** The
work now is **polish + solidify** for a public **demo on Itch.io** (Troy is lining up playtesters). The
2nd island (Driftspar) stays intentionally empty for now. Default work = bug-fix / feel-tune / smooth
onboarding, not new content.

**The 7 puzzles:**

| Puzzle | What it is |
|---|---|
| **Loft** | Bilging reskin — 2-wide free-swap match-3, keep the ship aloft above the rising Stardust |
| **Skirmish** | From-scratch versus-Tetris — clear lines → send garbage → top out the foe (the combat puzzle) |
| **Mining** | YPP foraging reskin — rotate a 2×2 cursor, dig ore chunks |
| **Gem Drop** | YPP Treasure-Drop reskin — 2P turn-based puzzle |
| **Poker** | Texas Hold'em with an NPC cast + a parlor lobby (pick-a-seat / invite) |
| **Lumberjacking** | YPP carpentry reskin — pair-fall, fuse 2×2 blocks into planks |
| **Patchworks** | Block-blast hull-repair — fill a row/column to seal the ship's holes |

## The world + economy
- **Cradle Rock** (the playable island): shore, tavern, forest, mine, interiors, the Skydock. A locked
  **8-NPC cast** (Brian, Jericho, Kerr, Troy, Godfrey, Mia, Jade, Ellison) with jobs + puzzle pipelines.
- **Economy:** ONE earned currency = **gold**. Earn-and-keep — no decay, no upkeep, no premium
  currency, no pay-to-win. (Legally safe *only* while gold stays earn-only — never real-money-purchasable.)
- **Multiplayer direction (decided, not yet built):** co-op (Stardew-style, ~4–8p, one shared world) +
  a thin global **parlor** social layer for real-time minigames. NOT an MMO. Build co-op-ready now; no
  netcode yet.

## The headline meta-system: the voyage (pillage)
The endgame loop, reskinned from YPP pillaging. You job onto a crew at the Skydock → board an isometric
**ship deck** → give the captain the word at the **helm** to **set sail**:
- The **deck then sails the whole route on its own** (set-sail-once — each leg's duty report flows
  straight into the next) at the crew's pace.
- **Man the Loft** (fly her / keep aloft) **or the Patchworks** (mend the hull) **any time while she
  sails**; leave a station and you're back on the still-sailing deck (re-man, switch, or just watch).
- At an encounter she triggers a **boarding** (crew-vs-crew Skirmish team fight); you arrive at Driftspar
  for your cut.
- The ship is **sinkable**: damage → hull holes → the Stardust floods faster in the Loft → sink on a fight
  leg = "Lost in the Stardust."

**The boarding is a LIVE BACKGROUND MELEE:** the fight runs in a persistent simulation (a `BoardingMelee`
autoload) whether or not you're watching — your AI mates trade blows, your undefended board buries
itself, a side can win/lose on its own. You can **step away** to the deck (which locks the stations and
shows "Rejoin the boarding"), let it fight on, and **rejoin** where you left it (or see the result if it
finished). Adversarially reviewed (3 bugs fixed) + several playtest fixes already landed.

## Architecture (the patterns to copy)
- **`PlayerState`** (autoload) — the data spine: gold, backpack/items, per-puzzle mastery (high-water-mark),
  NPC affinity, ships, flags, scene-transition handoff, all voyage state. Persisted via ConfigFile.
- **`HUD` / `Overlay`** (autoloads) — the overworld HUD + the NPC dialog overlay.
- **`BaseLocation`** — walkable overworld scenes spawn the player + resolve spawn points.
- **`Interactable` → `Puzzle` / `Npc` / `Door` / `Building`** — the prop hierarchy (E to interact).
- **Puzzle = a Board + a Scene:** the Board is the logical engine (grid + child piece-nodes + an async
  cascade resolver that *awaits* every animation); the Scene (`PuzzleScene`) hides the HUD, owns Leave +
  a "?" help button, and banks rewards via `record_puzzle_result`.
- **`VoyageStationScene`** — the shared base for a puzzle manned as a voyage station (Loft/Patchworks):
  chart sail, board-on-encounter, resolve, continuous next-leg.
- **`BoardingMelee`** (autoload) — the persistent crew-fight sim that survives scene changes.

## Standing rules (don't violate)
- **Placeholder-first art** — procedural `_draw()` shapes + flat colors. No asset-lifting.
- **Animate everything** — every state change is a shown, awaited motion, never an instant pop-in.
- **Instructions behind a "?"** button, never a strip under the board.
- **No persistent on-screen objective banner** — objectives live in the journal (! / J).
- **Inheritance over duplication; scene-per-component.**
- Build proactively, flag only big design forks; commit freely; **never push without an explicit ask.**

## Recent work (2026-06-05 → 06, all committed)
1. **Demo readiness:** all 6 demo blockers + the entire readiness-sweep polish tail (Patchworks
   results-celebration + blast animation, HUD backpack bag-bump, the `I`-key, the bed responds to E,
   Skirmish "READY?" lead-in + garbage explained + duel weapon swatch, Loft voyage help, voyages-board
   free-crew-first, event-feed corner, NPC dialog "[E] to close", work-site tooltips, poker
   stakes-on-felt, dead-code removal).
2. **Parlor redesign:** lobby opens straight to create-a-table → pick a seat → buy in → invite NPCs
   (between hands too) → dropdowns for config → adversarially reviewed.
3. **Live-melee boarding:** the big refactor above (persistent `BoardingMelee` autoload) + a 5-dimension
   adversarial review (3 bugs fixed) + playtest fixes (chart parks at the swords on step-away; Loft voyage
   HUD layout fix).
4. **Voyage flow → "captain sets sail" (2026-06-06):** the deck now drives the crossing — set sail at the
   helm, she sails the whole route, man stations freely while sailing, and leaving a station keeps you on
   the still-sailing deck (no snap-back to the island). + deck arrival shows the booty haul card.
5. **Stardust gem shader:** a `canvas_item` shader on the Loft — drifting, spinning **diamond** gems that
   twinkle + glow in jewel hues (blue/purple/pink/red), reddening with the Stardust's bite.
6. **Mined `godot-4-new-features` → `GODOT_BORROW_TODO.md`:** a 7-agent analysis → a prioritized, checkable
   backlog of patterns to borrow (audio · visual juice · UI/dialogue · GDScript-data · co-op-ready).
7. **Audio spine (borrow #1):** an `Audio` autoload (polyphonic SFX bank + music player) with 9 **procedural**
   placeholder `.wav` synthesised in-engine (no lifted audio); first call site = the gold "coin".

## What's next
- **Wire the rest of the audio call sites:** `Audio.play_sfx` into puzzle clears (clack/pop), UI (click),
  win/results (chime), toss/invalid (buzz) — the polyphony shines on cascades. Then continue down
  `GODOT_BORROW_TODO.md` (Juice tween helper → sky shader → typewriter dialogue → …).
- **Eyeball + tune** the Stardust gem shader in-editor (density / spin / hues).
- **Playtest** the new set-sail voyage flow; tune the brigand-crew fight + the deck-sail pace.
- **Troy's TODO** (bottom of this file) — several items now have a concrete blueprint from the godot mining.
- **Post-demo (deferred):** co-op netcode, parlor tournaments, filling Driftspar, a real soundtrack.

---
_This report is a living snapshot — regenerate it as the project moves. Deeper design history + locked
decisions live in the auto-memory (`…/memory/MEMORY.md`); the code map lives in `CLAUDE.md`._

# TROY's TODO #
# = players can chat with NPC. Use API for this one to respond intelligently
# = Player should be able to start a crew, and hire crew members and assign their ranks
# = Time to dive in deeper with the ship owning system