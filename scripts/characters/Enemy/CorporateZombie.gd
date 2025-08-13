extends CharacterBody2D

@export var max_health: int = 8
@export var speed: float = 70.0
@export var touch_damage: int = 1
@export var knockback: float = 120.0

var health: int
var target: Node2D = null

@onready var aggro: Area2D = $AggroArea
@onready var anim: AnimatedSprite2D = $Visuals/AnimatedSprite2D
@onready var agent: NavigationAgent2D = $agent

func _ready() -> void:
	health = max_health

	if not aggro:
		push_error("AggroArea missing from scene!")
		return
	if not anim:
		push_warning("AnimatedSprite2D missing; animations won't play.")

	if not aggro.body_entered.is_connected(_on_aggro_entered):
		aggro.body_entered.connect(_on_aggro_entered)
	if not aggro.body_exited.is_connected(_on_aggro_exited):
		aggro.body_exited.connect(_on_aggro_exited)

func _physics_process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		if anim: anim.play("idle")
		move_and_slide()
		return

	var dir := Vector2.ZERO

	if agent:
		agent.target_position = target.global_position
		var next := agent.get_next_path_position()
		if next != Vector2.ZERO:
			dir = global_position.direction_to(next)
		else:
			dir = global_position.direction_to(target.global_position)
	else:
		dir = global_position.direction_to(target.global_position)

	velocity = dir * speed
	move_and_slide()

	if anim:
		if velocity.length() > 0.1:
			anim.play("walk")
			anim.flip_h = velocity.x < 0
		else:
			anim.play("idle")

func take_damage(amount: int, from: Vector2) -> void:
	health = max(health - amount, 0)
	velocity += (global_position - from).normalized() * knockback
	if health == 0:
		die()

func die() -> void:
	queue_free()

func _on_aggro_entered(body: Node) -> void:
	if body.is_in_group("player") and body is Node2D:
		target = body

func _on_aggro_exited(body: Node) -> void:
	if body == target:
		target = null

func _draw() -> void:
	if agent and not agent.is_navigation_finished():
		var path_points = agent.get_current_navigation_path()
		if path_points.size() > 1:
			for i in range(path_points.size() - 1):
				draw_line(
				to_local(path_points[i]),
				to_local(path_points[i + 1]),
				Color(1, 0, 0), # red
				2.0
				)
