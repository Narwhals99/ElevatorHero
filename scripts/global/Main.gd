# Main.gd (Godot 4)
extends Node2D

@onready var level_root: Node = $level_root
@onready var ui: CanvasLayer = $ui

# Assign your player PackedScene (e.g., elevatorhero_2.tscn) in the Inspector
@export var player_scene: PackedScene

var player: Node2D
var current_level: Node
var current_level_key: String = ""                 # track which level is loaded
var checkpoint := { "level": "", "spawn": "SpawnPoint" }  # last checkpoint

# Menu references
var menu_ref: Control
var menu_layer: CanvasLayer

# ---- CONFIG: EDIT THESE PATHS ----
const MENU_SCENE := "res://scenes/mainmenu.tscn"   # <-- your real menu .tscn
const LEVELS: Dictionary = {
	"playground": "res://scenes/playground.tscn",   # <-- your real level paths
	"elevator":   "res://griffin/scenes/elevator.tscn",
}
const DEFAULT_START_LEVEL := "playground"
const DEFAULT_START_SPAWN := "SpawnPoint"
# ----------------------------------

func _ready() -> void:
	add_to_group("level_manager")
	_show_main_menu()

# ===================== MENU FLOW =====================
func _show_main_menu() -> void:
	_unload_level()

	# Hide in-game UI overlays so they can't cover the menu
	if ui:
		ui.visible = false

	# Clean up any existing menu/layer
	if menu_ref and is_instance_valid(menu_ref):
		menu_ref.queue_free()
	menu_ref = null
	if menu_layer and is_instance_valid(menu_layer):
		menu_layer.queue_free()
	menu_layer = null

	# Put the menu on a high CanvasLayer so nothing draws over it
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 100
	add_child(menu_layer)

	# Instance the menu scene
	var menu_packed: PackedScene = load(MENU_SCENE)
	if menu_packed == null:
		push_error("[Main] MENU_SCENE path invalid: " + MENU_SCENE)
		return
	menu_ref = menu_packed.instantiate()
	menu_layer.add_child(menu_ref)

	# Ensure full-rect and visible
	if menu_ref is Control:
		menu_ref.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_ref.modulate.a = 1.0
	menu_ref.visible = true

	# Connect expected signals from mainmenu.gd
	if not menu_ref.is_connected("start_game_requested", Callable(self, "_on_start_game")):
		menu_ref.connect("start_game_requested", Callable(self, "_on_start_game"))
	if not menu_ref.is_connected("quit_requested", Callable(self, "_on_quit_requested")):
		menu_ref.connect("quit_requested", Callable(self, "_on_quit_requested"))

func _on_start_game(level_id: String) -> void:
	if not LEVELS.has(level_id):
		level_id = DEFAULT_START_LEVEL

	# Remove menu & reveal UI
	if menu_ref and is_instance_valid(menu_ref):
		menu_ref.queue_free()
	menu_ref = null
	if menu_layer and is_instance_valid(menu_layer):
		menu_layer.queue_free()
	menu_layer = null

	if ui:
		ui.visible = true

	# Seed the initial checkpoint so deaths respawn correctly
	set_checkpoint(level_id, DEFAULT_START_SPAWN)
	load_level(level_id, DEFAULT_START_SPAWN)

func _on_quit_requested() -> void:
	get_tree().quit()
# =====================================================

# =================== LEVEL LOADING ===================
func load_level(level_key: String, spawn_name: String = "SpawnPoint") -> void:
	_unload_level()

	if not LEVELS.has(level_key):
		push_error("[Main] Unknown level key: %s" % level_key)
		return

	var path: String = LEVELS[level_key]
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("[Main] Failed to load: %s" % path)
		return

	current_level = packed.instantiate()
	level_root.add_child(current_level)
	current_level_key = level_key

	_ensure_player()
	_position_player_at_spawn(spawn_name)

	# If we don't have a checkpoint yet, set it to this entry
	if String(checkpoint.level) == "":
		set_checkpoint(level_key, spawn_name)

	# Optional broadcast to listeners (enemies/HUD)
	get_tree().call_group("enemies", "on_player_respawned", player)

func _unload_level() -> void:
	if current_level and is_instance_valid(current_level):
		current_level.queue_free()
	current_level = null
	current_level_key = ""
# =====================================================

# ================= PLAYER PERSISTENCE =================
func _ensure_player() -> void:
	if player and is_instance_valid(player):
		return
	if player_scene == null:
		push_error("[Main] player_scene is not assigned in the inspector.")
		return

	player = player_scene.instantiate()
	# Keep the player OUTSIDE level_root so it persists between level loads
	get_tree().root.add_child(player)
	player.add_to_group("player")

	# Ensure a camera is active (Godot 4)
	var cam := player.get_node_or_null("Camera2D")
	if cam:
		if cam.has_method("set_enabled"):
			cam.set_enabled(true)
		else:
			cam.enabled = true
		if cam.has_method("make_current"):
			cam.make_current()

# ----------------- SPAWN HELPERS / CHECKPOINTS -----------------
func _get_spawn(spawn_name: String) -> Node2D:
	if current_level == null:
		return null
	# Allow relative paths like "Spawns/ElevatorSpawn"
	if "/" in spawn_name:
		var n := current_level.get_node_or_null(spawn_name)
		return n if n is Node2D else null
	# Otherwise search by name anywhere in the level
	var found := current_level.find_child(spawn_name, true, false)
	return found if found is Node2D else null

func _position_player_at_spawn(spawn_name: String) -> void:
	if player == null: return
	var spawn := _get_spawn(spawn_name)
	if spawn == null:
		spawn = _get_spawn("SpawnPoint")
	if spawn:
		player.global_position = spawn.global_position
		if player.has_method("set_spawn_point"):
			player.set_spawn_point(player.global_position)  # <— keep in sync
	else:
		push_warning("[Main] spawn not found: '%s' (and no 'SpawnPoint' fallback)" % spawn_name)

func set_checkpoint(level_key: String, spawn_name: String) -> void:
	checkpoint.level = level_key
	checkpoint.spawn = spawn_name

func respawn_player() -> void:
	get_tree().paused = false

	# Seed a default if none yet
	if String(checkpoint.level) == "":
		set_checkpoint(DEFAULT_START_LEVEL, DEFAULT_START_SPAWN)

	# Reload level if needed, else just reposition
	if current_level_key != String(checkpoint.level):
		load_level(String(checkpoint.level), String(checkpoint.spawn))
	else:
		_position_player_at_spawn(String(checkpoint.spawn))
		get_tree().call_group("enemies", "on_player_respawned", player)

	# IMPORTANT: restore player state (unlocks controls, resets i-frames/anim, etc.)
	if player:
		if player.has_method("_respawn"):
			player.call("_respawn")  # uses your existing method
		else:
			# Fallback in case _respawn() is renamed/removed
			if player.has_variable("max_health"): player.health = player.max_health
			if player.has_variable("respawn_i_frames"): player.i_frames = player.respawn_i_frames
			if player.has_variable("controls_locked"): player.controls_locked = false
			if player.has_variable("attacking"): player.attacking = false
