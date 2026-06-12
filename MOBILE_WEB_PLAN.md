# Mobile-Web Foundations — phased checklist

Goal: make Shivaliva Shanty fully **touch-playable on a phone** (via the HTML5 web build) and fix the
web-export bugs. Built from a 10-agent survey of every puzzle's input model + a web-export audit
(2026-06-12). Standing rules honored: **inheritance over duplication** (one shared touch component, not
per-puzzle reinvention), animate-everything, scene-per-component, and **nothing ships without Troy's
greenlight on the piece**.

## The shared foundation (build ONCE, every puzzle inherits)

A new `components/touch_controls/` folder with three art-swappable pieces + a device flag:

- **`TouchEnv`** — the single source of truth: `TouchEnv.is_touch()` = `DisplayServer.is_touchscreen_available()
  or OS.has_feature("web")`, with a `user://settings.cfg` override. Every mobile branch reads ONLY this flag,
  so **desktop is byte-for-byte unaffected**.
- **`VirtualJoystick`** — a thumb-zone stick that calls the EXACT `move_left/right/up/down` actions
  `player.gd` already polls → zero player.gd logic change.
- **`TouchControlBar` / `ActionButtons`** — a data-driven bar of big (>=64px) buttons. You hand it a spec
  `[{label, action_or_callable, hold}]`. `hold` buttons synthesize `Input.action_press/release` so the
  existing DAS (auto-repeat) in skirmish/mining/lumberjacking works unchanged.
- **The seam**: `PuzzleScene` gets a virtual `_touch_spec() -> Array` (default empty). When `TouchEnv.is_touch()`
  it builds the bar from the subclass's spec. Tap-only puzzles (Loft, Gem Drop, Poker) inherit nothing —
  Godot already turns every touch into a synthetic mouse-click, so they Just Work.

---

## Phase 0 — Make the web build solid (export-bug fixes)  ·  size M
Fix the runtime-breaking bugs so the current web build runs every puzzle. (Independent of touch; helps the
build you can share today.)

- [ ] **CRITICAL** — Gate Gem Drop's background thread on platform. `puzzles/gem_drop/board.gd`
      `_begin_ai_search()`: on web run the AI search synchronously + `call_deferred` the result; keep the
      `Thread` on desktop. (Without this the web build FREEZES on a gem-drop AI turn.)
- [ ] Grep `Thread.new` to confirm Gem Drop is the only threaded puzzle (skirmish AI is already non-threaded).
- [ ] Web-safe quit: `main.gd` + `pause_menu` — on web, change_scene to title instead of `get_tree().quit()`
      (quitting just kills the tab).
- [ ] Web save durability: `player_state.gd` — `await` a frame after `config.save()` to flush IndexedDB +
      a light ~45s periodic auto-save + verify the close-request handler runs.
- [ ] Re-gate DevCheats for web: `OS.is_debug_build()` is false on web → add a `user://settings.cfg dev_mode`
      OR so devs keep cheats, players stay blocked.
- [ ] Decide the `thread_support` fork (below); the gem-drop gate is the real fix either way.
- [ ] Re-export web + smoke-test: load, play a gem-drop turn (AI moves, no freeze), quit, refresh, save persists.

## Phase 1 — Reusable touch-input foundation (build ONCE)  ·  size L
- [ ] `components/touch_controls/touch_env.gd` — the flag (+ settings override).
- [ ] `virtual_joystick.tscn/.gd` — drag → held `move_*` actions; spawn only on touch.
- [ ] `action_buttons.gd` + `touch_control_bar.gd` — data-driven, >=64px, hold + tap buttons, on a CanvasLayer.
- [ ] `PuzzleScene._touch_spec()` seam (default empty); `VersusPuzzleScene` inherits it free.
- [ ] Options-panel toggle to force touch on (desktop dev testing without a phone).
- [ ] Memory note `touch_input_foundation.md` so future puzzles follow the seam.

## Phase 2 — Wire the action puzzles + verify the tap puzzles  ·  size L
- [ ] Skirmish (`skirmish/duel/boarding`): spec ◄ ► (hold) · ↻ (tap) · ▼ Drop (hold); boarding target-cycle buttons.
- [ ] Patchworks: ↺ ↻ Flip Toss buttons; tap = pick/place, drag = move ghost; drop right-click/wheel as PRIMARY.
- [ ] Mining: D-pad (hold) + CW/CCW (tap); tap to position the 2×2 cursor.
- [ ] Lumberjacking: ◄ ► (hold) · ↺ ↻ (tap) · Drop (hold).
- [ ] Verify Loft / Gem Drop / Poker / overworld work via synthetic touch; add touch-up hover-clear where sticky.
- [ ] Per-puzzle z-order: bar must not cover the board or the Leave button.
- [ ] Playtest each with TouchEnv forced on (desktop, mouse-as-finger).

## Phase 3 — Responsive layout: orientation + touch-sized HUD / chat / menus  ·  size L
- [ ] Spawn the joystick in the overworld; add on-screen Backpack/Objectives buttons (E/I/J/R/ESC are keyboard-only).
- [ ] Chat: a visible Chat button (Enter-to-open is keyboard-only); shift the bar up by the virtual-keyboard height.
- [ ] Replace hover-tooltips with tap-to-show (touch has no hover).
- [ ] ESC-to-close: every modal needs a visible Close (the `ui_cancel` key never fires on touch).
- [ ] Touch-size the NPC radial menu + UserPanel tab rail (gated behind TouchEnv).
- [ ] Orientation: implement the portrait-vs-landscape decision (the biggest scope driver — see forks).

## Phase 4 — Device playtest + polish  ·  size M
- [ ] Test on real iOS Safari + Chrome Android: overworld, every puzzle, chat, every menu/modal.
- [ ] Tune feel: DAS rates, button sizes/positions, joystick deadzone, tap-vs-drag thresholds.
- [ ] Verify save persists across lock/tab-switch on-device.
- [ ] Confirm ZERO desktop regression (TouchEnv off → identical to today).
- [ ] First-launch touch tutorial via the existing UserPanel Tutorial tab.

---

## Forks for Troy to decide
1. **Orientation**: force-landscape (far less work, boards fit as-is) vs portrait (natural hold, big relayout). *Biggest scope driver.*
2. **`thread_support`**: keep (needs host isolation headers, may fail silently) vs flip to false (max compatibility, one-turn hitch). *Recommend: flip to false.*
3. **Action-puzzle controls**: on-screen buttons (MVP, ships fast) vs gestures (nicer, more work). *Recommend: buttons first; foundation supports gestures later.*
4. **Gate on TouchEnv flag** so desktop is unaffected. *Recommend: yes.*
5. **Scope vs the MVP-demo lock**: Troy greenlit "build the foundations" — treated as a go; phases gated on his per-phase sign-off.
