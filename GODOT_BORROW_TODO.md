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
- [ ] **ClearBurst particles** — a reusable `GPUParticles2D` sub-emitter chain (impact→shards→puff), `one_shot`, `.restart()` at a cleared cell. Capture the cell pos as a primitive BEFORE `queue_free`. *(space_scene.tscn)* **M**
- [ ] **Procedural `PointLight2D` glows** — radial GradientTexture2D, no art. Drop into any scene-per-component `.tscn`: forge glow, Skydock lanterns, piece halos. *(2d_dynamic_lights/gem.tscn)* **S**
- [ ] **`clip_children=2` masking** — (a) circular procedural NPC avatars (Overlay + Profile tab → fills the placeholder-avatar slot); (b) clip sparks to the Loft/Patchworks gauges so juice can't spill. *(2d_clipping)* **S**
- [ ] **`CanvasModulate` + `DirectionalLight2D` + `LightOccluder2D`** — per-location mood (blue night Cradle Rock, warm tavern, dark Mine with a player light). Occluders on props already solid. **M**
- [ ] **Scrolling-noise fog/clouds** — `FastNoiseLite` → thin scroll shader; drifting mist beneath the floating islands (parallax bands). *(top_clouds.gdshader)* **M**
- [ ] **Idle/breathing tween loops** (`set_loops()`) — cheap aliveness: a bob on the `_draw()` NPCs + the hovering ship. **S**

## 💬 UI & dialogue
- [x] **Typewriter dialogue reveal** — ✅ DONE 2026-06-06. `Overlay` types each dialog line / lore body out char-by-char (`Label.visible_ratio` tweened, length-scaled); an advance press completes the reveal, then the next advances/closes. Used the existing Label (not RichTextLabel) — BBCode `[wave]`/`[i]` deferred to the NPC-redesign. *(speech_bubble.gd)*
- [ ] **Self-animating `SkyButton`** — a small `extends Button` giving every code-built button (dialogue choices, results, station picks) entrance/exit juice for free. **S**
- [ ] **`HFlowContainer` wrap + bounce-in-after-one-frame** — backpack + trophy/mastery grids wrap as the bag expands; new pickups pop. (Copy the `await process_frame` gotcha.) **S**
- [ ] ⚠️ **Branching data-driven dialogue** — array of line-dicts + `{choice: target_id}`, could become an `NpcDialogue.tres`, branch on `npc_affinity` via a `requires` field. *Our `Overlay` is linear-only — this is the NPC-interaction core* (feeds the NPC-redesign + chatbox TODOs). *(dialogue_tree_ui.gd)* **M**
- [ ] ⚠️ **Project `Theme.tres`** with named `theme_type_variations` (`PanelDialog`/`ButtonPrimary`/`LabelTitle`…) — de-dups **503 `add_theme_*_override` calls across 41 files** + instant reskin. Roll out incrementally (start Overlay + PuzzleScene results). **L**

## 🧱 GDScript / data patterns
- [ ] **Exported `Array[NodePath]`** — wire prop→prop links in the editor (favor-giver→target, station→launch markers) instead of `%UniqueName` lookups. **S**
- [ ] ⚠️ **`ItemDef.tres` resources** — convert `PlayerState.ITEM_DEFS` (const dict) to `.tres` files; "add an item" = drop a `.tres`. Like `NpcPersonality` already does. **M**
- [ ] **Inspector ergonomics** — `@export_group("X","prefix_")` + `@export_range(...,"suffix:gold")` to fold/annotate `NpcPersonality` knobs. **S**
- [ ] **`##` autodoc convention** — codify "doc-comment every new base class" as a CLAUDE.md rule. **S**
- [ ] **`Callable`-in-a-var dispatch** — clean fit for station/AI hooks instead of `match`/`if` ladders. **S**
- [ ] **Re-entrancy-safe tween convention** — store the tween in a member var + `kill()` before recreate, for any input-repeatable animation (Loft fast re-swap, hover-pulse). Codify. **S**

## 🔮 For later (co-op-ready now, netcode later · post-MVP)
- [ ] **`SessionState` autoload stub** — mirror the multiplayer signal shape (`player_added`/`player_removed`, a `players` dict of size 1 in SP). Swap in ENet later, almost nothing else changes. **M**
- [ ] **Authority-gated input** — `if not is_local_authority(): return` (true in SP) on `player.gd` input + InteractionZone-E. Cheapest co-op-ready change today. **S**
- [ ] **Extract `_spawn_player(id, pos)`** from `BaseLocation._ready()` (loop-of-one, keyed by id). **M**
- [ ] **Cutout parented-`_draw()` limbs** — torso→limb child nodes, tween child rotations (idle bob, hit flinch). The realistic upgrade off flat `_draw()`, keeps placeholder-first. **L**

## 🚫 Skip / defer
- **Skeleton2D + IK rig** — needs authored skeletons + part sprites; fights placeholder-first (bank only the flip-bend-direction gotcha for a future rigged boss).
- **POT/gettext localization** — text is code-built; defer (route player strings through `tr()` when convenient).
- **The 3D demo scenes** — lift only material/audio *property values*, never the scenes (Forward+/Mobile, not our GLES3 Compatibility target).
