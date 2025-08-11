# main_menu.gd
extends Control

func _ready():
	$play_button.pressed.connect(_on_play_pressed)
	$quit_button.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	# Change to your "playground" scene
	get_tree().change_scene_to_file("res://scenes/playground.tscn")

func _on_quit_pressed():
	get_tree().quit()
