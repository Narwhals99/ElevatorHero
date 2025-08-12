# Main.gd
extends Node2D

@onready var level_root: Node = $level_root
@onready var ui: CanvasLayer = $ui

var current_level: Node
var menu_ref: Control

const LEVELS: Dictionary[String, String] = {
	"playground": "res://scenes/playground.tscn",  # <-- path must match your project
}

func _ready() -> void:
	print("[main] ready. ui:", ui, " level_root:", level_root)
	_show_main_menu()

func _show_main_menu() -> void:
	var menu_ps := load("res://scenes/mainmenu.tscn") as PackedScene
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
	if menu_ref:
		menu_ref.queue_free()
		menu_ref = null
	get_tree().paused = false  # just in case
	_unload_level()
	_load_level_by_id(level_id)

func _load_level_by_id(id: String) -> void:
	var path: String = LEVELS.get(id, "")
	print("[main] loading id:", id, "->", path)
	if path == "" or not ResourceLoader.exists(path):
		push_error("[main] level path not found: %s" % path)
		return

	var ps := load(path) as PackedScene
	if ps == null:
		push_error("[main] failed to load PackedScene at: %s" % path)
		return

	current_level = ps.instantiate()
	level_root.add_child(current_level)
	print("[main] level instanced:", current_level.name)

func _unload_level() -> void:
	if current_level:
		current_level.queue_free()
		current_level = null

func return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().call_group("pause_ui", "hide_menu")  # in case it’s open
	_unload_level()
	_show_main_menu()
