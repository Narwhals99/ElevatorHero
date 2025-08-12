extends CharacterBody2D

@onready var anim = $AnimatedSprite2D  # Change to $AnimatedSprite2D if you use spritesheets

# Movement variables
var speed := 250
var lunge_speed := 400
var is_lunging := false
var lunge_time := 0.2
var lunge_timer := 0.0

func _ready():
	$Camera2D.make_current()

func _process(delta: float) -> void:
	handle_input(delta)
	update_animation()

func handle_input(delta: float) -> void:
	var input_vector = Vector2.ZERO
	
	if not is_lunging:
		input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		input_vector = input_vector.normalized()
		
		velocity = input_vector * speed

		# Attack
		if Input.is_action_just_pressed("attack"):
			anim.play("attack")
			velocity = Vector2.ZERO  # stop movement while attacking

		# Lunge
		elif Input.is_action_just_pressed("lunge"):
			if input_vector != Vector2.ZERO:
				velocity = input_vector * lunge_speed
				is_lunging = true
				lunge_timer = lunge_time
				anim.play("lunge")

	else:
		# During lunge
		lunge_timer -= delta
		if lunge_timer <= 0:
			is_lunging = false
			velocity = Vector2.ZERO

	move_and_slide()

func update_animation() -> void:
	if is_lunging:
		return # Lunge animation overrides others
	if anim.is_playing() and anim.animation in ["attack", "lunge"]:
		return # Don't interrupt attack/lunge animations

	if velocity.length() > 0:
		anim.play("walk")
	else:
		anim.play("idle")
