# Door.gd (Godot 4)
extends Area2D

## Destination (matches a key in Main.gd LEVELS) and a spawn node name in that scene.
@export var target_level_key: String = ""      # e.g. "playground" or "elevator"
@export var target_spawn_name: String = ""     # e.g. "ElevatorSpawn" or "PlaygroundSpawn"

## Interaction
@export var require_interact: bool = true      # true = press a key; false = auto on enter
@export var interact_action: String = "interact"

## Checkpoint behavior
@export var set_checkpoint_on_use: bool = true # if true, death will respawn at this door's destination

var _player_inside := false
var _used := false  # prevents double-trigger during scene switch

func _enter_tree() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _ready() -> void:
	set_process_input(require_interact)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		_player_inside = true
		if not require_interact:
			_go()

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		_player_inside = false

func _input(event: InputEvent) -> void:
	if require_interact and _player_inside and event.is_action_pressed(interact_action):
		_go()

func _go() -> void:
	if _used:
		return
	if target_level_key == "" or target_spawn_name == "":
		push_warning("Door: missing target_level_key or target_spawn_name")
		return

	_used = true  # lock to avoid multiple calls in the same frame

	# Record checkpoint so deaths after transition bring you back here
	if set_checkpoint_on_use:
		get_tree().call_group("level_manager", "set_checkpoint", target_level_key, target_spawn_name)

	# Perform the level swap via Main.gd (level_manager)
	get_tree().call_group("level_manager", "load_level", target_level_key, target_spawn_name)
