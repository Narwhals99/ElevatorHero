# RunState.gd (Godot 4) — Autoload as "RunState"
extends Node

# ---- Enemy persistence (per run) ----
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

# ---- Lives (per floor, in-memory for this run) ----
# lives_remaining[level_key] -> int
var lives_remaining: Dictionary = {}
var default_lives_per_floor: int = 3

func set_default_lives_per_floor(n: int) -> void:
	default_lives_per_floor = max(1, n)

func ensure_lives(level_key: String, default_lives: int = -1) -> void:
	var d := default_lives
	if d <= 0:
		d = default_lives_per_floor
	if not lives_remaining.has(level_key):
		lives_remaining[level_key] = d

func get_lives(level_key: String) -> int:
	if not lives_remaining.has(level_key):
		return default_lives_per_floor
	return int(lives_remaining[level_key])

func consume_life(level_key: String) -> int:
	ensure_lives(level_key, default_lives_per_floor)
	var rem: int = int(lives_remaining[level_key])
	rem = max(0, rem - 1)
	lives_remaining[level_key] = rem
	return rem

# ---- Run reset (called when returning to main menu) ----
func reset_run() -> void:
	dead_enemies.clear()
	lives_remaining.clear()

# Back-compat alias if other code calls clear_all()
func clear_all() -> void:
	reset_run()
