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
  never a rival's. Make every chat-reachable scene situation-aware. See `…/memory/npc_situational_awareness.md`.
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
                  state_machine, parlor_table, trophies, npc/ (personality + registry + crew_skills)
levels/           walkable overworld scenes (extend BaseLocation): shore, tavern, forest, mine,
                  *_interior, frontier_isle(Driftspar), door/
buildings/        building props + their interiors' work-sites (forge, workshop, skydock, …)
player/           the Player character (top-down move + InteractionZone)
puzzles/          one folder per mini-game: skirmish, mining, gem_drop, poker, lumberjacking, loft
voyages/          voyage.gd — ⚠️ DEAD/superseded; LIVE voyage = levels/ship_deck/ship_deck.gd
tournaments/      tournament.gd
main.gd/.tscn     entry point / title → resume or new session
```

## 🧠 Autoloads (globals; see `project.godot [autoload]`)
- **`PlayerState`** (`autoloads/player_state.gd`) — the **data spine**. Holds gold (`add_coins`,
  `total_coins`, `lifetime_coins_earned`), the backpack/items (`ITEM_DEFS`, `add_ore`, etc.),
  per-puzzle mastery (`puzzle_mastery` high-water-mark via **`record_puzzle_result(id, score)`** +
  the **`MASTERY_PUZZLES`** registry + `MASTERY_TIERS`), `npc_affinity`, `owned_ships`, flags
  (`frontier_unlocked`, `has_seen_intro`), and the **scene-transition handoff**: `last_scene` /
  `last_position`, `request_spawn_at_anchor(name)`/`consume_anchor()`, the one-shot
  `puzzle_return_scene`, and `voyage_phase`. Persisted via `_save()`/`_load()` (ConfigFile). Mutate
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
- **State machines** (`components/state_machine/`, `FsmState` + `StateMachine`): apply SELECTIVELY
  (the voyage is the intended user). Don't retrofit onto simple scripts — keep it simple.
- **Sizing**: overworld 1 tile = 32px ≈ 1m, player ~1 tile. Puzzle boards set their own `CELL`.
- **Economy**: ONE earned currency = **gold** (no premium currency, no decay/upkeep). Earn-and-keep.

## ➕ Recipes
- **New puzzle:** copy `puzzles/loft/` (stone + board + scene + 2 `.tscn`s) as the skeleton → rename
  `class_name`s → implement the mechanic in the Board → add `"<id>": {...}` to `MASTERY_PUZZLES` →
  drop a `Puzzle` prop (`puzzle_scene = res://puzzles/<id>/<id>.tscn`) into a location.
- **New NPC:** instance the `Npc` scene, set `@export`s + assign a `NpcPersonality` `.tres`;
  optionally add a one-line entry to `Npc.NPC_FAVORS`.
- **New prop/door/building:** a scene with `Interactable`/`Puzzle`/`Door`/`Building` attached + its
  `@export`s; add a `StaticBody2D` child if it should be solid.

## ▶️ Run / test
Open in Godot 4.6 → run `main.tscn` (title → new/resume). Run any `puzzles/*/<name>.tscn` directly
to test a puzzle standalone. Logic tests where they exist: `puzzles/poker/test_*.gd`.