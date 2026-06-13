# Shivaliva Shanty — Project Report

_Last updated: 2026-06-13_

## What it is
A single-player-first, retro-charming **puzzle-skill adventure** among floating sky-islands — a
spiritual successor to *Puzzle Pirates*, but its own thing. Solo dev (Troy). **Godot 4.6, GDScript, GL
Compatibility, 1280×720, no build step** (run `main.tscn`, or any `puzzles/*/<name>.tscn` standalone).
Windows / OneDrive, git-backed. Sky-pirates among floating islands (not sailors on water) — every water
term is reskinned to a sky/Stardust equivalent ("the Stardust" = the abyss below).

## Dev journey + velocity (the numbers)
_Recompute these from git each report — first-commit date, `git rev-list --count HEAD`, `.gd`/`.tscn` line counts._
- **Started: ~2026-05-24/25** (first locked design calls) → **~20 days** as of 2026-06-13.
- **358 commits** (git baseline 2026-06-03).
- **~43,000 lines of hand-built game** — **~40,300 GDScript** across **194 `.gd` files** + **~3,000 lines** across **89 scenes** (plus a 242-line key-safe chat proxy).
- **Scope:** a walkable iso overworld + a 9-NPC cast · **7 full mini-games** (each a Board+Scene engine w/ AI +
  animation + mastery) · the **voyage meta-system** (deck, set-sail routes, charts, duty reports, a LIVE
  background boarding melee, sinkable ships) · **AI-powered NPC chat** (LLM via a key-safe proxy — a novel hook,
  situationally aware, talk-moves-the-game) · crew/ship-owning · economy/mastery/trophies/save-load/onboarding ·
  a social parlor · and a **mobile-web (HTML5) port** with full touch controls.
- **What it'd take a normal person:** this scope is realistically **~10–14 months** of solid solo-dev work
  (7 polished mini-games alone ≈ 4–6 months) — **1.5–2+ years for most hobbyists** (many never finish). Troy
  did it in **~20 days → roughly a 20–30× pace.**

## Status: DEMO LIVE on itch.io (Windows + mobile web) → polishing from real play
**Locked 2026-06-05:** the core loop is done. **7 puzzles is the final count — no more puzzles.** Since
**2026-06-11 the page is PUBLISHED** (tairoyzone.itch.io/shivaliva-shanty): a Windows release build plus a
**mobile-web (HTML5) build** (touch controls, a custom loading screen, the chat proxy kept warm) for phone
players. Builds zip to **`build/`** — that is the upload source of truth (`ShivalivaShanty-Web.zip` +
`ShivalivaShanty-Windows.zip`). The work now is **polish + solidify from real-play feedback**; the 2nd island
(Driftspar) stays intentionally empty for now. Default work = bug-fix / feel-tune / smooth onboarding, not new
content. (Public handle: **Trojan Bulldog**; in public copy NEVER say "AI" — frame the chat as "intelligent
NPCs". See [[marketing-voice-rules]].)

**📱 MOBILE / WEB IS NOW A PRIMARY REACH PLAY** (Troy 2026-06-13): YPP fans on Reddit have explicitly asked for a
mobile *Puzzle Pirates*, and a touch-friendly browser build is the cheapest path to that under-served audience —
so mobile-web polish is a strategic priority, not just a side port. The HTML5 build now has on-screen touch
controls for every action puzzle, a centred slidable tab rail, and a corner-button layout that clears each
puzzle's own HUD. Lots still to tune on real devices, but reachability-wise this may be the single best move.

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
  **9-NPC cast** (Brian, Jericho, Kerr, Cinder Troy, Godfrey, Mia, Jade, Ellison, Geneva) with jobs + puzzle
  pipelines. Each persona carries pronouns + a grounded `chat_role` (what they do/offer in the real systems).
- **Economy:** ONE earned currency = **gold**. Earn-and-keep — no decay, no upkeep, no premium
  currency, no pay-to-win. (Legally safe *only* while gold stays earn-only — never real-money-purchasable.)
- **Multiplayer direction (decided, not yet built):** co-op (Stardew-style, ~4–8p, one shared world) +
  a thin global **parlor** social layer for real-time minigames. NOT an MMO. Build co-op-ready now; no
  netcode yet.

## The headline meta-system: the voyage (pillage)
The endgame loop, reskinned from YPP pillaging. You job onto a crew at the Skydock → board an isometric
**ship deck** → give the captain the word at the **helm** to **set sail**:
- The **deck then sails the whole route on its own** (set-sail-once — each leg's duty report flows into the next).
- **Man the Loft** (fly her / keep aloft) **or the Patchworks** (mend the hull) **any time while she sails**;
  leave a station and you're back on the still-sailing deck (re-man, switch, or just watch).
- At an encounter she triggers a **boarding** (crew-vs-crew Skirmish team fight); you arrive at Driftspar for your cut.
- The ship is **sinkable**: damage → hull holes → the Stardust floods faster in the Loft → sink on a fight leg =
  "Lost in the Stardust."
- **Three real ship classes** (`ShipClasses` registry): Driftpod 750g (hull 4 · 1 berth · 2–3-leg hops · hold
  ×1.0) → Cloud Cutter 3000g (6 · 2 · 2–4 · ×1.3) → Sky Galleon 10000g (9 · 4 · 4–6 · ×1.6). You **christen** her
  at purchase, manage the fleet at the **dock berth** (sail / swap / rename / sell at half price), and she
  *draws* as her class.
- **The boarding is a LIVE BACKGROUND MELEE** (`BoardingMelee` autoload): the fight runs whether or not you're
  watching — mates trade blows, your undefended board buries itself, a side can win/lose on its own. **Step
  away** to the deck (stations lock, "Rejoin the boarding"), let it fight on, **rejoin** where you left it.

## Architecture (the patterns to copy)
- **`PlayerState`** (autoload) — the data spine: gold, backpack/items, per-puzzle mastery (high-water-mark),
  NPC affinity, ships, flags, scene-transition handoff, all voyage state. Persisted via ConfigFile.
- **`HUD` / `UserPanel` / `Overlay`** (autoloads) — the overworld HUD, the right-edge Sunshine-widget tab rail,
  the NPC dialog overlay.
- **`BaseLocation`** — walkable overworld scenes spawn the player + resolve spawn points.
- **`Interactable` → `Puzzle` / `Npc` / `Door` / `Building`** — the prop hierarchy (click-ON-target to interact).
- **Puzzle = a Board + a Scene:** the Board is the logical engine (grid + child piece-nodes + an async cascade
  resolver that *awaits* every animation); the Scene (`PuzzleScene`) hides the HUD, owns Leave + the Tutorial
  feed, and banks rewards via `record_puzzle_result`. Chat-able versus games extend **`VersusPuzzleScene`**
  (situational-awareness + talk-influence base, hidden-info-safe by construction).
- **`BoardingMelee`** (autoload) — the persistent crew-fight sim that survives scene changes.
- **Mobile:** one `TouchEnv.is_touch()` flag gates ALL touch UI (`components/touch_controls/`: `VirtualJoystick`
  + a data-driven `TouchControlBar` fed by each puzzle's `_touch_spec()`); desktop is byte-for-byte unchanged.

## Standing rules (don't violate)
- **Placeholder-first art** — procedural `_draw()` shapes + flat colors. No asset-lifting.
- **Animate everything** — every state change is a shown, awaited motion, never an instant pop-in.
- **Instructions in the Tutorial tab**, never a strip under the board. **No persistent objective banner** (journal only).
- **Click-ON-target, never click-anywhere-while-near. Every window closes on ESC** (reuse `EscToClose`).
- **Inheritance over duplication; scene-per-component.**
- **NPCs are situation-aware + hidden-info-safe.** Public copy never says "AI"; no em-dashes / AI-slop.
- Build proactively, flag only big design forks; commit freely; **never push without an explicit ask.**

## Session changelog (newest first — older per-session detail intentionally condensed)
- **2026-06-13 (pm) — Mobile-feel polish: Tetris freeze fix, joysticks, soft-drop, character-creation names.**
  🐛 **Fixed a full-match Tetris LOCKUP** (Skirmish): the player gravity loop re-entered `_step_down()` after a
  lock set `_piece=-1`, and GDScript's `SHAPES[-1]` silently wraps to the L piece → a phantom re-lock stranded a
  pause flag → piece hung mid-air. Found via a 5-agent hunt + adversarially verified; guarded (mirrors the AI
  loop) with a headless regression test ([[step-loop-sentinel-guard]]). **Touch joysticks replace the d-pad:**
  Mining gets a 4-way thumb stick; Skirmish a stick that shifts AND pull-down soft-drops (the ▼ button removed) —
  plus a touch-only auto-expire of the post-spawn soft-drop lockout so hold-to-drop survives across pieces
  (`PuzzleJoystick` + a `_touch_joystick` seam on `PuzzleScene`; the overworld `VirtualJoystick` refactored to a
  shared `_actions_for`). **New Game now REQUIRES a name** + a dice-roll (`RandomName`, procedural `DieIcon`) for a
  random *unused* one, validated against a single `_taken_names()` source (the cast now; server players fold in for
  online/co-op uniqueness later). **`/skills`** dev cheat (max all mastery to Legend) for voyage playtesting. All
  verified headless + by screenshot; **both itch builds re-exported** to `build/`.
- **2026-06-12→13 — Mobile-web port + a touch-UI marathon + a SILENT NPC-chat outage fixed.** Built the phone/web
  build in phases (`TouchEnv` flag, 8-dir `VirtualJoystick`, data-driven `TouchControlBar` via per-puzzle
  `_touch_spec`, a custom `web/shell.html` loading screen, a keep-warm proxy pinger, DejaVu for web glyphs).
  🚨 **The headline: NPC chat was OFFLINE for EVERY player** — a UTF-8 BOM on `npc_chat.cfg` (PowerShell writes
  one by default) made Godot's `ConfigFile` misread the section, so `endpoint` silently fell back to dead
  `localhost` and all chat went into the void. Hidden for ages because the dev's direct key bypassed the proxy;
  PURGING that key (player-facing key field removed + the settings.cfg path dropped) is what exposed it. Fixed:
  the loader now strips a BOM (see [[bom-breaks-godot-configfile]]). **Touch-UI fixes:** the L/R control-bar split
  (movement bottom-left, rotate/drop bottom-right); a control bar that rendered 0×0 under its CanvasLayer (now
  viewport-fitted); an input crash (a synthesised `InputEventAction` has no `echo` → now emits a real key event);
  the **action-puzzle layout** (Leave→top-left, Chat→top-right, the puzzle's score/status HUD centred at the top
  via a generic `_touch_hud_node` seam — Lumberjacking done, others queued); the tab rail **vertically centred +
  a slide-away tuck handle, now shown on every scene**; mobile HUD alignment + **Save & Quit**. Re-exported to
  `build/`. ⚠️ NEEDS a real-device pass; Skirmish/Mining/Patchworks still need the one-line HUD-node opt-in.
- **2026-06-11→12 — itch.io demo ships + "talk moves the game".** Went PUBLIC with a Windows release + all-
  procedural key art + a devlog; marketing voice locked. New hook: chat a versus opponent and landing words
  (gated by per-NPC `composure`) tilts a decaying `NpcMood` that biases the AI's next moves (bluffier poker,
  an under-defending Gem Drop, a reckless Skirmish). Built on the `VersusPuzzleScene` base (poker/gem-drop/
  skirmish migrated, adversarially verified byte-identical). Plus the **Sweethearts** romance system.
- **2026-06-10 — the ship system + human NPC voices + NPCs-can-hate-you.** `ShipClasses` registry single-
  sources 3 real classes; christen + a `DockBerthModal` fleet hub (sail/swap/rename/sell). Chat voices went
  plain + distinct (banned the pirate dialect); the cast remembers an introduced name. Rapport now spans
  -100..100 — NPCs can sour (red in Hearts, withhold Favour). Adversarially reviewed, 11 bugs fixed.
- **2026-06-09 — NPC-chat depth: live situational awareness + chat-driven duels.** Standing principle: a scene
  implements `npc_chat_context` → folded into the prompt (built for poker: the cast read the live hand, hidden-
  info-safe). Chat can turn into a Skirmish duel filed to the **Ayo!** inbox (reliable via a deterministic
  classifier). Per-NPC battle memory (W/L). World grounding (`ISLAND_GAZETTEER` + `chat_role`) kills contradictions.
- **2026-06-08→09 — ship-owning + crew.** Recruit a confidant (rapport ≥ 80) into a ranked `crew`; post them to
  the voyage's three duty-stations (Sailing→Loft, Repair→Patchworks, Combat→boarding) for real skill-based
  effects; **captain your OWN moored ship** (persisted hull carried in → damaged → written back). Click-to-trade
  barter; ambient `RoomChat`; a chat scope selector (All / →Name).
- **2026-06-05→08 — the AI NPC chat hook + Sunshine widget + HUD overhaul + live-melee boarding.** Free chat
  with the cast, in-character LLM replies via a key-safe proxy (`NpcBrain`). The Sunshine Widget consolidated
  user panel. A reviewed HUD overhaul (reusable `MeterBar`, a `PauseMenu`, the ESC-closes-every-window rule).
  The boarding became a persistent background melee. An `Audio` autoload with procedural placeholder SFX.
- **~2026-05-24 → 06-05 — the MVP build-out.** The walkable iso overworld + the 9-NPC cast, all 7 puzzles
  (each a Board+Scene engine with AI + animation + mastery), the voyage meta-system, and economy / mastery /
  trophies / save-load / onboarding. **Locked 2026-06-05:** 7 puzzles is the final count; polish, not content.

## What's next
- **📱 THE FRIEND / DEVICE PLAYTEST is the immediate signal** (the whole point now): the touch controls in
  EVERY puzzle, the overworld mobile HUD alignment, Save & Quit, chat on a phone, the proxy staying warm.
- **💬 Talk-influence feel:** does a taunt VISIBLY move an NPC? Tune `composure` if bait-ability reads wrong.
  Deferred polish: a mood **pip** so you SEE you got in their head; an optional Needle/Read/Steady button row.
- **🚢 Ship-owning + crew end-to-end:** recruit → Crew Duty assign → captain your own ship → feel the station
  effects + hull carry/repair. Tune the duty-station balance (Repair's seal is the strongest knob).
- **Keep the chat proxy deployed/warm** before friends play (NPC chat is dead otherwise; see proxy/README.md).
- **Deferred "later forks"** (need Troy's green light): `Theme.tres` centralization (post-demo, regression
  risk), `ItemDef.tres` (defer), cutout-limb character art (needs art direction), audio call-site wiring + feel.
- **Post-demo:** co-op netcode, parlor tournaments, filling Driftspar, a real soundtrack.

---
_This report is a living snapshot — regenerate it as the project moves. Deeper design history + locked
decisions live in the auto-memory (`…/memory/MEMORY.md`); the code map lives in `CLAUDE.md`._

# TROY's TODO (next session) #
--- 🏠 QUEUED FOR "WHEN HOME" (Troy 2026-06-13 pm — deferred, design discussed, NOT yet built) ---
= 🔍 PINCH-TO-ZOOM the camera scenes (overworld + poker + gem-drop tables read SMALL on phones): standard
  two-finger pinch. Cameras exist in overworld (`base_location`)/`ship_deck`/`poker`; **gem_drop has NO camera**
  (fixed Node2D layout) → needs one added. Plan: a reusable zoom-only `PinchZoom` on each scene's `Camera2D`,
  clamped; pan deferred. (Investigated this session; not started.)
= 🔤 BIGGER chat FONTS + a bigger chat INPUT FIELD on touch (input is 15px now — `chat_box.gd`); bigger NPC
  NAMETAGS (`npc.gd _setup_name_tag`). Gate on `TouchEnv.is_touch()` so desktop is untouched.
= ⚡ GENERAL PERFORMANCE PASS — gem-drop + mining felt LAGGY/JERKY on mobile (maybe others). Profile + sweep
  (per-frame allocations, `_draw`/`queue_redraw` churn, the web no-thread budget).
--- MOBILE / WEB BUILD (new 06-12 — playtest on a phone!) ---
= play the web build on a phone: do the touch controls work in EVERY puzzle? (skirmish move-L / rotate-drop-R,
  mining d-pad, lumberjacking, patchworks, the gem-drop/poker/loft taps)
= overworld mobile HUD: the ≡ (top-left), joystick + Chat should sit aligned; ≡ → pause → Save & Quit saves + resumes
= chat on mobile: tap Chat, tap outside to dismiss; confirm the proxy is awake (no false "offline" before replies)
--- TALK-MOVES-THE-GAME (06-11→12) ---
= TALK-INFLUENCE feel: taunt Kerr at poker, "send the gems my way" at Gem Drop — does it VISIBLY move them?
= tune `composure` if bait-ability reads wrong (Kerr 0.3 / Mia 0.35 low · Jericho 0.88 / Ellison 0.85 high · rest 0.6)
= check the audio: the Options volume sliders + that the title music sits comfortably (now -16 dB)
--- THE SHIP SYSTEM (06-10) ---
= buy a ship → christen her → click the moored ship → the BERTH hub (sail/rename/sell); sail a Cutter / Galleon run
= try genuinely insulting someone: rapport should sour → red row in Hearts → favour withheld (OFFENSE_HIT = 4)
--- CARRY-OVER ---
= tune duel_appetite (challenge frequency) + persona chat_* fields by feel
= a self-playthrough + a written playtest checklist/script before a friend plays
--- IDEAS PARKED ---
= per-class WALKABLE deck layouts (the deck props are hand-placed — needs 3 hand-tuned scenes)
= the cast permanently remembers your introduced name (PlayerState + prompt, pairs w/ romance groundwork)
