# Shivaliva Shanty — architecture map

A single-player-first, retro-charming **puzzle-skill adventure** among floating sky-islands — a
spiritual successor to Puzzle Pirates, its own thing. Solo dev (Troy). **Godot 4.6**, GDScript, GL
Compatibility, 1280×720. No build step — run `main.tscn`, or any `puzzles/*/<name>.tscn` standalone.

> Deep design history, locked decisions, and "why" live in the **auto-memory** at
> `…/memory/MEMORY.md` (loaded each session). This file is the **code map** — where things live and
> the patterns to copy. When they disagree, the code wins; update both.

---

## 🔑 Standing rules (do not break)
- **Build proactively; flag only the big forks** (Troy 2026-06-03, replacing the old "ask before every
  feature" rule). Just build routine work + already-agreed slices without checking in. STILL pause to
  confirm only: (a) genuinely-forking DESIGN decisions where the wrong pick wastes real work (e.g. which
  voyage shape, lodged-vs-falling), and (b) irreversible / outward-facing actions. The point is unchanged
  — "I don't wanna waste time reverting garbage features" — just trust the routine. Repo is now git-backed
  (baseline commit), so snapshot at sensible checkpoints; everything is revertible.
- **Placeholder-first art**: procedural `_draw()` shapes + flat colors. Do NOT lift/import art assets.
- **Animate everything**: every state change is SHOWN as motion (an awaited tween), never an instant
  pop-in. Garbage/stones/pieces visibly fall. (Troy is a visual thinker; teleports read as broken.)
- **Instructions behind a "?"**: puzzle how-to-play text ALWAYS goes behind a hoverable "?" button
  (call `PuzzleScene.set_help_text(text)`), NEVER a long strip under the board — strips run off-screen.
- **Click-ON-target, never click-anywhere-while-near**: a click-to-interact fires ONLY when the click
  lands ON the object's body AND the player is in range. Proximity shows the prompt; the click landing
  on the body does the interaction (two gates). This is GENERAL — holds for EVERY input handler, not
  just the overworld. Reuse the ONE click-box in `interactable.gd` (`Interactable.CLICK_HALF_WIDTH` /
  `CLICK_ABOVE` / `CLICK_BELOW`). Audit any new `_unhandled_input`/`_input`/click handler against this.
- **ESC closes every window**: ANY exitable window/modal MUST close on **ESC**. Don't hand-roll a handler
  per panel — drop the ONE reusable `components/esc_to_close/` node in: `add_child(EscToClose.new(_close))`
  (it processes-always, consumes the key, and no-ops while its modal is hidden). Audit every new
  panel/card/menu/shop/dialog for it. (The HUD ESC chain + pause_menu own their own ESC.)
- **Inheritance over duplication**: every gameplay category has a base class; concrete variants
  override only what differs. Never re-implement a foundation.
- **Scene-per-component**: each visual game piece is its own `.tscn` so art can be swapped later
  without touching gameplay logic.
- **NPCs know their situation** (Troy 2026-06-09 foundational): an NPC you can chat with is ALWAYS grounded in
  the LIVE scene/activity — what they're doing, where, and its real-time state — and speaks to it. Mechanism: a
  scene implements `npc_chat_context(npc_name) -> String`; `NpcBrain.compose_system` folds it into the prompt
  (poker does this). MUST be hidden-info-safe — only ever expose the asker's OWN secret state (their hole cards),
  never a rival's. Make every chat-reachable scene situation-aware. AND they must never get **delusional**: a
  global `NpcBrain.GROUND_TRUTH_RULES` (in every prompt) forbids denying a settled result or inventing
  rules/scores; each versus game also feeds its rules via `VersusPuzzleScene._rules_brief()` and a "match/duel is
  OVER, X won" frame once it ends (gem_drop/skirmish_duel). See `…/memory/npc_situational_awareness.md`.
- **The NPC Awareness Stack** (the ONE place all NPC knowledge is assembled — `NpcBrain.compose_system`): every
  chat prompt = identity/voice (`.tres`) + role/locale + world grounding (`ISLAND_GAZETTEER`, pronoun roster,
  live time) + **private memory** (this NPC's own persisted chat history, per-NPC) + **shared social memory**
  (NEW) + **live situational awareness** (`npc_chat_context`) + relationship (affinity/romance/battle). All of it
  is AUTOMATIC for any NPC — adding one is still just a `.tres`. The **shared social memory** is the cross-NPC,
  cross-scene, reload-surviving layer: `PlayerState.recent_happenings` — a HARD-CAPPED (`HAPPENINGS_CAP`) global
  log of NOTABLE **public** events, written ONLY via the one choke-point **`PlayerState.note_happening(text, place)`**
  (so a new activity/island just adds one call) and folded in by `NpcBrain._happenings_block` as island-scoped
  **hearsay** ("around here lately" vs "word from afar"). Wired at gym/ordeal wins, ship bought, job hired, a duel
  lost, and a budding romance (the cast gossips). **Hidden-info-safe by construction**: record ONLY observable
  SOCIAL facts — NEVER a raw chat line, a held `chat_secret`, or hidden GAME state (a rival's hole cards / a
  per-seat `_own_secret_view`). A *noticed* romance is fair game (the flirty words stay private; only the fact
  you're close goes around). Because it's capped, the save + the per-prompt token cost stay BOUNDED no matter how
  long you play. Multi-island scope = the
  `NpcPersonality.island` field + `NpcBrain.SCENE_ISLAND` map; nothing else.
- For **risky logic / new systems**, prefer design → build → adversarial review before handoff. Be
  deliberate about multi-agent *workflows* — they're powerful but slow/expensive; reserve them for
  genuinely risky or open-ended work, just build for routine edits.

## 🎨 Coding style (from Troy's GDQuest-derived convention)
`snake_case` files · `PascalCase` `class_name` · `_underscore` privates · signal handlers named
`_on_Source_event` (or `on_Source_event`) · `%UniqueName` for scene-unique nodes · `@export_category`
to group exports · typed vars/returns. Keep files focused (**aim ≤ ~400 lines**; split when bigger).
Integer division needs `@warning_ignore("integer_division")`. Avoid shadowing base-class props
(`scale`, `position`, `name`, …) with locals.

---

## 📁 Directory map
```
autoloads/        PlayerState — the data spine (singleton)
interface/        HUD, Overlay (singletons) + all UI panels (inventory, profile, lobby, …)
components/       reusable bases + parts: interactable, puzzle, npc, building, bed,
                  modal (the pop-up base — EVERY centered panel/window extends it), puzzle_scene,
                  parlor_table, trophies, npc/ (personality + registry + crew_skills),
                  ships/ (ShipClasses — THE registry of the 3 ship classes: stats/prices/blurbs;
                  the shop, PlayerState, dock, deck + chat ALL read it — never hardcode a ship stat)
levels/           walkable overworld scenes (extend BaseLocation): shore, tavern, forest, mine,
                  *_interior, frontier_isle(Driftspar), door/
buildings/        building props + their interiors' work-sites (forge, workshop, skydock, …)
player/           the Player character (top-down move + InteractionZone)
puzzles/          one folder per mini-game: skirmish, mining, gem_drop, poker, lumberjacking, loft
tournaments/      tournament.gd  (LIVE voyage = levels/ship_deck/ship_deck.gd; the old voyages/ dir is gone)
main.gd/.tscn     entry point / title → resume or new session
```

## 🧠 Autoloads (globals; see `project.godot [autoload]`)
- **`PlayerState`** (`autoloads/player_state.gd`) — the **data spine**. Holds gold (`add_coins`,
  `total_coins`, `lifetime_coins_earned`), the backpack/items (`ITEM_DEFS`, `add_ore`, etc.),
  per-puzzle mastery (`puzzle_mastery` high-water-mark via **`record_puzzle_result(id, score)`** +
  the **`MASTERY_PUZZLES`** registry + `MASTERY_TIERS`), `npc_affinity`, `owned_ships`, flags
  (`frontier_unlocked`, `has_seen_intro`), and the **scene-transition handoff**: `last_scene` /
  `last_position`, `request_spawn_at_anchor(name)`/`consume_anchor()`, and the one-shot
  `puzzle_return_scene`. Persisted via `_save()`/`_load()` (ConfigFile). Mutate
  mastery ONLY via `record_puzzle_result`.
- **`HUD`** (`interface/hud.tscn`) — overworld HUD: just the gold purse now (the right-side quick-menu + the
  "!" journal popup were retired into the **Sunshine Widget** user panel — see `InventoryPanel`). Hidden by
  the title + every `PuzzleScene`. **E**/**I** open the panel (Backpack); **R** → Hearts; **J** → Objectives;
  **ESC** runs a priority chain (`_on_escape`): close the open panel → close the chat Log → else open the
  **`PauseMenu`** (`interface/pause_menu/`, a `PROCESS_MODE_ALWAYS` modal: Resume / Options / Quit to Title).
- **`UserPanel`** (`interface/user_panel/`, autoload) — the **Sunshine Widget**: a foldable right-edge tab
  rail wrapping `InventoryPanel` (Ayo! · Objectives · Tutorials · Backpack · Hearts · Profile + a Jobs
  launcher). Shown in the overworld AND inside puzzles; Tutorials shows only the current scene's how-to;
  trophies are earned → claimed in **Ayo!** → shown on the Profile shelf.
- **`Overlay`** (`interface/overlay.tscn`) — the NPC dialog overlay.

---

## 🧩 The three core patterns (copy these)

### 1. Overworld location → `extends BaseLocation` (`levels/base_location.gd`)
A walkable Node2D. On `_ready` it spawns the `Player`, resolves the spawn point
(`pending_spawn_anchor` → that node's `global_position + spawn_offset`, else resumed position, else
`pirate_spawn_position`), parents the player under a `YSortNode2D` if present (iso y-sort), and
records `last_scene`. Props (doors, puzzles, NPCs, buildings) are children. **Add one:** new scene
extending BaseLocation + a `Door` back + props.

### 2. Interactable prop → `extends Interactable` (`components/interactable/interactable.gd`)
`@tool` `Area2D` on physics layer **Interactable**. The Player's InteractionZone calls
`set_tooltip_visible()`; a **left-click that lands ON the body** (`contains_click`) while in range calls
`interact()` (emits `interacted`) — the Player's `_unhandled_input` picks the nearest in-range
interactable **the click actually hit** (clicking bare ground beside it does nothing — see the
click-ON-target standing rule; the ship deck obeys the same box). The world is **click-based**; **E** now
opens the backpack. Tooltips read `[Click]`. Has `marker_label`, `spawn_offset`. Subclasses:
- **`Puzzle`** (`components/puzzle/puzzle.gd`) — adds `@export_file puzzle_scene` + `play_cost`;
  `interact()` charges gold then `request_spawn_at_anchor(name)` + `change_scene_to_file(puzzle_scene)`
  so the player returns next to the prop. **This is how a puzzle is launched from the world.**
- **`Npc`** (`components/npc/npc.gd`) — permanent name tag; click → a radial **`NpcMenu`**
  (`interface/npc_menu.gd`, YPP-style) of **Talk / Spar / Favour / Hearts** (NOT a dialogue box). Talk floats
  a **`SpeechBubble`** line (`components/speech_bubble.gd`); Spar launches a 1v1 Skirmish duel vs that NPC;
  Favour is tucked in (the old `Overlay` dialog + favour-demand are gone); grants affinity. Data-driven
  `NPC_FAVORS` (one-entry edit to give an NPC a favour). Personality/AI tuning lives in `.tres`
  `NpcPersonality` resources (`components/npc/profiles/*.tres`, indexed by `NpcRegistry`).
- **`Door`**, **`Building`** (solid; add a `StaticBody2D` child for collision).

### 3. Puzzle → a **Board** + a **Scene** (the most important pattern)
Every mini-game is two halves under `puzzles/<name>/`:

**A. The Board** — `class_name <Name>Board extends Node2D` (e.g. `LoftBoard`, `MiningBoard`,
`SkirmishBoard`). The engine:
- `const COLS/ROWS/CELL` + a `grid` array = the **logical source of truth**; pieces are **child
  nodes** (one scene per piece, e.g. `stone.tscn`) positioned/tweened to grid cells.
- **typed signals** out (e.g. `lift_changed`, `moves_changed`, `session_ended`).
- `_draw()` paints only the board chrome (backing, grid lines, frame); pieces draw themselves.
- input via `_unhandled_input` (+ `get_local_mouse_position()` → cell); lock input while resolving.
- the **async cascade resolver**: a logical change is always followed by an `await`-ed tween, so
  motion is shown step-by-step — `find matches → await animate_clear → settle gravity → await
  animate_to_grid → refill → await animate_to_grid`, looping until stable (`_resolving` guards input,
  `MAX_CASCADE_DEPTH` backstops). Heavy per-turn AI runs on a **background thread** (see the Gem Drop
  / Skirmish pattern), never on the main thread.

**B. The Scene** — `extends PuzzleScene` (`components/puzzle_scene/puzzle_scene.gd`). Inherits
HUD-hide-on-enter/restore-on-exit, the persistent **Leave** button, and click-to-dismiss. It: holds
the `Board` as a child node (see `puzzles/skirmish/skirmish.tscn` for the minimal `.tscn` shape),
binds the board's signals to a **code-built** HUD (no hand-authored UI scenes — build panels in
`_build_ui()`), and on round-end calls **`PlayerState.record_puzzle_result("<id>", score)`** →
shows a results panel + a `MasteryToast` on rank-up + `_set_awaiting_dismiss(true)`. Bank rewards
idempotently (also on mid-session Leave — override `_return_to_launching_scene`).

Then register the id in **`PlayerState.MASTERY_PUZZLES`** and launch it from a `Puzzle` prop.

**Reference puzzles:** `loft` (match-3, the simplest current Board+Scene — good template) ·
`mining` (forage grid, the canonical async resolver) · `skirmish` (versus Tetris + threaded AI +
duel scene) · `gem_drop` · `poker` (cards + `test_*.gd` logic tests) · `lumberjacking`.

---

## 🔁 Cross-cutting conventions
- **Async-resolve + await-after-free**: when a piece is freed mid-cascade, capture any data you need
  (hue, score, row) as **primitives BEFORE** `queue_free()` + `await` — a freed node read after an
  await crashes. Guard leave-during-await with `is_instance_valid(self)` / `is_inside_tree()`.
- **Sizing**: overworld 1 tile = 32px ≈ 1m, player ~1 tile. Puzzle boards set their own `CELL`.
- **Economy**: ONE earned currency = **gold** (no premium currency, no decay/upkeep). Earn-and-keep.

## ➕ Recipes
- **New puzzle:** copy `puzzles/loft/` (stone + board + scene + 2 `.tscn`s) as the skeleton → rename
  `class_name`s → implement the mechanic in the Board → add `"<id>": {...}` to `MASTERY_PUZZLES` →
  drop a `Puzzle` prop (`puzzle_scene = res://puzzles/<id>/<id>.tscn`) into a location.
- **New VERSUS puzzle (a chat-able AI opponent):** do the **New puzzle** steps but extend
  **`VersusPuzzleScene`** (`components/versus_puzzle_scene/`) instead of `PuzzleScene`. You inherit for free: a
  default `npc_chat_context(asker)` emitting the standard situational-awareness shape (`_public_frame` →
  `_lead_phrase` → `_own_secret_view` → `_pressure_phrase` → `_active_mood_note`), **hidden-info-safe by
  construction** (only `_own_secret_view` ever sees a secret, keyed solely on the asker — never a rival's),
  plus the talk-influence seam (`mood_bias`/`tick_opponent_mood`/`_apply_opponent_mood`, no-ops until NpcMood).
  Fill ONLY the hooks you need (all default to `""`/`true`/`0.0`): `_versus_ready`, `_public_frame`
  (MUTUALLY-VISIBLE state only), `_lead_phrase` + `_pressure_phrase` (PLAIN-WORDS, pre-computed — the chat
  model can't compare numbers), `_own_secret_view` (the asker's OWN hidden view only; **`""` for OPEN
  boards**). NEVER re-implement `npc_chat_context` — that defeats the base. Ref: gem_drop (open, simplest) ·
  skirmish_duel (1v1) · poker (hidden cards + multi-seat).
- **New NPC:** instance the `Npc` scene, set `@export`s + assign a `NpcPersonality` `.tres` (clone an existing
  one; set name + the `chat_*` fields + `island`); optionally add a one-line entry to `Npc.NPC_FAVORS`. They
  inherit the ENTIRE NPC Awareness Stack (world grounding + private + shared memory + relationships) for free — no
  awareness code per NPC.
- **New ISLAND's NPCs:** (1) clone a profile `.tres`, set its `island` field (e.g. `"driftspar"`); (2) register
  it in `NpcRegistry`; (3) name the island's scene FILES with the island keyword (e.g. `driftspar_tavern.tscn`) so
  `NpcBrain.SCENE_ISLAND` maps them (or add each stem there) + (optionally) extend the `ISLAND_GAZETTEER`. Shared-
  memory awareness is then automatic + correctly scoped (own-island events read as "around here," other islands'
  as "word from afar"). To make a new event cast-aware, add ONE `PlayerState.note_happening("…", place)` call at
  its outcome site (public facts only — see the standing rule).
- **New prop/door/building:** a scene with `Interactable`/`Puzzle`/`Door`/`Building` attached + its
  `@export`s; add a `StaticBody2D` child if it should be solid.

## ▶️ Run / test
Open in Godot 4.6 → run `main.tscn` (title → new/resume). Run any `puzzles/*/<name>.tscn` directly
to test a puzzle standalone. Logic tests where they exist: `puzzles/poker/test_*.gd`.