extends CanvasLayer

signal opened
signal closed

@onready var root_ctrl: Control = $control
@onready var text_scroll: ScrollContainer = $control/DialogPanel/MainVBox/TextScroll
@onready var text_label: RichTextLabel = $control/DialogPanel/MainVBox/TextScroll/DialogueText
@onready var choices_vbox: VBoxContainer = $control/DialogPanel/MainVBox/ChoicesVBox

var dialogue_data: Dictionary = {}
var current_node: String = ""
var is_open: bool = false

func _ready() -> void:
	add_to_group("dialogue_ui")  # NPCs can find this
	if text_label == null or choices_vbox == null or text_scroll == null:
		push_error("Dialogue UI paths are wrong. Check node names/paths.")
		return

	text_scroll.custom_minimum_size.y = 160  # make sure it shows
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("normal_font_size", 16)
	choices_vbox.add_theme_constant_override("separation", 6)

	root_ctrl.visible = false

func show_dialogue(text: String) -> void:
	text_label.text = text
	await _refresh_text_layout()
	root_ctrl.visible = true
	is_open = true
	emit_signal("opened")

func hide_dialogue() -> void:
	root_ctrl.visible = false
	is_open = false
	emit_signal("closed")

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		hide_dialogue()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		hide_dialogue()
		get_viewport().set_input_as_handled()

func start_dialogue(json_path: String, start_node: String = "Start") -> void:
	var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_error("Could not open: " + json_path)
		return
	var raw_text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dialogue JSON is not a dictionary")
		return

	dialogue_data = parsed as Dictionary

	# Pick a valid starting node
	if dialogue_data.has(start_node):
		current_node = start_node
	else:
		var keys := dialogue_data.keys()
		if keys.size() == 0:
			push_error("Dialogue JSON is empty")
			return
		current_node = str(keys[0])  # fallback to first key

	_show_node(current_node)

	await get_tree().process_frame
	root_ctrl.visible = true
	is_open = true
	emit_signal("opened")

func _show_node(node_name: String) -> void:
	var node: Dictionary = dialogue_data.get(node_name, {}) as Dictionary
	if node.is_empty():
		push_error("Missing node: " + node_name)
		hide_dialogue()
		return

	var line_text: String = str(node.get("text", ""))
	text_label.text = line_text

	await _refresh_text_layout()

	var choices: Array = []
	if node.has("choices") and node["choices"] is Array:
		choices = node["choices"] as Array
	_populate_choices(choices)

func _populate_choices(choices: Array) -> void:
	for c in choices_vbox.get_children():
		c.queue_free()

	for choice in choices:
		var text: String = ""
		var next_node: String = ""

		if choice is Dictionary:
			var ch: Dictionary = choice as Dictionary
			text = str(ch.get("text", ""))
			next_node = str(ch.get("next", ""))
		else:
			text = str(choice)

		_add_choice_button(text, next_node)

func _add_choice_button(text: String, next_node: String) -> void:
	var btn: Button = Button.new()
	btn.text = text
	_style_choice_button(btn)

	var nn: String = next_node
	btn.pressed.connect(func ():
		if nn.is_empty():
			hide_dialogue()
		else:
			current_node = nn
			_show_node(current_node)
	)

	choices_vbox.add_child(btn)

func _style_choice_button(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 14)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb: StyleBox = btn.get_theme_stylebox(style_name, "Button")
		if sb != null:
			var clone: StyleBox = sb.duplicate()
			if clone is StyleBoxFlat:
				var flat := clone as StyleBoxFlat
				flat.content_margin_top = 4
				flat.content_margin_bottom = 4
			btn.add_theme_stylebox_override(style_name, clone)

# Make sure label actually shows
func _refresh_text_layout() -> void:
	await get_tree().process_frame
	var h: int = text_label.get_content_height()
	if h < 1:
		h = 1
	text_label.custom_minimum_size.y = h
	text_scroll.scroll_vertical = 0
