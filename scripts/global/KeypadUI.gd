# KeypadUI.gd (Godot 4)
# Invisible-but-clickable floor buttons
class_name ElevatorKeypadUI
extends Control

signal floor_selected(level_key: String)
signal closed

@onready var close_btn: Button = $CloseBtn
var floor_buttons: Array[BaseButton] = []
var current_level_key: String = ""

func _ready() -> void:
	visible = false
	_collect_buttons()

	for i in floor_buttons.size():
		var btn := floor_buttons[i]
		# Make button invisible but clickable
		if "text" in btn:
			btn.text = ""
		if "flat" in btn:
			btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.self_modulate = Color(1, 1, 1, 0)   # alpha 0 = invisible
		btn.mouse_filter = Control.MOUSE_FILTER_STOP  # still capture clicks
		if not btn.is_connected("pressed", Callable(self, "_on_floor_pressed").bind(i)):
			btn.connect("pressed", Callable(self, "_on_floor_pressed").bind(i))

	if close_btn and not close_btn.is_connected("pressed", Callable(self, "_on_close")):
		close_btn.connect("pressed", Callable(self, "_on_close"))

	if not GameProgress.is_connected("floor_unlocked", Callable(self, "_on_floor_unlocked")):
		GameProgress.connect("floor_unlocked", Callable(self, "_on_floor_unlocked"))

func _collect_buttons() -> void:
	floor_buttons.clear()
	var i := 1
	while true:
		var path := "Floor%dBtn" % i
		if not has_node(path):
			break
		var btn := get_node(path)
		if btn is BaseButton:
			floor_buttons.append(btn)
		i += 1

func open_ui(current_key: String) -> void:
	current_level_key = current_key
	_refresh_buttons()
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_floor_unlocked(_idx: int) -> void:
	_refresh_buttons()

func _refresh_buttons() -> void:
	for i in floor_buttons.size():
		var btn := floor_buttons[i]
		var unlocked := GameProgress.is_floor_unlocked_by_index(i)
		btn.disabled = not unlocked
		# stays invisible either way; disabled prevents clicks on locked floors

func _on_floor_pressed(idx: int) -> void:
	if idx < 0 or idx >= GameProgress.LEVEL_ORDER.size():
		return
	if not GameProgress.is_floor_unlocked_by_index(idx):
		return
	var key := GameProgress.LEVEL_ORDER[idx]
	emit_signal("floor_selected", key)
	hide()

func _on_close() -> void:
	hide()
	emit_signal("closed")
