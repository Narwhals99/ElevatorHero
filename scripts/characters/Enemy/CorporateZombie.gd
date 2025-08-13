extends CharacterBody2D

# ---- Tunables ----
@export var speed: float = 70.0
@export var stop_distance: float = 8.0
@export var sprite_path: NodePath            # leave empty if your sprite is named "AnimatedSprite2D"
@export var repath_interval: float = 0.2

# ---- Nodes / state ----
@onready var agent: NavigationAgent2D = $agent
@onready var aggro_area: Area2D = $AggroArea
@onready var sprite: AnimatedSprite2D = null

var _repath_accum := 0.0
var aggro := false
var player: Node2D = null
var last_dir := Vector2.DOWN

func _ready() -> void:
	# Resolve sprite node safely
	if sprite_path != NodePath(""):
		sprite = get_node_or_null(sprite_path)
	else:
		sprite = get_node_or_null("AnimatedSprite2D")

	# Find the player once; we won't chase until aggro == true
	var p := get_tree().get_first_node_in_group("player")
	if p:
		player = p
	else:
		var by_name := get_tree().get_root().find_child("player", true, false)
		if by_name is Node2D:
			player = by_name

	# Connect aggro signals (avoid duplicate connects)
	if aggro_area and not aggro_area.body_entered.is_connected(_on_aggro_enter):
		aggro_area.body_entered.connect(_on_aggro_enter)
	if aggro_area and not aggro_area.body_exited.is_connected(_on_aggro_exit):
		aggro_area.body_exited.connect(_on_aggro_exit)

func _on_aggro_enter(body: Node) -> void:
	if body == player or body.is_in_group("player"):
		aggro = true

func _on_aggro_exit(body: Node) -> void:
	if body == player or body.is_in_group("player"):
		aggro = false
		agent.target_position = global_position
		velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO

	if aggro and is_instance_valid(player):
		_repath_accum += delta
		if _repath_accum >= repath_interval:
			agent.target_position = player.global_position
			_repath_accum = 0.0

		if not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			var to_next := next - global_position
			if to_next.length() > stop_distance:
				dir = to_next.normalized()
	else:
		# idle
		agent.target_position = global_position

	velocity = dir * speed
	move_and_slide()
	_update_animation(dir)

func _update_animation(dir: Vector2) -> void:
	if sprite == null:
		return

	if dir.length_squared() > 0.0001:
		last_dir = dir
		sprite.play(_run_anim_for(last_dir))
	else:
		sprite.play(_idle_anim_for(last_dir))

func _run_anim_for(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "run_left" if v.x < 0.0 else "run_right"
	else:
		return "run_up" if v.y < 0.0 else "run_down"

func _idle_anim_for(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "idle_left" if v.x < 0.0 else "idle_right"
	else:
		return "idle_up" if v.y < 0.0 else "idle_down"
