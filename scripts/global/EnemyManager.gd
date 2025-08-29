# EnemyManager.gd (Godot 4) — persists enemy deaths during the current run
extends Node

@export var level_key: String = ""         # MUST match a key in Main.LEVELS (e.g., "playground")
@export var enemy_group: String = "enemies"

var _alive: int = 0
var _cleared_emitted: bool = false

func _ready() -> void:
	# Auto-fill level_key from parent meta if you used the Main.gd helper
	if level_key == "" and get_parent() and get_parent().has_meta("level_key"):
		level_key = String(get_parent().get_meta("level_key"))
	if level_key == "":
		push_warning("EnemyManager: level_key not set")
		return

	# First pass: compute & store a stable ID for every enemy while they're still in-tree
	var list := get_tree().get_nodes_in_group(enemy_group)
	for e in list:
		if e is Node:
			var id := _compute_persist_id(e)
			(e as Node).set_meta("persist_id", id)

	# Cull enemies already marked dead this run
	for e in list:
		if e is Node:
			var id := String((e as Node).get_meta("persist_id", ""))
			if id != "" and RunState.is_enemy_dead(level_key, id):
				(e as Node).queue_free()

	# Rebuild after cull and wire signals with the precomputed ID
	list = get_tree().get_nodes_in_group(enemy_group)
	_alive = 0
	for e in list:
		if not (e is Node): continue
		var n := e as Node
		if not n.is_inside_tree(): continue

		var id := String(n.get_meta("persist_id", ""))
		if id == "":
			id = _compute_persist_id(n)
			n.set_meta("persist_id", id)

		_alive += 1

		# Prefer explicit 'died' signal if your enemy emits it
		if n.has_signal("died"):
			n.connect("died", Callable(self, "_on_enemy_died_id").bind(id))
		# Fallback: when enemy frees itself on death (bind ID so we don't query path later)
		n.connect("tree_exited", Callable(self, "_on_enemy_freed_id").bind(id), CONNECT_ONE_SHOT)

	_check_cleared()

func _compute_persist_id(n: Node) -> String:
	# Stable path relative to the level root (this manager's parent)
	if n.is_inside_tree():
		var level_root_path := String(get_parent().get_path()) + "/"
		var full := String(n.get_path())
		if full.begins_with(level_root_path):
			return full.substr(level_root_path.length())
		return full
	# Fallback if somehow called off-tree
	return n.name

func _on_enemy_died_id(id: String) -> void:
	_mark_dead_id(id)

func _on_enemy_freed_id(id: String) -> void:
	_mark_dead_id(id)

func _mark_dead_id(id: String) -> void:
	if id == "":
		return
	if not RunState.is_enemy_dead(level_key, id):
		RunState.mark_enemy_dead(level_key, id)
		_alive = max(0, _alive - 1)
	_check_cleared()

func _check_cleared() -> void:
	if _cleared_emitted:
		return
	if _alive <= 0 and level_key != "":
		_cleared_emitted = true
		# Optional: unlock next floor on first clear
		GameProgress.mark_floor_cleared(level_key)
