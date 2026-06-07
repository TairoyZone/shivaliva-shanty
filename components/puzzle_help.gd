## PuzzleHelp — the central how-to-play registry, the source for the user panel's TUTORIAL tab (which
## replaces the old per-puzzle "?" button — Troy 2026-06-07, YPP-style). The overworld Tutorial tab lists
## ALL of these as a help library; inside a puzzle, PuzzleScene pushes the LIVE text for the current puzzle
## (so dynamic help like the Loft's still works). Static class — reference as PuzzleHelp.TUTORIALS / .body_for.
## ids match the launched puzzle (and PlayerState.MASTERY_PUZZLES where applicable).
class_name PuzzleHelp


## Ordered for the library (the 7 MVP puzzles). Each: id · title · body (the how-to shown in the tab).
const TUTORIALS : Array[Dictionary] = [
	{"id": "loft", "title": "The Loft", "body":
		"The Loft — keep her aloft\n\n"
		+ "• Swap two side-by-side tiles to line up 3+ of a colour\n"
		+ "• Clears pump the STARDUST down — let it rise to the top and you're SUNK\n"
		+ "• More holes in the hull = the Stardust rises faster (mend her at the Patchworks)\n"
		+ "• Chain clears back-to-back for combo score — your skill ceiling\n"
		+ "• Sink a drifting BALLAST into the Stardust for a burst of lift"},
	{"id": "skirmish", "title": "Skirmish", "body":
		"Skirmish — bury your foe in garbage to top them out\n\n"
		+ "• ← → move the piece  ·  ↑ rotate  ·  ↓ / SPACE soft drop\n"
		+ "• Clear lines to send GARBAGE to your opponent — fill their board to win\n"
		+ "• Incoming attacks land as grey X-blocks that clog your stack; they can't clear until they\n"
		+ "  RIPEN into coloured tiles (after a couple of your drops)\n"
		+ "• In a crew boarding: CLICK a foe (or [A]/[D]) to target; CLICK a mate to DEFEND them"},
	{"id": "mining", "title": "Mining", "body":
		"How to mine\n\n"
		+ "• Move the 2×2 cursor with the arrow keys or the mouse\n"
		+ "• Rotate it: C / right-click = clockwise,  X / left-click = counter-clockwise\n"
		+ "• Line up 3+ of the same colour to crumble that rock\n"
		+ "• Clear the rock UNDER an ore chunk to dig it to the floor — chunks are the only thing that scores\n"
		+ "• Dig several chunks in one move for a combo bonus\n"
		+ "• Big clears drop a TOOL — frame it (cursor shrinks to 1×1) and click to use it\n"
		+ "• Empty the 'TO DIG' meter to finish the shift"},
	{"id": "gem_drop", "title": "Gem Drop", "body":
		"How to play\n\n"
		+ "• Click an entry slot at the top to drop a gem (your turn only)\n"
		+ "• A gem RESTS on an empty pad, BOUNCES off an occupied pad, and FLIPS a switch when it crosses the lever side\n"
		+ "• Odd flips drop the resting gem off the pad — bumped gems can merge with falling ones into multi-coins (×N score)\n"
		+ "• First to the round target wins the round\n"
		+ "• Best of 4 rounds wins the game (cumulative score tiebreaker)"},
	{"id": "poker", "title": "Poker", "body":
		"Hold 'em Poker — Texas Hold'em\n\n"
		+ "• Click action buttons (Fold / Check / Call / Bet / Raise / All-In)\n"
		+ "• Slide the bet amount on raises\n"
		+ "• Best 5-card hand from your 2 hole cards + 5 community cards wins\n\n"
		+ "• Your chips ARE gold (1:1) — buy in, then Cash Out your whole stack when you Leave\n"
		+ "• Bust and you forfeit your buy-in. Free tables risk no gold (rapport only)"},
	{"id": "lumberjacking", "title": "Lumberjacking", "body":
		"Lumberjacking — work the felled wood\n\n"
		+ "• ← → move the falling pair  ·  ↑ rotate ccw  ·  ↓ rotate cw  ·  SPACE drop faster (hold)\n"
		+ "• Match 3+ of the SAME wood (row, column, or bend) to SHATTER it — that's your score\n"
		+ "• Pack a 2×2 or bigger square of one wood and it FUSES into planks — that's your wood haul\n"
		+ "• Chain shatters back-to-back for combo score\n"
		+ "• Knots are junk — they won't clear, so build around them\n"
		+ "• Let the pile reach the top and the shift's over"},
	{"id": "patchworks", "title": "The Patchworks", "body":
		"The Patchworks — mend the hull\n\n"
		+ "• Drag a tray piece onto the 8×8 hull grid (rotate / flip before you place)\n"
		+ "• Fill a whole ROW or COLUMN to BLAST it clear\n"
		+ "• Back-to-back / multi-line clears combo for more\n"
		+ "• Cleared lines seal the ship's holes → the Loft's Stardust rises slower\n"
		+ "• Right-click a tray piece to toss it — it's endless"},
]


## The how-to body for a puzzle id (empty string if unknown).
static func body_for(id: String) -> String:

	for t in TUTORIALS:
		if t["id"] == id:
			return String(t["body"])
	return ""


## The display title for a puzzle id (falls back to the id itself).
static func title_for(id: String) -> String:

	for t in TUTORIALS:
		if t["id"] == id:
			return String(t["title"])
	return id
