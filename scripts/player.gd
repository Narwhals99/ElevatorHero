extends CharacterBody2D

@export var speed := 120.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_dir := Vector2.DOWN   # remember facing for idle
var facing_left := false

func _physics_process(_delta: float) -> void:
	# 1) Read input (normalized so diagonals aren't faster)
	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
	).normalized()

	# 2) Move
	velocity = input_vec * speed
	move_and_slide()

	# 3) Pick facing
	if input_vec != Vector2.ZERO:
		last_dir = input_vec

	# 4) Play the right animation
	if input_vec == Vector2.ZERO:
		_play_idle()
	else:
		_play_walk(input_vec)

func _play_walk(dir: Vector2) -> void:
	# Horizontal takes priority if abs(x) >= abs(y)
	if abs(dir.x) >= abs(dir.y):
		sprite.animation = "walk_side"
		_set_flip(dir.x < 0)
	elif dir.y < 0:
		sprite.animation = "walk_up"
		_set_flip(false) # ensure no stray flips on vertical
	else:
		sprite.animation = "walk_down"
		_set_flip(false)

	if not sprite.is_playing():
		sprite.play()

func _play_idle() -> void:
	# Use last_dir to choose which idle to show
	if abs(last_dir.x) >= abs(last_dir.y):
		sprite.animation = "idle"
		_set_flip(last_dir.x < 0)


	# For multi-frame idle, use play(); for 1-frame idle, stop at frame 0:
	if sprite.sprite_frames.get_frame_count(sprite.animation) > 1:
		if not sprite.is_playing():
			sprite.play()
	else:
		sprite.stop()
		sprite.frame = 0

func _set_flip(left: bool) -> void:
	if sprite.flip_h != left:
		sprite.flip_h = left
