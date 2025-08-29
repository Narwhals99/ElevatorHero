# RunState.gd (Godot 4) — Autoload as "RunState"
extends Node

# dead_enemies[level_key] -> Dictionary of enemy_id -> true
var dead_enemies: Dictionary = {}   # top-level map (String -> Dictionary)

func is_enemy_dead(level_key: String, enemy_id: String) -> bool:
	if not dead_enemies.has(level_key):
		return false
	var level_map: Dictionary = dead_enemies[level_key]
	if not level_map.has(enemy_id):
		return false
	return bool(level_map[enemy_id])

func mark_enemy_dead(level_key: String, enemy_id: String) -> void:
	var level_map: Dictionary
	if dead_enemies.has(level_key):
		level_map = dead_enemies[level_key]
	else:
		level_map = Dictionary()
		dead_enemies[level_key] = level_map
	level_map[enemy_id] = true
	# reassign in case engine returns a copy (keeps intent clear)
	dead_enemies[level_key] = level_map

func clear_all() -> void:
	dead_enemies.clear()
