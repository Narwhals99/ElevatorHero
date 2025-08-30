extends Node

signal floor_unlocked(new_index: int)  # fired whenever the highest unlocked index increases

# Order of gated floors (NOT hubs). Edit to match your game.
@export var LEVEL_ORDER: PackedStringArray = PackedStringArray([
	"playground",  # index 0 (Floor 1)
	"floor2",      # index 1 (Floor 2)
	# "floor3",
])

var highest_unlocked_index: int = 0
const SAVE_PATH: String = "user://progress.save"

func _ready() -> void:
	_load()

# ---------- Query helpers ----------
func get_index_from_key(key: String) -> int:
	return LEVEL_ORDER.find(key)  # -1 if not a gated floor (e.g., "elevator")

func is_floor_unlocked_by_index(idx: int) -> bool:
	if idx < 0:
		return true  # hubs/non-gated
	return idx <= highest_unlocked_index

func is_floor_unlocked_by_key(key: String) -> bool:
	var idx: int = get_index_from_key(key)
	if idx == -1:
		return true  # hubs/non-gated
	return is_floor_unlocked_by_index(idx)

# ---------- State changes ----------
func mark_floor_cleared(level_key: String) -> void:
	# Clearing floor i unlocks i+1
	var i: int = get_index_from_key(level_key)
	if i == -1:
		return  # clearing a hub does nothing
	var target: int = min(i + 1, LEVEL_ORDER.size() - 1)
	if target > highest_unlocked_index:
		highest_unlocked_index = target
		_save()
		emit_signal("floor_unlocked", highest_unlocked_index)
		print("[Progress] cleared '", level_key, "' -> unlock index ", highest_unlocked_index)

func reset_progress() -> void:
	highest_unlocked_index = 0
	_save()
	emit_signal("floor_unlocked", highest_unlocked_index)
	print("[Progress] reset; highest = ", highest_unlocked_index)

# ---------- Persistence ----------
func _save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		var payload: Dictionary = {"highest": highest_unlocked_index}
		f.store_var(payload)

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f != null:
		var data: Variant = f.get_var()
		if data is Dictionary:
			var dict: Dictionary = data
			if dict.has("highest"):
				highest_unlocked_index = int(dict["highest"])
