extends CharacterBody2D

@export var dialogue_json: String = "res://dialogues/chilis_npc.json"

@onready var talk_hint: Label = $talk_hint
@onready var talk_area: Area2D = $talk_area

var player_in_range := false

func _ready() -> void:
	if talk_hint:
		talk_hint.visible = false

	if not talk_area.body_entered.is_connected(_on_talk_area_body_entered):
		talk_area.body_entered.connect(_on_talk_area_body_entered)
	if not talk_area.body_exited.is_connected(_on_talk_area_body_exited):
		talk_area.body_exited.connect(_on_talk_area_body_exited)

func _on_talk_area_body_entered(body: Node) -> void:
	if body.name == "elevatorhero_2":
		player_in_range = true
		if talk_hint:
			talk_hint.visible = true

func _on_talk_area_body_exited(body: Node) -> void:
	if body.name == "elevatorhero_2":
		player_in_range = false
		if talk_hint:
			talk_hint.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		if talk_hint:
			talk_hint.visible = false
		_start_conversation()

func _start_conversation() -> void:
	var dlg := get_tree().get_first_node_in_group("dialogue_ui")
	if dlg == null:
		push_error("No DialogueBox found in group 'dialogue_ui'")
		return

	if dlg.has_method("start_dialogue"):
		dlg.start_dialogue(dialogue_json, "Start")
