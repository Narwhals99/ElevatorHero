extends CanvasLayer

func _ready():
	visible = false  # Start hidden

func show_menu():
	visible = true
	get_tree().paused = true

func hide_menu():
	visible = false
	get_tree().paused = false

func _on_resume_pressed():
	hide_menu()

func _on_main_menu_pressed():
	get_tree().paused = false
	var game = get_tree().get_first_node_in_group("game_root")
	if game:
		game.call("return_to_main_menu")
