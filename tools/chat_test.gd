## DEV-ONLY live chat test: ask Cinder Troy a world-knowledge question and print BOTH the composed system
## prompt (proof the gazetteer + role carry today's facts) AND the live LLM reply (via the proxy / SHANTY_NPC_KEY).
## Not shipped.
extends Node

func _ready() -> void:
	call_deferred("_go")

func _go() -> void:
	var persona = load("res://components/npc/profiles/cinder_troy.tres")
	# Proof #1: the assembled system prompt actually contains today's world (gym / keys / hire gate).
	var sys : String = NpcBrain.compose_system(persona, false)
	print("===SYSTEM_BEGIN===")
	print(sys)
	print("===SYSTEM_END===")
	# Proof #2: a live reply.
	NpcBrain.setup(persona)
	NpcBrain.npc_replied.connect(_on_reply)
	NpcBrain.chat_failed.connect(_on_fail)
	print("===ASK=== How do I get the mining job?")
	NpcBrain.send("How do I get the mining job?")
	await get_tree().create_timer(60.0).timeout
	print("===TIMEOUT=== no reply within 60s (proxy cold/asleep?)")
	get_tree().quit()

func _on_reply(text: String) -> void:
	print("===REPLY_BEGIN===")
	print(text)
	print("===REPLY_END===")
	get_tree().quit()

func _on_fail(reason: String) -> void:
	print("===FAIL=== " + reason)
	get_tree().quit()
