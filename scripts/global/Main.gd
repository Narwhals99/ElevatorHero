# Main.gd
extends Node2D

@onready var level_root: Node = $level_root
@onready var ui: CanvasLayer = $ui

var current_level: Node
var menu_ref: Control
@export var player_scene: PackedScene
var player: Node2D

const LEVELS: Dictionary[String, String] = {
	"playground": "res://scenes/playground.tscn",
}

func _ready() -> void:
	add_to_group("game_root")	# used by pause menu
	print("[main] ready. ui:", ui, " level_root:", level_root)

	# Instance a single persistent player
	if player == null and player_scene:
		player = player_scene.instantiate()
		player.add_to_group("player")
		add_child(player)			# keep under Main so it persists across floors
		move_child(player, get_child_count() - 1)	# draw above floors (UI is separate)

	_show_main_menu()

func _show_main_menu() -> void:
	var menu_ps: PackedScene = load("res://scenes/mainmenu.tscn")
	menu_ref = menu_ps.instantiate() as Control
	ui.add_child(menu_ref)
	menu_ref.start_game_requested.connect(_on_start_game_requested)
	menu_ref.quit_requested.connect(_on_quit_requested)
	print("[main] menu loaded + signals connected")

func _on_quit_requested() -> void:
	print("[main] quit requested")
	get_tree().quit()

func _on_start_game_requested(level_id: String = "playground") -> void:
	print("[main] start requested:", level_id)
	if is_instance_valid(menu_ref):
		menu_ref.queue_free()
		menu_ref = null
	get_tree().paused = false
	_load_level_by_id(level_id)

func _load_level_by_id(level_id: String) -> void:
	_unload_level()

	var path: String = LEVELS.get(level_id, "")
	if path == "":
		push_error("[main] Unknown level id: " + level_id)
		return

	var ps: PackedScene = load(path)
	if ps == null:
		push_error("[main] Failed to load: " + path)
		return

	current_level = ps.instantiate()
	level_root.add_child(current_level)
	print("[main] level instanced:", current_level.name)

	# Place persistent player at this level's spawn
	var spawn: Node2D = current_level.find_child("SpawnPoint", true, false) as Node2D
	if spawn != null and player != null:
		player.global_position = spawn.global_position
		if player.has_method("set_spawn_point"):
			player.set_spawn_point(spawn.global_position)
	else:
		push_warning("[main] SpawnPoint not found in " + current_level.name)

	# Notify enemies/HUD of the active player
	get_tree().call_group("enemies", "on_player_respawned", player)

func _unload_level() -> void:
	if current_level:
		current_level.queue_free()
		current_level = null

func return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().call_group("pause_ui", "hide_menu")	# in case it’s open
	_unload_level()
	_show_main_menu()
