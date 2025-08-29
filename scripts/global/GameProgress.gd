# GameProgress.gd (Godot 4) — Autoload as "GameProgress"
extends Node

signal floor_unlocked(new_index: int)

# IMPORTANT: THESE MUST MATCH Main.LEVELS KEYS
# Floor 1 = "playground" for now.
const LEVEL_ORDER: Array[String] = [
	"playground",  # Floor 1
	"floor2",      # add to Main.LEVELS when you actually make it
	"floor3",
	"floor4",
	"floor5",
	"floor6",
]

var highest_unlocked_index: int = 0  # 0 => floor1 unlocked
var cleared: Dictionary = {}         # "level_key": true

func _ready() -> void:
	_load()

func is_floor_unlocked_by_index(idx: int) -> bool:
	return idx >= 0 and idx < LEVEL_ORDER.size() and idx <= highest_unlocked_index

func is_floor_unlocked_by_key(key: String) -> bool:
	var idx := LEVEL_ORDER.find(key)
	return idx != -1 and is_floor_unlocked_by_index(idx)

func mark_floor_cleared(level_key: String) -> void:
	if not cleared.get(level_key, false):
		cleared[level_key] = true
		var idx := LEVEL_ORDER.find(level_key)
		if idx != -1 and idx < LEVEL_ORDER.size() - 1:
			if highest_unlocked_index < idx + 1:
				highest_unlocked_index = idx + 1
				emit_signal("floor_unlocked", highest_unlocked_index)
		_save()

func reset_progress() -> void:
	highest_unlocked_index = 0
	cleared.clear()
	_save()

func _save() -> void:
	var data := {
		"highest_unlocked_index": highest_unlocked_index,
		"cleared": cleared
	}
	var f := FileAccess.open("user://progress.save", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _load() -> void:
	if not FileAccess.file_exists("user://progress.save"):
		return
	var f := FileAccess.open("user://progress.save", FileAccess.READ)
	if f:
		var txt := f.get_as_text()
		f.close()
		var result = JSON.parse_string(txt)
		if typeof(result) == TYPE_DICTIONARY:
			highest_unlocked_index = int(result.get("highest_unlocked_index", 0))
			cleared = result.get("cleared", {})
