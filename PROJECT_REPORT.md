# Shivaliva Shanty — Project Report

_Last updated: 2026-06-10_

## What it is
A single-player-first, retro-charming **puzzle-skill adventure** among floating sky-islands — a
spiritual successor to *Puzzle Pirates*, but its own thing. Solo dev (Troy). **Godot 4.6, GDScript, GL
Compatibility, 1280×720, no build step** (run `main.tscn`, or any `puzzles/*/<name>.tscn` standalone).
Windows / OneDrive, git-backed. Sky-pirates among floating islands (not sailors on water) — every water
term is reskinned to a sky/Stardust equivalent ("the Stardust" = the abyss below).

## Dev journey + velocity (the numbers)
_Recompute these from git each report — first-commit date, `git rev-list --count HEAD`, `.gd`/`.tscn` line counts._
- **Started: ~2026-05-24/25** (first locked design calls) → **~17 days** as of 2026-06-10.
- **250 commits** (git baseline 2026-06-03; **7 intense build days** Jun 3·5·6·7·8·9·10, ~36/day).
- **~32,900 lines of hand-built game** — **~29,848 GDScript** across **170 `.gd` files** + **~3,049 lines** across **83 scenes**.
- **Scope:** a walkable iso overworld + a 9-NPC cast · **7 full mini-games** (each a Board+Scene engine w/ AI +
  animation + mastery) · the **voyage meta-system** (deck, set-sail routes, charts, duty reports, a LIVE
  background boarding melee, sinkable ships) · **AI-powered NPC chat** (LLM via a key-safe proxy — a novel hook,
  now situationally aware) · crew/ship-owning · economy/mastery/trophies/save-load/onboarding/HUD · a social parlor.
- **What it'd take a normal person:** this scope is realistically **~10–14 months** of solid solo-dev work
  (7 polished mini-games alone ≈ 4–6 months) — **1.5–2+ years for most hobbyists** (many never finish). Troy
  did it in **~17 days → roughly a 20–30× pace.**

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
  **9-NPC cast** (Brian, Jericho, Kerr, Cinder Troy, Godfrey, Mia, Jade, Ellison, Geneva) with jobs + puzzle
  pipelines. Each persona now carries pronouns + a grounded `chat_role` (what they do/offer in the real systems).
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
- **Three real ship classes** (2026-06-10, `ShipClasses` registry): Driftpod 750g (hull 4 · 1 crew berth ·
  2–3-leg hops · hold ×1.0) → Cloud Cutter 3000g (6 · 2 · 2–4 · ×1.3) → Sky Galleon 10000g (9 · 4 · 4–6 ·
  ×1.6). You **christen** her at purchase, manage the fleet at the **dock berth** (sail / swap / rename /
  sell at half price), and she *draws* as her class (size, 1–3 masts, armament).

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

## This session (2026-06-10) — voices, the SHIP SYSTEM + NPCs that can hate you (all committed)
Troy's first **Fable 5** session. The cast got human; the ships got real; the rapport got teeth.

- **Plain, human, distinct NPC voices** (`eeb9d3f`): the global prompt now bans the thick pirate dialect
  ("ahoy/ye/matey") and sets a plain-English bar (Troy: ESL players must read it easily) — each persona's
  written personality finally drives HOW they talk. World-nouns (ship, stardust, Skydock) stay. Confirmed
  in live play (Kerr's dry jabs vs Mia's tea-mothering).
- **"I'm Troy" is an introduction, not a mix-up** (`533527e`): the cast accepts/remembers/uses a name the
  traveller gives — even one colliding with a local's (Mia had replied "I'm Mia, not Troy").
- **THE ELABORATE SHIP SYSTEM** (`8decc2a`, the session's centerpiece — design forked via 2 questions,
  "full spread" + dock picker locked): the `ShipClasses` registry single-sources every class stat
  (see the voyage section); **christening** ("name her!", dice-roll suggestions, re-christen at the dock);
  the **DockBerthModal** fleet hub (sail / swap ★ / rename / two-click **sell**); class-driven hull caps
  (`voyage_max_holes` — a galleon survives 9 holes, fixed the old clamp-to-4), route lengths, **hold
  multiplier** on the plunder pool, crew **berth caps** at the stations, class visuals at the dock + deck;
  NPC chat names her class. Also fixed: the shop's id mismatch that broke 2 of 3 ships' display names.
- **NPCs can HATE you** (`cb6e038`): rapport now spans **-100..100** — tiers Wary/Disliked/Despised; the
  NPC itself judges a line crossed in chat (hidden `[[OFFENDED]]` tag, same plumbing as `[[DUEL]]`, -4 a
  hit; banter explicitly safe); soured NPCs go cold in chat, show **red** in Hearts, and withhold their
  Favour. Profile reads "Friends: N" — never "of 9" (befriending the whole cast isn't the point). Core
  earning never gates on rapport (the parlor LAW).
- **Feel/UI:** Crew Duty button only when captaining your own ship (`e40b247`) · weapon slots **toggle**
  (click to equip, click again to unarm, `a944a0c`) · trophy shelf folds behind "See all N" (`14ed35c`) ·
  duty report "off duty" for unmanned legs (`5d02027`/`3544c5f`) · prices stripped from chat roles (`3c7de8e`).
- **Adversarially reviewed + fixed** (`8620494`): a 5-angle multi-agent review swept both headline systems
  (voyage state, economy exploits, modal lifecycle, negative-affinity fallout, @tool safety). **11 confirmed
  bugs fixed** — incl. an offense-tag reply that spoke a *warm* canned line over the souring, a two-click
  sell that survived a rename (one stray click could sell a just-named ship), the `/crew` cheat failing on
  soured NPCs, the berth cap blocking a legal crew *move*, and resume-into-a-phantom-voyage if you closed
  the app mid-sail.
- **Your own ship carries YOUR crew** (`9078cb5`): captaining your own hull seated *random* cast at the
  stations — now it's only your recruited crew (capped to berths), and **with none recruited you sail solo**
  (no NPCs aboard). Jobbed runs unchanged (those are the AI captain's hands).
- ⚠️ **Needs playtest:** christening + dock-berth feel, a galleon 4–6-leg run, hold-mult economy, the
  offense tag's fire-rate (too touchy vs too tolerant), the new voices across the whole cast.

## Prior session (2026-06-09) — the NPC-CHAT DEPTH arc + UI/bug polish (all committed)
A massive Troy-driven pass making the **AI-chat hook the game's soul** — the cast now reacts to the live
moment AND knows the world — plus a wave of UI-placement fixes and voyage bug-fixes. Each piece scan-verified;
the two riskiest (duel reliability, poker live-awareness) adversarially reviewed via multi-agent workflows.

- **NPCs CHALLENGE you to a duel via chat → the Ayo! inbox:** chat a cast member (public/private) and if it
  turns competitive they can challenge you to a Skirmish duel; it lands in the **Ayo!** tab (Accept → the duel,
  Reject → a small rapport ding). Made RELIABLE (a red-team workflow): filing no longer depends on the AI
  emitting a hidden `[[DUEL]]` tag (the no-markup rule suppressed it) — a deterministic proposal/accept
  classifier fires it too, per-responder so only the accepter is filed. Per-NPC `duel_appetite`.
- **Battle memory:** a persisted per-NPC head-to-head W/L (`npc_battle_record`) folded into chat so NPCs own
  the score + never deny a real defeat, + a post-fight banter bubble. In-code only (no UI).
- **★ STANDING PRINCIPLE — live situational awareness:** any scene implements `npc_chat_context(npc_name)` →
  folded into the prompt. Built for **POKER**: the seated cast read the live hand (every stack, the pot, the
  board, their OWN cards, the recent action — raises/folds/all-ins/busts) and react in real time. Hidden-info
  safe (only the asker's own cards), adversarially reviewed (16 agents).
- **Poker TABLE CHAT:** the chat bar now shows at the felt (a `chat_scene` group un-hides it) + each seated
  `PokerSeat` joins the `npc` group → chat the cast at the table, public or private.
- **World grounding + role/offer uplift (no more contradictions):** `ISLAND_GAZETTEER` (every spot + who's
  there + what they offer) + per-room `PLACES` props + per-NPC **`chat_role`** (real job/offer, grounded in
  the systems) so NPCs stop denying their own hiring board / helm / shop (Godfrey + Jericho fixed). + `pronouns`
  per NPC (Jericho "she"→he). Shop PRICES kept OUT of the dialogue — the shop UI is the source of truth (no drift).
- **UI placement pass:** Leave button back to **bottom-left** by default (only poker top-left — its chat bar
  owns the bottom); poker stake banner → top-right; Mine headers centered above the board; the Mine "TO GET"
  meter starts empty + fills as you dig; swept EVERY puzzle HUD for the Leave overlap (one global change).
- **Voyage bug-fixes:** (1) **poker → back-to-voyage** — `clear_voyage` clears the stale `puzzle_return_scene`
  that warped you into the over voyage on a puzzle Leave; (2) **duty report "Booched"** — a leg you WATCHED
  (never manned) now reads **"off duty"** (not a botch), labels the station you actually manned (Loft vs
  Patchworks), and doesn't skew the overall duty; a pure-passenger run reads "off duty" + a fair ×1.0 par cut.
- Earlier in the session: poker river-card re-deal fix, the Ayo! badge lingering after New Game, and
  **Operation Marie Kondo** (a reusable `Modal` base + dead-voyage-system delete).

## Prior session (2026-06-08 → 09) — the ship-owning + crew arc (all committed)
A Troy-driven depth pass on **owning a ship + running a crew** — a deliberate expansion past the pure polish
lock, closing the gap where "owning a ship" meant nothing mechanical. Each piece scan-verified; the risky ones
adversarially reviewed.

- **NPC profiles + the CREW foundation:** an `NpcProfileCard` (portrait · role · your rapport · bio · their
  favour) opening with an **Abilities** ★ readout (`CrewSkills` — Combat/Sailing/Repair/Cards/Craft, 1–5, tuned
  distinct per cast) = the "why hire them". **Recruit** a CONFIDANT (rapport ≥ 80, the tier the affinity design
  already reserved) → a persisted **`crew`** with **ranks** (Deckhand→First Mate) → a **crew roster** on your
  ★ Profile (promote / demote / dismiss, live).
- **Duty-stations (full — 6 phases, adversarially reviewed):** assign crew to the voyage's three stations
  (Sailing→Loft, Repair→Patchworks, Combat→boarding) via a deck **Crew Duty** panel. You man ONE station live;
  the crew you posted to the others are auto-resolved **by skill into the real voyage code points** — a posted
  sailor slows the Loft's rise (`sailing_rise_relief`), a carpenter passively seals holes (gated by
  `mastery_id != "patchworks"` so it never double-dips when you patch by hand), a fighter adds boarding-footing
  clumps (`voyage_seed_from_lift`).
- **Captain your OWN ship — the ownership gap closed:** owning a ship was *vanity* ("set sail" ran the jobbing
  loop on a borrowed hull). Now a **"Captain the Driftpod"** row sails YOUR ship: her name on the deck (you
  captain; your top hand is the "Mate"), her **persisted hull condition carried in → damaged → written back**
  on arrival (so the port Patchworks finally mends a hull that gets hurt). Shared
  `PlayerState.captain_own_voyage`; reviewed (one field-bleed fix on the jobbing reset).
- **A moored Driftpod you physically walk onto:** a `Dock` pier off Cradle Rock's shore edge with the
  **`MooredShip`** berthed at it (appears once owned; drawn breaches show her wear) — walk out + **Board** to
  set sail. Containment is an **editable `CollisionPolygon2D`** in the scene (Troy shaped it on sight); dock +
  ship sizes are inspector-tunable (`steps`/`step_len`/`plank_width`, `ship_scale`).
- **Trade system:** click-to-add barter with NPCs (hand items / gold both ways), economy-reviewed (barter
  never out-pays delivery; the favour gold-tip removed as a renewable tap) + a visual pass (icon slots, coin chip).
- **Ambient room chat + smarter NPCs:** a new `RoomChat` autoload — scene-wide **"All"** chat where present
  NPCs may pipe up (a name-mention or a room greeting elicits a reply); **environment awareness** (NPCs know
  the room they're in); broke-player **friendly Gem Drop** (no stake at zero gold → rapport only).
- **Chat scope selector (your Valorant idea):** a persistent left chip — **"All ▾"** (the room) / **"→ Name ▾"**
  (private, in the NPC's colour) — opens a picker of everyone present to choose who you're talking to.
- **Dev slash-commands** (debug builds only — replaced F-keys that clashed with Godot's editor): `/crew` (seed
  a test crew: cast → Confidant + 4 hired), `/gold`, `/holes`, `/mend`, `/wreck`, `/help`.
- **Fixes:** the ★ Profile tab rebuilt as a single vertical column (the 3-column layout kept spilling Skills
  off the panel); free poker = 1000-chip standard buy-in; mining "to dig" meter moved beside the board + its
  HUD overlap fixed; no-negative-gold honesty on the Gem-Drop stake.

## Recent work (2026-06-05 → 08, all committed)
A. **AI NPC chat — the unique hook (2026-06-07):** chat freely with the cast; in-character LLM replies
   (DeepSeek via a key-safe **proxy**, personality on `NpcPersonality` chat_* fields), routed through the
   chat box as a private "→ Name" mode; **affinity shapes warmth/openness**; an Options on/off toggle.
B. **Sunshine Widget — the consolidated user panel (2026-06-08):** a foldable right-edge icon tab rail
   (Tutorials · Backpack · Hearts · Profile + a Jobs launcher + an **Ayo!** trophy-claim tab with a count
   badge). Replaced the per-puzzle "?" AND the old right-side quick-menu. **Tutorials shows only the
   current scene's** how-to; trophies go earned → **claimed in Ayo!** → then onto the Profile shelf.
C. **Economy guard (2026-06-08):** gold can never go negative; cash play is gated on affordability everywhere.
0. **HUD overhaul + UI hardening (2026-06-07):** a big, well-reviewed pass —
   - **Real meter bars:** new reusable `components/meter_bar/` (`MeterBar`) — animated tweened fill,
     segmented (hull notches) / smooth (stardust), green→amber→red states + danger/sink ticks. Replaced
     the deck's lonely hull icon AND the Loft's LIFT/HULL text gauges; **retired `HullGauge`**.
   - **Decluttered ship deck:** killed the 760px captain banner (now a transient `SpeechBubble` + a log
     echo, deduped so it never repeats on deck re-entry); consolidated HULL + STARDUST into ONE top-left
     vessel panel; voyage chart → a hover-expand top-centre **strip** (`place_collapsed_top`, polled hover);
     quick-menu → slim **icon** buttons (new `interface/quick_menu/` `MenuGlyph`: bag/heart/star/pickaxe).
   - **ESC system:** ESC now opens a new **`PauseMenu`** (Resume / Options / Quit-to-Title — moved OUT of
     the backpack); HUD ESC chain = close backpack → close chat log → else pause. **STANDING RULE: every
     window closes on ESC** via the new `components/esc_to_close/` (`EscToClose`) on all 11 modals.
   - **Bugs fixed:** deck click-ON-target (was click-anywhere-while-near); `clear_burst` shadow warning;
     chart collapse min-size + signal-vs-poll hover; shop signal-disconnect hygiene; HUD closes the bag
     when hidden.
   - **New standing rules** (in MEMORY.md + CLAUDE.md): click-on-target, ESC-closes-every-window,
     game-boot-writes-save (booting the game for screenshots writes `save.cfg` — back it up first).

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
- **💬 NPC-CHAT DEPTH (this session's arc):** playtest the cast live now that the AI is online — confirm
  Godfrey/Jericho point you to their board/helm (not deny them), poker NPCs react to the live hand, and a
  chat-driven duel lands in Ayo!. **Tune `duel_appetite`** (how often NPCs challenge) once it's felt. NEXT
  situation-aware scenes (the principle generalizes): gem-drop / skirmish duels (the foe reacting to the
  board), the boarding deck. ⚠️ Deploy the proxy before any friend plays an export (NPC chat is dead otherwise).
- **🚢 SHIP-OWNING + CREW (Troy-driven):** playtest the full loop end-to-end — **recruit** (or
  `/crew`) → **Crew Duty** assign on the deck → **captain the Driftpod** from the moored ship → feel the
  station effects + the hull carry/repair. **Tune the duty-station balance** (Repair's 2-holes/leg seal is the
  strongest knob; Sailing pays off most when you man the Loft live). The dock collision is finalized (Troy
  shaped it); nudge dock/ship size + position to taste. Possible follow-ups: a self-captain booty-cut bonus,
  more cast-recruitable depth, a dedicated crew/duty-station UI polish.
- **⏳ IN PROGRESS — refine the HUD (Troy 2026-06-07):** Troy said "I still need to refine the HUD" —
  the overhaul above is done + reviewed, but he wants more refinement (specifics TBD — ask him). The deck
  HUD, vessel panel, meter bars, pause menu + chart strip are all live; iterate on feel/layout from there.
- **DECISION NEEDED — the "later forks"** (deferred, need Troy's green light, all flagged in the todo):
  - `Theme.tres` — centralize the heavy inline `StyleBoxFlat` duplication into one Godot Theme. Real DRY
    win, BUT a big refactor with visual-regression risk → **recommend AFTER the demo**, not during the lock.
  - `ItemDef.tres` — data-drive `PlayerState.ITEM_DEFS` as resources. Nice architecture, not polish →
    **recommend defer** (the dict works; MVP is locked).
  - Cutout-limb character art — needs Troy's art direction (placeholder humanoids today).
  - Audio call-site wiring + juice/feel + voyage-pace tuning — needs a real playtest (subjective feel).
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

# TROY's TODO (next session) #
--- THE SHIP SYSTEM (new 06-10 — playtest it!) ---
= buy a ship → christen her (the "name her" card) → click the moored ship → the BERTH hub (sail/rename/sell)
= sail a Cloud Cutter / Sky Galleon run: feel the longer routes + the bigger booty cut + the berth caps
= sell a ship (two-click confirm) + check the dock redraws as the new active class (size + masts)
--- NPC VOICES + HATE (new 06-10) ---
= chat the cast — voices should read PLAIN + distinct (no "ahoy ye matey"); introduce yourself by name
= try genuinely insulting someone (for science): rapport should sour → red row in Hearts → favour withheld
= tune the offense sensitivity by feel (OFFENSE_HIT = 4 in npc_brain.gd; the tag prompt is in _affinity_block)
--- CARRY-OVER ---
= tune duel_appetite (challenge frequency) + persona chat_* fields by feel
= deploy the proxy to a free Node host before the public demo (see proxy/README.md)
= a self-playthrough + a written playtest checklist/script before a friend plays
--- IDEAS PARKED ---
= per-class WALKABLE deck layouts (the deck props are hand-placed — needs 3 hand-tuned scenes; flagged 06-10)
= the cast permanently remembers your introduced name (PlayerState + prompt, pairs w/ romance groundwork)
