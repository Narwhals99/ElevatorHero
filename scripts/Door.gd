# Door.gd (Godot 4) — allow hub levels like "elevator" to bypass floor locks
extends Area2D

@export var target_level_key: String = ""
@export var target_spawn_name: String = "SpawnPoint"
@export var require_interact: bool = true
@export var interact_action: String = "interact"
@export var set_checkpoint_on_use: bool = true
@export_enum("teleport", "open_keypad") var door_action := "teleport"
@export var interior_area_path: NodePath   # optional Area2D for "inside the cab" check

var _player_touching_panel := false
var _player_inside_cab := false
var _used := false

func _ready() -> void:
	# Panel proximity
	if not is_connected("body_entered", Callable(self, "_on_panel_body_entered")):
		connect("body_entered", Callable(self, "_on_panel_body_entered"))
	if not is_connected("body_exited", Callable(self, "_on_panel_body_exited")):
		connect("body_exited", Callable(self, "_on_panel_body_exited"))

	# Optional interior/cab area
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

	match door_action:
		"open_keypad":
			# If you wired an interior area, require the player to be inside before opening keypad
			if interior_area_path != NodePath("") and not _player_inside_cab:
				return
			_open_keypad()
		"teleport":
			_use_teleport()

# ----------------- Actions -----------------

func _open_keypad() -> void:
	var mgr := _get_level_manager()
	if mgr == null:
		push_error("Door.gd: no node in 'level_manager' group found.")
		return
	if mgr.has_method("open_keypad"):
		mgr.call("open_keypad")
	else:
		push_warning("Door.gd: level manager lacks open_keypad().")

func _use_teleport() -> void:
	if target_level_key == "":
		push_warning("Door.gd: target_level_key not set.")
		return

	# If the target participates in the floor lock order, enforce the lock.
	# If it's NOT in LEVEL_ORDER (e.g., 'elevator' hub), allow it.
	var idx := GameProgress.get_index_from_key(target_level_key)
	if idx >= 0:
		if not GameProgress.is_floor_unlocked_by_key(target_level_key):
			push_warning("Door.gd: '%s' is locked; ignoring teleport." % target_level_key)
			return
	# else: idx == -1 → not a floor → bypass lock (hub/utility scene)

	var mgr := _get_level_manager()
	if mgr == null:
		push_error("Door.gd: no node in 'level_manager' group found.")
		return

	if set_checkpoint_on_use and mgr.has_method("set_checkpoint"):
		mgr.call("set_checkpoint", target_level_key, target_spawn_name)

	if mgr.has_method("load_level"):
		mgr.call("load_level", target_level_key, target_spawn_name)
	else:
		push_warning("Door.gd: level manager lacks load_level(key, spawn)")

	_used = true

# ----------------- Signals -----------------

func _on_panel_body_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player_touching_panel = true

func _on_panel_body_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_touching_panel = false

func _on_interior_entered(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside_cab = true

func _on_interior_exited(b: Node) -> void:
	if b.is_in_group("player"):
		_player_inside_cab = false

# ----------------- Helpers -----------------

func _get_level_manager() -> Node:
	var list := get_tree().get_nodes_in_group("level_manager")
	if list.size() > 0:
		return list[0]
	return null
