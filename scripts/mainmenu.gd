# mainmenu.gd (Godot 4) — attach to your menu scene root (Control)
extends Control

signal start_game_requested(level_id: String)
signal quit_requested

@onready var play_button: Button = $play_button
@onready var quit_button: Button = $quit_button

# Optional: choose a default level key to start
@export var default_level_key: String = "playground"

func _ready() -> void:
	# Ensure full rect
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if play_button and not play_button.is_connected("pressed", Callable(self, "_on_play_pressed")):
		play_button.connect("pressed", Callable(self, "_on_play_pressed"))
	if quit_button and not quit_button.is_connected("pressed", Callable(self, "_on_quit_pressed")):
		quit_button.connect("pressed", Callable(self, "_on_quit_pressed"))

func _on_play_pressed() -> void:
	emit_signal("start_game_requested", default_level_key)

func _on_quit_pressed() -> void:
	emit_signal("quit_requested")
