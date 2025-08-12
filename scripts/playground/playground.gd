extends Node2D

@onready var pause_menu = $UI/pausemenu  # or whatever path it is

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # Esc by default
		if get_tree().paused:
			pause_menu.hide_menu()
		else:
			pause_menu.show_menu()
