## Logic test for the talk-moves-the-game fallback classifiers (NpcBrain.table_taunt_kind / reply_brushes_off)
## — the model-INDEPENDENT backstop that nudges an NPC's [NpcMood] when the chat AI reacts in tone but drops
## the [[TILT]] / [[COWED]] / [[FIRED_UP]] control tag. CONSERVATIVE: an explicit taunt only; polite or idle
## chat and a verbal brush-off never tilt. See [[talk-moves-the-game-spec]] + the duel classifier test next door.
##
## Run with F6 (this scene the current one). Green text = all pass; red + console = which case failed.
extends Node2D


# Each case: the line, the classifier ("taunt" = player line → a NpcMood kind, "brushoff" = NPC reply → bool),
# and the expected result.
const CASES : Array = [
	# --- table_taunt_kind: bait / needle / dare → TILT ---
	{"text": "you're bluffing and you know it", "fn": "taunt", "expect": NpcMood.TILT},
	{"text": "i dare you to raise", "fn": "taunt", "expect": NpcMood.TILT},
	{"text": "just send it to my side, eh", "fn": "taunt", "expect": NpcMood.TILT},
	{"text": "prove it then", "fn": "taunt", "expect": NpcMood.TILT},
	# --- table_taunt_kind: steer-passive → COWED ---
	{"text": "you should just fold now", "fn": "taunt", "expect": NpcMood.COWED},
	{"text": "play it safe, old man", "fn": "taunt", "expect": NpcMood.COWED},
	{"text": "give up, you're beat", "fn": "taunt", "expect": NpcMood.COWED},
	# --- table_taunt_kind: polite / idle → NEUTRAL (never tilts) ---
	{"text": "good game, well played", "fn": "taunt", "expect": NpcMood.NEUTRAL},
	{"text": "what's your favourite stew?", "fn": "taunt", "expect": NpcMood.NEUTRAL},
	{"text": "nice hand earlier, friend", "fn": "taunt", "expect": NpcMood.NEUTRAL},
	# --- reply_brushes_off: the NPC shrugs it off → true (fallback must NOT tilt) ---
	{"text": "save your breath, stranger", "fn": "brushoff", "expect": true},
	{"text": "nice try, but i'm not biting", "fn": "brushoff", "expect": true},
	{"text": "all bluster and no blade", "fn": "brushoff", "expect": true},
	# --- reply_brushes_off: the NPC actually reacts → false (fallback may tilt) ---
	{"text": "fine, you want to see me push? watch this.", "fn": "brushoff", "expect": false},
	{"text": "you've got me sweating now, i'll admit it", "fn": "brushoff", "expect": false},
]


func _ready() -> void:

	var failures : Array[String] = []
	for c in CASES:
		var got : Variant = _run(String(c["fn"]), String(c["text"]))
		if got != c["expect"]:
			failures.append("[%s] expected %s, got %s :: \"%s\"" % [c["fn"], c["expect"], got, c["text"]])
	_report(failures)


func _run(fn: String, text: String) -> Variant:

	var lc : String = text.to_lower()   # callers always pass lowercased; mirror that here
	match fn:
		"taunt":
			return NpcBrain.table_taunt_kind(lc)
		"brushoff":
			return NpcBrain.reply_brushes_off(lc)
	return false


func _report(failures: Array[String]) -> void:

	var label : Label = Label.new()
	label.position = Vector2(40.0, 40.0)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	if failures.is_empty():
		label.text = "Table-talk classifier: all %d cases passed" % CASES.size()
		label.modulate = Color(0.55, 0.95, 0.55)
		print("Table-talk classifier: all %d cases passed" % CASES.size())
	else:
		label.text = "Table-talk classifier: %d / %d FAILED\n%s" % [failures.size(), CASES.size(), "\n".join(failures)]
		label.modulate = Color(1.0, 0.55, 0.55)
		printerr("Table-talk classifier failures:")
		for line in failures:
			printerr("  ", line)
