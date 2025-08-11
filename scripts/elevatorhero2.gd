extends CharacterBody2D

@export var speed: float = 120.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var last_dir := "down"  # Tracks last facing direction
var attacking := false

func _physics_process(delta: float) -> void:
	if attacking and (!anim.is_playing() or !anim.animation.begins_with("attack_")):
		attacking = false

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()

	# Handle attacking
	if Input.is_action_just_pressed("attack") and !attacking:
		attacking = true
		anim.play("attack_" + last_dir)
		# Optional: prevent movement during attack
		velocity = Vector2.ZERO
		return

	# If not attacking, handle movement
	if !attacking:
		if input_vector != Vector2.ZERO:
			velocity = input_vector * speed

			# Update last_dir for animations
			if abs(input_vector.x) > abs(input_vector.y):
				last_dir = "right" if input_vector.x > 0 else "left"
			else:
				last_dir = "down" if input_vector.y > 0 else "up"

			anim.play("run_" + last_dir)
		else:
			velocity = Vector2.ZERO
			anim.play("idle_" + last_dir)

	move_and_slide()

func _on_AnimatedSprite2D_animation_finished() -> void:
	# Reset attack state when done
	if anim.animation.begins_with("attack_"):
		attacking = false


func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.
