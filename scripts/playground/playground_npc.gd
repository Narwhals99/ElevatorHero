extends CharacterBody2D  # or StaticBody2D if this NPC doesn't move

@export var dialogue_json: String = "res://dialogues/chilis_npc.json"
@onready var dialogue_box := get_tree().get_first_node_in_group("dialogue_ui")

@onready var talk_hint: Label = $talk_hint
@onready var talk_area: Area2D = $talk_area

var player_in_range := false

func _ready() -> void:
	if talk_hint:
		talk_hint.visible = false

	# Avoid duplicate signal connections
	if not talk_area.body_entered.is_connected(_on_talk_area_body_entered):
		talk_area.body_entered.connect(_on_talk_area_body_entered)
	if not talk_area.body_exited.is_connected(_on_talk_area_body_exited):
		talk_area.body_exited.connect(_on_talk_area_body_exited)

func _on_talk_area_body_entered(body: Node) -> void:
	print("[NPC] entered:", body.name)
	if body.name == "elevatorhero_2":
		player_in_range = true
		if talk_hint:
			talk_hint.visible = true
		print("[NPC] player_in_range = true")

func _on_talk_area_body_exited(body: Node) -> void:
	print("[NPC] exited:", body.name)
	if body.name == "elevatorhero_2":
		player_in_range = false
		if talk_hint:
			talk_hint.visible = false
		print("[NPC] player_in_range = false")

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"): # map "interact" to E in Input Map
		if talk_hint:
			talk_hint.visible = false
		_start_conversation()

func _start_conversation() -> void:
	if dialogue_box == null:
		push_error("No DialogueBox found in group 'dialogue_ui'")
		return
	if dialogue_box.has_method("start_dialogue"):
		dialogue_box.start_dialogue(dialogue_json)
	elif dialogue_box.has_method("show_dialogue"):
		dialogue_box.show_dialogue("...")  # fallback if your script uses a different API
