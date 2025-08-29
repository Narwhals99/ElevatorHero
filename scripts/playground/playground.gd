extends Node2D

@onready var spawn_point: Node2D = $ElevatorSpawn
@onready var pause_menu = get_tree().get_first_node_in_group("pause_ui")

func _ready() -> void:
	# Player is now persistent and positioned by Main.gd at "SpawnPoint".
	pass

func _input(event) -> void:
	if event.is_action_pressed("ui_cancel") and pause_menu:
		if get_tree().paused:
			pause_menu.hide_menu()
		else:
			pause_menu.show_menu()
