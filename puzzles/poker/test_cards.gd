## Visual smoke test for [CardSprite]. Lays out every face card in a
## 4×13 grid (suits down → Hearts, Diamonds, Spades, Clubs; ranks across
## → A..K) plus all 8 card backs below. Lets us eyeball that the
## spritesheet region math is right before integrating into the real
## game.
##
## Run this scene directly (F6 in Godot or set as main scene) and the
## full deck should render at the configured spacing on a green felt
## background.
extends Node2D


const CARD_SCENE : PackedScene = preload("res://puzzles/poker/card_sprite.tscn")

@export var grid_origin : Vector2 = Vector2(80.0, 80.0)
@export var card_h_spacing : float = 54.0
@export var card_v_spacing : float = 72.0
@export var backs_gap : float = 48.0


func _ready() -> void:

	# Face cards: row per suit (0..3), column per rank (1..13).
	for suit_idx in 4:
		for rank in range(Card.ACE, Card.KING + 1):
			var sprite : CardSprite = CARD_SCENE.instantiate()
			add_child(sprite)
			sprite.position = grid_origin + Vector2(
				(rank - 1) * card_h_spacing,
				suit_idx * card_v_spacing)
			sprite.set_card(Card.new(suit_idx, rank), true)

	# Backs strip below the face grid.
	var backs_y : float = grid_origin.y + 4 * card_v_spacing + backs_gap
	for design in 8:
		var sprite : CardSprite = CARD_SCENE.instantiate()
		add_child(sprite)
		sprite.position = Vector2(grid_origin.x + design * card_h_spacing, backs_y)
		sprite.back_design = design
		sprite.face_up = false
