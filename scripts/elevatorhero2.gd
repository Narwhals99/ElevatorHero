extends CharacterBody2D

@export var speed: float = 120.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var controls_locked := false
@onready var db := get_tree().root.find_child("dialoguebox", true, false)  # finds DialogueBox anywhere

var last_dir := "down"  # Tracks last facing direction
var attacking := false

func _ready() -> void:
	# If DialogueBox exists, hook its signals so we can lock/unlock movement
	if db:
		if not db.opened.is_connected(_on_dialogue_opened):
			db.opened.connect(_on_dialogue_opened)
		if not db.closed.is_connected(_on_dialogue_closed):
			db.closed.connect(_on_dialogue_closed)
	else:
		# In case the DialogueBox is added a bit later in the tree
		call_deferred("_late_bind_dialoguebox")

func _late_bind_dialoguebox() -> void:
	db = get_tree().root.find_child("dialoguebox", true, false)
	if db:
		if not db.opened.is_connected(_on_dialogue_opened):
			db.opened.connect(_on_dialogue_opened)
		if not db.closed.is_connected(_on_dialogue_closed):
			db.closed.connect(_on_dialogue_closed)

func _on_dialogue_opened() -> void:
	controls_locked = true
	attacking = false
	velocity = Vector2.ZERO
	if anim:
		anim.play("idle_" + last_dir)

func _on_dialogue_closed() -> void:
	controls_locked = false

func _physics_process(delta: float) -> void:
	# Hard stop while in dialogue
	if controls_locked:
		attacking = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Finish attack state if animation ended
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
