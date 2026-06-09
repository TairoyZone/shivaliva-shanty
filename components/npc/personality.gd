## Per-NPC personality knobs. One [Resource] instance per cast member;
## both the [PokerAI] and [GemDropBoard] read from this so the same NPC
## plays consistently across mini-games. Eight instance files live at
## [code]components/npc/profiles/*.tres[/code].
##
## The shape follows the standard pattern from Civilization / Mario
## Party / FIFA: a small set of numeric knobs that bias existing
## heuristics, NOT separate AI scripts per NPC. To add a new NPC,
## clone an existing .tres and tweak the knobs.
##
## Poker-specific knobs use the real-poker analytics terms VPIP
## (Voluntarily Put $ In Pot) and PFR (PreFlop Raise) — together they
## define every poker style on a 2D plane (loose/tight × passive/aggressive).
class_name NpcPersonality
extends Resource


## Display name with adjective prefix ("Flint Kerr", "Cogwise Godfrey").
## Read by seat panels and overworld name tags.
@export var npc_name : String = ""
## Portrait tint — circle background in poker seats, also seeds the
## chip color for "won X chips" toasts. Matches the NPC's overworld
## color so identity reads across scenes.
@export var portrait_color : Color = Color.WHITE

@export_category("Universal")
## How forcefully the NPC pushes situations. High = raises more in
## poker, lays bigger denial plays in gem drop. 0..1.
@export_range(0.0, 1.0) var aggression : float = 0.5
## Tolerance for variance — high = chases draws and takes risky shots,
## low = folds marginal spots and minimizes swings. 0..1.
@export_range(0.0, 1.0) var risk_tolerance : float = 0.5
## Willingness to wait for good situations. High = folds weak hands,
## prefers setup plays over immediate scoring. 0..1.
@export_range(0.0, 1.0) var patience : float = 0.5
## How much the NPC reads YOU — tracks the player's tendencies over
## the session (poker: VPIP, aggression-frequency, fold-rate; gem drop:
## column histogram) and shifts decisions to exploit them. 0 = totally
## oblivious, plays own personality; 1 = sharp reader, leans hard on
## observed patterns. Sample-size gating: no effect until ~5 actions
## have been observed, so the early game still plays personality-pure.
@export_range(0.0, 1.0) var perception : float = 0.3

@export_category("Poker")
## Target VPIP — fraction of hands played voluntarily preflop. The
## strength threshold for "call/raise vs fold preflop" is scaled so
## the NPC averages roughly this VPIP over many hands. Typical
## values: nit 0.12, tight-aggressive 0.22, loose-aggressive 0.40,
## maniac 0.55+.
@export_range(0.0, 1.0) var vpip_target : float = 0.25
## Target PFR — fraction of preflop hands that include a raise.
## Together with VPIP defines style. Tight-passive 0.05, tight-
## aggressive 0.18, maniac 0.40+.
@export_range(0.0, 1.0) var pfr_target : float = 0.15
## Bluff rate — chance to turn a moderate hand into a raise on a
## scary board. Scales with [member aggression] but exposed separately
## so a few NPCs can be "calling stations" with high vpip but no bluff.
@export_range(0.0, 1.0) var bluff_rate : float = 0.25

@export_category("Gem Drop")
## Weight on the NPC's own scoring in the minimax eval. Higher = more
## eager to grab points even at the cost of letting opponent score too.
@export_range(0.0, 2.0) var w_score : float = 1.0
## Weight on denying the opponent's scoring. Higher = block-focused,
## a "spoiler" play style. Set this above [member w_score] for NPCs
## who care more about you NOT winning than themselves winning.
@export_range(0.0, 2.0) var w_denial : float = 1.0
## Weight on multi-step setup / chain potential. Higher = patient
## builder NPCs who plan two turns ahead and prefer enabling positions
## over immediate points.
@export_range(0.0, 2.0) var w_chain : float = 0.5
## Minimax search depth. Caps at 5 so deep-thinking NPCs don't lag
## the frame. Higher = stronger but more uniform; capping per-NPC is
## itself a personality lever (the impulsive cook searches shallow).
@export_range(1, 5) var search_depth : int = 3

## Which Skirmish WEAPON this NPC duels with — shapes the garbage they send.
## "brawl" (fists, the default), "sword", or "long_range". Variety, not power
## (all weapons share one equal budget). See [[combat-puzzle-direction]].
@export var skirmish_weapon : String = "brawl"

@export_category("Voyage")
## How competent a hand this NPC is at a ship DUTY (sailing, gunnery, carpentry,
## navigating). Drives their simulated per-leg DUTY REPORT rating (Booched..Incredible):
## a high-skill crewmate trends Good/Excellent, a poor one botches more often. Per-leg
## variance is layered on top, so even an ace has an off stretch. 0..1.
@export_range(0.0, 1.0) var duty_skill : float = 0.55

@export_category("Chat / AI")
## FREE-FORM CHAT personality (the unique hook). These four fields are composed into the system prompt
## that drives the live NPC conversation (Claude Haiku, via the proxy — see [NpcBrain]). TWEAK THEM HERE
## per NPC, same idea as the GodotNPCAI course's exported fields. Leave blank to fall back to canned lines.
## How they look / carry themselves — a sentence or two of physical/visual character.
@export_multiline var chat_appearance : String = ""
## WHO THEY ARE: voice, manner, mood, what they care about, how they talk. The heart of the character.
@export_multiline var chat_persona : String = ""
## A SECRET they hold — Claude is told to keep it unless the player pointedly digs for it. Optional flavour.
@export_multiline var chat_secret : String = ""
## Where they are, in-world (defaults to Cradle Rock). Grounds the NPC so replies fit the setting.
@export var chat_locale : String = "Cradle Rock, a floating sky-island"
## How readily this NPC throws down a friendly SKIRMISH duel during chat (the unique-hook challenge path).
## 0 = a pacifist who never challenges (a healer); 1 = a scrapper who'll spar at the lightest provocation (a
## swordsman). They ALWAYS take the player up on an explicit challenge — this only biases SPONTANEOUS ones.
## At 0 the duel marker is omitted from the prompt entirely, so they cannot start a fight. See
## [NpcBrain._duel_clause]; the marker is stripped before display + filed as an Ayo! challenge.
@export_range(0.0, 1.0) var duel_appetite : float = 0.12
## Pronouns this NPC goes by — folded into the chat prompt as a cast roster so the OTHER NPCs refer to them
## correctly (the AI otherwise guesses, and guesses wrong). See [NpcBrain._cast_pronouns_block].
@export_enum("he/him", "she/her", "they/them") var pronouns : String = "they/them"
