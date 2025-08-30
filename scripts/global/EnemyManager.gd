# EnemyManager.gd (Godot 4) — real-death only + clear diagnostics
extends Node

@export var level_key: String = ""                  # e.g., "playground" (MUST match GameProgress.LEVEL_ORDER)
@export var enemy_group: String = "enemies"         # every enemy should be in this group
@export var unlock_if_no_enemies: bool = false
@export var enemies_root_path: NodePath             # optional: "Enemies" container
@export var debug_logs: bool = true                 # turn on/off prints

var _alive: int = 0
var _initial_total: int = 0
var _cleared_once: bool = false
var _wired_ids: Array[String] = []

func _ready() -> void:
	# Auto-fill level_key from level root meta if blank
	if level_key == "" and get_parent() and get_parent().has_meta("level_key"):
		level_key = String(get_parent().get_meta("level_key"))
	if debug_logs:
		print("[EM] READY level_key='", level_key, "'")

	_wire_enemies()
	_check_cleared()  # handles the case where all were already dead for this run

func _wire_enemies() -> void:
	_alive = 0
	_initial_total = 0
	_wired_ids.clear()

	var level_root: Node = get_parent()
	var level_root_path: String = (String(level_root.get_path()) + "/") if level_root != null else ""
	var enemies: Array = []

	# Collect via group, limited to this level subtree
	for n in get_tree().get_nodes_in_group(enemy_group):
		if n is Node:
			var p: String = String(n.get_path())
			if level_root_path == "" or p.begins_with(level_root_path):
				enemies.append(n)

	# Optionally include a specific container’s direct children
	var root_node: Node = get_node_or_null(enemies_root_path)
	if root_node:
		for child in root_node.get_children():
			if child is Node and not enemies.has(child):
				enemies.append(child)

	if debug_logs:
		print("[EM] found ", enemies.size(), " enemies in subtree")

	for e in enemies:
		var id: String = _persist_id_for(e, level_root)
		_initial_total += 1

		if RunState.is_enemy_dead(level_key, id):
			if e is CanvasItem:
				e.visible = false
			if debug_logs:
				print("[EM] already dead (hiding): ", id)
			continue

		_alive += 1
		_wired_ids.append(id)

		# Only listen for a real death signal.
		if e.has_signal("died"):
			if not e.is_connected("died", Callable(self, "_on_enemy_died_id")):
				e.connect("died", Callable(self, "_on_enemy_died_id").bind(id))
			if debug_logs:
				print("[EM] wired 'died' for: ", id)
		else:
			if debug_logs:
				print("[EM][WARN] enemy has no 'died' signal: ", id, " (won't decrement)")

	if debug_logs:
		print("[EM] initial_total=", _initial_total, " alive=", _alive)

func _persist_id_for(n: Node, level_root: Node) -> String:
	if level_root:
		var root_path := String(level_root.get_path()) + "/"
		var full := String(n.get_path())
		if full.begins_with(root_path):
			return full.substr(root_path.length())
	return String(n.get_path())

func _on_enemy_died_id(id: String) -> void:
	if debug_logs:
		print("[EM] died: ", id)
	if not RunState.is_enemy_dead(level_key, id):
		RunState.mark_enemy_dead(level_key, id)
		_alive = max(0, _alive - 1)
		if debug_logs:
			print("[EM] alive now=", _alive)
		_check_cleared()

func _check_cleared() -> void:
	if _cleared_once:
		return
	# Unlock only if there WERE enemies or you explicitly allow no-enemy floors
	if _alive <= 0 and (unlock_if_no_enemies or _initial_total > 0):
		_cleared_once = true
		if debug_logs:
			print("[EM] *** FLOOR CLEARED for '", level_key, "' — unlocking next ***")
		GameProgress.mark_floor_cleared(level_key)
		# Safety: verify on next frame too
		call_deferred("_post_unlock_verify")

func _post_unlock_verify() -> void:
	if debug_logs:
		print("[EM] verify unlock → index for '", level_key, "'=",
			GameProgress.get_index_from_key(level_key),
			" highest_unlocked_index=",
			GameProgress.highest_unlocked_index)
