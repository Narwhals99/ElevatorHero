extends CanvasLayer

# dialoguebox.gd (root = CanvasLayer)
signal opened
signal closed

@onready var box: Control = $control
@onready var dialogue_label: Label = $control/panel/content/dialogue_label
@onready var choices_container: VBoxContainer = $control/panel/content/choices_container
var dialogue_data := {}
var current_node := ""
var is_open := false

func _ready() -> void:
	box.visible = false

func show_dialogue(text: String) -> void:
	dialogue_label.text = text
	box.visible = true
	is_open = true
	emit_signal("opened")

func hide_dialogue() -> void:
	box.visible = false
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
	var f := FileAccess.open(json_path, FileAccess.READ)
	if not f:
		push_error("Could not open: " + json_path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Dialogue JSON is not a dictionary")
		return

	dialogue_data = parsed
	current_node = start_node
	_show_node(current_node)
	is_open = true
	box.visible = true
	emit_signal("opened")

func _show_node(node_name: String) -> void:
	var node = dialogue_data.get(node_name)
	if node == null:
		push_error("Missing node: " + node_name)
		hide_dialogue()
		return

	dialogue_label.text = str(node.get("text", ""))
	_populate_choices(node.get("choices", []))


func _populate_choices(choices: Array) -> void:
	# Clear old buttons
	for child in choices_container.get_children():
		child.queue_free()

	# Build a button per choice
	for choice in choices:
		var btn := Button.new()
		btn.text = str(choice.get("text", ""))
		btn.pressed.connect(func():
			var next_node := str(choice.get("next", ""))
			if next_node.is_empty():
				hide_dialogue()
			else:
				current_node = next_node
				_show_node(current_node)
		)
		choices_container.add_child(btn)

	# Optional: if no choices, you can auto-add a Close button
	# if choices.is_empty():
	# 	var close_btn := Button.new()
	# 	close_btn.text = "Close"
	# 	close_btn.pressed.connect(hide_dialogue)
	# 	choices_container.add_child(close_btn)
