# KeypadUI.gd — name-based mapping, no visual changes
class_name ElevatorKeypadUI
extends Control

signal floor_selected(level_key)
signal closed

# Map your button node NAMES to your level keys here.
# Edit in the Inspector or right here:
@export var button_name_to_key := {
	"Floor1Btn": "playground",
	"Floor2Btn": "floor2",
	# "Floor3Btn": "floor3",  # add more as you build them
}

@onready var close_btn = $CloseBtn

var _buttons := {}                # name -> Button node
var _current_level_key := ""

func _ready() -> void:
	_resolve_buttons()
	_wire_buttons()
	# refresh when progress advances (e.g., after last enemy dies)
	if not GameProgress.is_connected("floor_unlocked", Callable(self, "_on_floor_unlocked")):
		GameProgress.connect("floor_unlocked", Callable(self, "_on_floor_unlocked"))

func open_ui(current_key) -> void:
	_current_level_key = String(current_key)
	_refresh_locks()
	show()

func _on_floor_unlocked(_new_idx) -> void:
	_refresh_locks()

# ---------------- internals ----------------
func _resolve_buttons() -> void:
	_buttons.clear()
	for name in button_name_to_key.keys():
		var n = find_child(String(name), true, false)  # search by NAME anywhere under KeypadUI
		if n and n is BaseButton:
			_buttons[name] = n

func _wire_buttons() -> void:
	for name in _buttons.keys():
		var btn = _buttons[name]
		var cb = Callable(self, "_on_btn_pressed").bind(name)
		if not btn.is_connected("pressed", cb):
			btn.connect("pressed", cb)
	if is_instance_valid(close_btn) and not close_btn.is_connected("pressed", Callable(self, "_on_close")):
		close_btn.connect("pressed", Callable(self, "_on_close"))

func _refresh_locks() -> void:
	for name in _buttons.keys():
		var btn = _buttons[name]
		var key = String(button_name_to_key[name])
		var unlocked = GameProgress.is_floor_unlocked_by_key(key)
		# Do NOT change visibility or text; only gate input
		btn.disabled = not unlocked

func _on_btn_pressed(name) -> void:
	var key = String(button_name_to_key.get(name, ""))
	if key == "":
		return
	# Hard guard: ignore if locked even if disabled was flipped elsewhere
	if not GameProgress.is_floor_unlocked_by_key(key):
		return
	emit_signal("floor_selected", key)
	hide()
	emit_signal("closed")

func _on_close() -> void:
	hide()
	emit_signal("closed")
