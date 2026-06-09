## Logic test for the deterministic duel classifiers (NpcBrain.is_duel_proposal / reply_accepts_duel /
## reply_declines_duel) — the model-INDEPENDENT fallback that files an NPC duel challenge when the chat AI
## agrees in words but drops the [[DUEL]] control tag (it kept treating it as banned markup). Pins behaviour on
## the EXACT phrases from the live incident (Flint Kerr ACCEPTS, Spritely Mia SPECTATES) so a future lexicon
## edit can't silently regress it. See the duel-marker-reliability review + [[ayo-tidings-inbox]].
##
## Run with F6 (this scene the current one). Green text = all pass; red + console = which case failed.
extends Node2D


# Each case: the line, which classifier to run ("proposal" = player line, "accept"/"decline" = NPC reply), and
# the expected boolean. The proposal/accept cases are the literal lines from the reported failure.
const CASES : Array = [
	# --- is_duel_proposal (the PLAYER's line) ---
	{"text": "invite me into a duel then", "fn": "proposal", "expect": true},
	{"text": "fight me lol", "fn": "proposal", "expect": true},
	{"text": "let's spar, Kerr", "fn": "proposal", "expect": true},
	{"text": "don't duel me lol", "fn": "proposal", "expect": false},          # negation veto
	{"text": "that was a tough fight earlier", "fn": "proposal", "expect": false},  # past-tense banter, no frame
	{"text": "i hate fighting, it's not my way", "fn": "proposal", "expect": false}, # negation veto
	# --- reply_accepts_duel (Kerr ACCEPTS — must file) ---
	{"text": "fine — i'll sharpen that attitude for you. name the stakes, stranger.", "fn": "accept", "expect": true},
	{"text": "clear the floor by the hearth — i'll keep it short", "fn": "accept", "expect": true},
	# --- reply_accepts_duel (Mia SPECTATES — must NOT file) ---
	{"text": "oh my stars, this ought to be right entertaining!", "fn": "accept", "expect": false},
	{"text": "carve out some space by the hearth before somebody chips a tooth", "fn": "accept", "expect": false},
	# --- reply_declines_duel (a hard veto that beats an accept match) ---
	{"text": "maybe another time, stranger", "fn": "decline", "expect": true},
	{"text": "not in the mood for a scrap", "fn": "decline", "expect": true},
	{"text": "name the stakes, then", "fn": "decline", "expect": false},
]


func _ready() -> void:

	var failures : Array[String] = []
	for c in CASES:
		var got : bool = _run(String(c["fn"]), String(c["text"]))
		if got != bool(c["expect"]):
			failures.append("[%s] expected %s, got %s :: \"%s\"" % [c["fn"], c["expect"], got, c["text"]])
	_report(failures)


func _run(fn: String, text: String) -> bool:

	var lc : String = text.to_lower()   # callers always pass lowercased; mirror that here
	match fn:
		"proposal":
			return NpcBrain.is_duel_proposal(lc)
		"accept":
			return NpcBrain.reply_accepts_duel(lc)
		"decline":
			return NpcBrain.reply_declines_duel(lc)
	return false


func _report(failures: Array[String]) -> void:

	var label : Label = Label.new()
	label.position = Vector2(40.0, 40.0)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	if failures.is_empty():
		label.text = "Duel classifier: all %d cases passed" % CASES.size()
		label.modulate = Color(0.55, 0.95, 0.55)
		print("Duel classifier: all %d cases passed" % CASES.size())
	else:
		label.text = "Duel classifier: %d / %d FAILED\n%s" % [failures.size(), CASES.size(), "\n".join(failures)]
		label.modulate = Color(1.0, 0.55, 0.55)
		printerr("Duel classifier failures:")
		for line in failures:
			printerr("  ", line)
