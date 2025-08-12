# mainmenu.gd (on your menu root Control)
extends Control
signal start_game_requested(level_id: String)
signal quit_requested

@onready var play_btn: Button = $play_button
@onready var quit_btn: Button = $quit_button

func _ready() -> void:
	# Force connections in code so we don't rely on editor wiring
	if not play_btn.pressed.is_connected(_on_play_pressed):
		play_btn.pressed.connect(_on_play_pressed)
	if not quit_btn.pressed.is_connected(_on_quit_pressed):
		quit_btn.pressed.connect(_on_quit_pressed)
	print("[menu] play connected:", play_btn.pressed.is_connected(_on_play_pressed),
		  " quit connected:", quit_btn.pressed.is_connected(_on_quit_pressed))

func _on_play_pressed() -> void:
	print("[menu] Play pressed")
	emit_signal("start_game_requested", "playground")

func _on_quit_pressed() -> void:
	print("[menu] Quit pressed")
	emit_signal("quit_requested")
