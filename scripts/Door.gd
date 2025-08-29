# Door.gd (Godot 4) — group-safe version
extends Area2D

@export var target_level_key: String = ""
@export var target_spawn_name: String = ""
@export var require_interact: bool = true
@export var interact_action: String = "interact"
@export var set_checkpoint_on_use: bool = true
@export_enum("teleport", "open_keypad") var door_action := "teleport"
@export var interior_area_path: NodePath

var _player_touching_panel := false
var _player_inside_cab := false
var _used := false

func _ready() -> void:
	if not is_connected("body_entered", Callable(self, "_on_panel_body_entered")):
		connect("body_entered", Callable(self, "_on_panel_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_panel_body_exited")):
		connect("body_exited", Callable(self, "_on_panel_body_exited"))

	var interior := get_node_or_null(interior_area_path)
	if interior and interior is Area2D:
		if not interior.is_connected("body_entered", Callable(self, "_on_interior_entered")):
			interior.connect("body_entered", Callable(self, "_on_interior_entered"))
		if not interior.is_connected("body_exited", Callable(self, "_on_interior_exited")):
			interior.connect("body_exited", Callable(self, "_on_interior_exited"))

func _input(event: InputEvent) -> void:
	if not require_interact:
		return
	if not event.is_action_pressed(interact_action):
		return
	if not _player_touching_panel:
		return

	if door_action == "open_keypad":
		if interior_area_path != NodePath("") and not _player_inside_cab:
			return
		_open_keypad()
	else:
		_go()

func _on_panel_body_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player_touching_panel = true
		if not require_interact and door_action == "teleport":
			_go()

func _on_panel_body_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_touching_panel = false

func _on_interior_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside_cab = true

func _on_interior_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside_cab = false

func _open_keypad() -> void:
	var mgr := get_tree().get_first_node_in_group("level_manager")
	if mgr and mgr.has_method("open_keypad"):
		mgr.call("open_keypad")
	else:
		push_warning("Door.gd: no node in group 'level_manager' with open_keypad()")

func _go() -> void:
	if _used:
		return
	if target_level_key == "" or target_spawn_name == "":
		push_warning("Door: missing target_level_key or target_spawn_name")
		return
	_used = true
	var mgr := get_tree().get_first_node_in_group("level_manager")
	if not mgr:
		push_warning("Door.gd: no node in group 'level_manager'")
		return
	if set_checkpoint_on_use and mgr.has_method("set_checkpoint"):
		mgr.call("set_checkpoint", target_level_key, target_spawn_name)
	if mgr.has_method("load_level"):
		mgr.call("load_level", target_level_key, target_spawn_name)
	else:
		push_warning("Door.gd: level manager lacks load_level(key, spawn)")
