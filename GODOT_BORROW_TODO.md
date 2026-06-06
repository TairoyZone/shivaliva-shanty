# Godot-4-features — Borrow Backlog

_From mining `godot-4-new-features-main` (2026-06-06). Work through one at a time; check the box when done._
_Effort: **S** small · **M** medium · **L** large. ⚠️ = expands past the MVP-demo lock (a conscious call)._

**Suggested order (cheap demo-juice first):**
1 Audio autoload → 2 Juice tween helper → 3 Sky shader → 4 Typewriter dialogue → 5 Clear/KO juice → 6 Procedural lights → then the rest.

---

## 🔊 Audio — ✅ DONE 2026-06-06 (Audio autoload + ~13 call sites + a procedural music bed)
- [x] **Audio autoload** — `Audio.play_sfx(name)` / `play_music()`, polyphonic SFX bank, `PROCESS_MODE_ALWAYS`. *(autoloads/audio.gd)*
- [x] **Polyphony** — an `AudioStreamPolyphonic` (12 voices) so cascades layer instead of cutting.
- [x] **`random_pitch`** — a small per-play pitch jitter kills repetition fatigue.
- [x] **Looping music** — a seamless procedural ambient pad bed (loop forced on the stream). *(tools/music_gen.gd)*
- [x] **9 procedural placeholder SFX + 13 call sites** — coin · clears→pop/clack · Lumberjacking shatter/fuse · toss · rank-up chime · duel-loss buzz · Leave click. *(tools/sfx_gen.gd)*
- [ ] **`AudioStreamPlayer2D`** — diegetic world SFX (forge clang near Cinder Troy) — *deferred*. **S**
- [ ] **Broader UI clicks** — centralize when we build the SkyButton (UI section). **S**

## ✨ Visual juice
- [x] **`Juice` tween helper** — ✅ DONE 2026-06-06. `components/juice.gd` (`class_name Juice`): `pop_in` (elastic) · `collect_fly` (parallel scale/spin/drift/free) · `bump` · `pulse` · `fade_in` · `fade_out_free`; each returns the Tween to await/chain. First adoption = the HUD bag-bump. The toasts kept their bespoke slide+hold+fade sequences; broader adoption is incremental + new code uses it from the start. *(tweens/gem.gd)*
- [x] **Procedural sky shader** — ✅ DONE 2026-06-06. `components/stardust_sky.gdshader` (twilight gradient + two layers of twinkling jewel-tinted stars) + `components/sky_backdrop.gd` (`class_name SkyBackdrop`, drop-in on a -10 CanvasLayer, flat fallback colour). Live on the **ship deck** (replaced the flat SKY fill); the title keeps its `MenuBackdrop`. Overworld opt-in later. *(2d_sky.gdshader)*
- [x] **Screen-flash ColorRect** — ✅ DONE 2026-06-06. `components/screen_flash.gd` (`ScreenFlash.make(color, peak)`) — a self-freeing full-screen alpha-punch on a high CanvasLayer. Wired: Loft big combo (lift ≥ 7, combo-tinted) + Skirmish duel KO (red loss / gold win). *(rainy_night.gd)*
- [x] **ClearBurst particles** — ✅ DONE 2026-06-06 (reference). `components/clear_burst.gd` (`class_name ClearBurst extends CPUParticles2D` — GL-Compatibility-safe, NOT GPUParticles2D): a self-freeing one-shot shard puff, `ClearBurst.make(tint, amount)`. REFERENCE wiring = the Loft board (each cleared stone bursts in its gem hue, pos captured before the free). ⏳ Roll out to Mining/Gem Drop/Lumberjacking/Patchworks/Skirmish (system-wide phase). *(space_scene.tscn)*
- [x] **Procedural glows** — ✅ DONE 2026-06-06. `components/glow.gd` (`Glow.make(color, radius)`) — an additive GradientTexture2D sprite (NOT PointLight2D, for GL-Compatibility reliability), self-pulsing. Live: a warm furnace glow on the forge; drop-in for lanterns/halos. *(2d_dynamic_lights/gem.tscn)*
- [x] **`clip_children` masking** — ✅ DONE 2026-06-06. `components/circle_clip.gd` (`CircleClip.wrap(content, d)`) — round portraits via a circle mask; applied to the Profile avatar bust. Gauge spark-clipping deferred (nothing spills yet). *(2d_clipping)*
- [x] **Per-location mood lighting** — ✅ DONE 2026-06-06. `components/mood_tint.gd` (`MoodTint`) — a colour wash on CanvasLayer 2 (tints the world, not the UI); `BaseLocation` applies it via an `@export` or a SCENE_MOODS keyword default (cool mine, warm tavern, …). **M**
- [x] **Scrolling-noise fog/clouds** — ✅ DONE 2026-06-06. `components/stardust_fog.gdshader` (procedural fbm mist) + `components/drift_fog.gd` (`DriftFog`, CanvasLayer -5). Live: drifting cloud wisps on the ship deck. *(top_clouds.gdshader)*
- [x] **Idle/breathing tween loops** — ✅ DONE 2026-06-06. `Juice.bob(node, height, dur)` — a looping vertical bob; wired into the `Npc` base `_ready` (editor-guarded, randomized dur so the cast desyncs), so every NPC breathes. *(ship-bob deferred — the player stands on the deck.)* **S**

## 💬 UI & dialogue
- [x] **Typewriter dialogue reveal** — ✅ DONE 2026-06-06. `Overlay` types each dialog line / lore body out char-by-char (`Label.visible_ratio` tweened, length-scaled); an advance press completes the reveal, then the next advances/closes. Used the existing Label (not RichTextLabel) — BBCode `[wave]`/`[i]` deferred to the NPC-redesign. *(speech_bubble.gd)*
- [x] **System-wide button juice** — ✅ DONE 2026-06-06. Better than a SkyButton base: `autoloads/ui_juice.gd` hooks node_added → EVERY BaseButton gets hover (up) + press (down) scale juice for free (pairs with the global Audio click hook). Re-entrancy-safe.
- [x] **`HFlowContainer` wrap** — ✅ DONE 2026-06-06. The Profile trophy shelf reflows via HFlowContainer. The backpack stays a fixed-col GridContainer (correct for it). The new-pickup "pop" (await-process-frame) deferred. **S**
- [ ] ⚠️ **Branching data-driven dialogue** — array of line-dicts + `{choice: target_id}`, could become an `NpcDialogue.tres`, branch on `npc_affinity` via a `requires` field. *Our `Overlay` is linear-only — this is the NPC-interaction core* (feeds the NPC-redesign + chatbox TODOs). *(dialogue_tree_ui.gd)* **M**
- [ ] ⚠️ **Project `Theme.tres`** with named `theme_type_variations` (`PanelDialog`/`ButtonPrimary`/`LabelTitle`…) — de-dups **503 `add_theme_*_override` calls across 41 files** + instant reskin. Roll out incrementally (start Overlay + PuzzleScene results). **L**

## 🧱 GDScript / data patterns
- [~] **Exported `Array[NodePath]`** — apply-when-relevant (no concrete prop→prop link needs it yet); pattern noted. **S**
- [ ] ⚠️ **`ItemDef.tres` resources** — convert `PlayerState.ITEM_DEFS` (const dict) to `.tres` files. **FORK** — expands past the MVP lock; your call. **M**
- [x] **Inspector ergonomics** — ✅ ALREADY IN PLACE. `NpcPersonality` already uses `@export_category` groups + `@export_range` on every knob. **S**
- [x] **`##` autodoc convention** — ✅ ALREADY FOLLOWED across the base classes (Juice, Glow, MoodTint, SessionState, …). **S**
- [~] **`Callable`-in-a-var dispatch** — apply-when-relevant (no station/AI `if`-ladder needs refactoring yet); pattern noted. **S**
- [x] **Re-entrancy-safe tween convention** — ✅ APPLIED in `UiJuice` (kills the prior tween before a new one, via a meta handle) — the pattern to copy. **S**

## 🔮 For later (co-op-ready now, netcode later · post-MVP)
- [x] **`SessionState` autoload stub** — ✅ DONE 2026-06-06. `autoloads/session_state.gd` — players dict (1 in SP), add/remove signals, `is_local_authority()`. **M**
- [x] **Authority-gated input** — ✅ DONE 2026-06-06. `player.gd` carries a `peer_id` + gates `_physics_process` + `_unhandled_input` on `SessionState.is_local_authority(peer_id)` (always true in SP). **S**
- [x] **Extract `_spawn_player(id)`** — ✅ DONE 2026-06-06. `BaseLocation` loops `SessionState.players` (one in SP) into `_spawn_player(id)`. **M**
- [ ] **Cutout parented-`_draw()` limbs** — torso→limb child nodes, tween child rotations. **FLAG: big art-rework (L)** — changes the character-art approach; needs your design call (not a drop-in). **L**

## 🚫 Skip / defer
- **Skeleton2D + IK rig** — needs authored skeletons + part sprites; fights placeholder-first (bank only the flip-bend-direction gotcha for a future rigged boss).
- **POT/gettext localization** — text is code-built; defer (route player strings through `tr()` when convenient).
- **The 3D demo scenes** — lift only material/audio *property values*, never the scenes (Forward+/Mobile, not our GLES3 Compatibility target).
