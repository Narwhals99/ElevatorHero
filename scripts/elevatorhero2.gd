extends CharacterBody2D

@export var speed: float = 120.0
@export var debug_respawn: bool = false

@export var hb_off_down: Vector2 = Vector2(0, 10)
@export var hb_off_up: Vector2 = Vector2(0, -10)
@export var hb_off_left: Vector2 = Vector2(-10, 0)
@export var hb_off_right: Vector2 = Vector2(10, 0)
@export var hb_rot_down_deg: float = 90.0
@export var hb_rot_up_deg: float = -90.0
@export var hb_rot_left_deg: float = 0.0
@export var hb_rot_right_deg: float = 0.0


@export var body_shape_path: NodePath			# set to your player CollisionShape2D (optional)
@export var hitbox_margin: float = 2.0			# little gap between body and hitbox

@onready var body_shape: CollisionShape2D = (
	get_node_or_null(body_shape_path) if body_shape_path != NodePath("")
	else get_node_or_null("CollisionShape2D")
)
@onready var hb_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D


@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# --- Health / damage ---
@export var max_health: int = 5
@export var i_frames_time: float = 0.35	# brief invulnerability after getting hit
var health: int = 0
var i_frames: float = 0.0
@onready var hurtbox: Area2D = $Hurtbox
# Track last swing we already counted per attack Area2D
var _last_hit_swing_by_area := {}	# area_instance_id -> swing_id

# --- Respawn ---
@export var respawn_i_frames: float = 1.0
var spawn_pos: Vector2

# Optional: which groups count as damaging sources
@export var damaging_groups: Array[String] = ["enemy_attack"]

var controls_locked := false
@onready var db := get_tree().root.find_child("dialoguebox", true, false)	# finds DialogueBox anywhere

var last_dir := "down"	# Tracks last facing direction
var attacking := false

# --- NEW: Player attack -> enemy damage wiring ---
@export var attack_damage: int = 1
@export var attack_knockback: float = 220
@onready var attack_hitbox: Area2D = $AttackHitbox
var _swing_id: int = 0
var _hit_areas := {}     # area_id -> swing_id
var _hit_bodies := {}    # body_id -> swing_id
# -------------------------------------------------

func _ready() -> void:
	# Init health
	health = max_health

	# Ensure we're always in the "player" group (important for enemies re-targeting)
	if not is_in_group("player"):
		add_to_group("player")

	# Fallback spawn; Main.gd will call set_spawn_point() after loading a level
	spawn_pos = global_position

	# If DialogueBox exists, hook its signals so we can lock/unlock movement
	if db:
		if not db.opened.is_connected(_on_dialogue_opened):
			db.opened.connect(_on_dialogue_opened)
		if not db.closed.is_connected(_on_dialogue_closed):
			db.closed.connect(_on_dialogue_closed)
	else:
		# In case the DialogueBox is added a bit later in the tree
		call_deferred("_late_bind_dialoguebox")

	# Hook hurtbox signal
	if hurtbox and not hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# --- AttackHitbox signals (kept OFF by default) ---
	if attack_hitbox:
		attack_hitbox.monitoring = false
		if not attack_hitbox.area_entered.is_connected(_on_attack_area_entered):
			attack_hitbox.area_entered.connect(_on_attack_area_entered)
		if not attack_hitbox.body_entered.is_connected(_on_attack_body_entered):
			attack_hitbox.body_entered.connect(_on_attack_body_entered)
	# --------------------------------------------------

	# Make sure we get an animation_finished callback
	if anim and not anim.animation_finished.is_connected(_on_AnimatedSprite2D_animation_finished):
		anim.animation_finished.connect(_on_AnimatedSprite2D_animation_finished)
		
	if hb_shape:
		hb_shape.position = Vector2.ZERO
		
	if hb_shape:
		hb_shape.rotation = 0.0



func set_spawn_point(world_pos: Vector2) -> void:
	# store the spawn in GLOBAL space
	spawn_pos = world_pos
	if debug_respawn:
		print("[player] set_spawn_point -> ", spawn_pos)

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
	# Tick down invulnerability
	if i_frames > 0.0:
		i_frames -= delta

	# Hard stop while in dialogue
	if controls_locked:
		attacking = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Finish attack state if animation ended
	if attacking and (not anim.is_playing() or not anim.animation.begins_with("attack_")):
		attacking = false
		if attack_hitbox:
			attack_hitbox.monitoring = false	# safety: never leave it on

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()

	# Handle attacking
	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		if anim:
			anim.play("attack_" + last_dir)

		_swing_id += 1
		_hit_areas.clear()
		_hit_bodies.clear()

		if attack_hitbox:
			_set_attack_box_for_dir(last_dir)	# << place/rotate for this swing
			attack_hitbox.monitoring = true

		velocity = Vector2.ZERO
		move_and_slide()
		return

	# If not attacking, handle movement
	if not attacking:
		if input_vector != Vector2.ZERO:
			velocity = input_vector * speed

			# Update last_dir for animations
			if abs(input_vector.x) > abs(input_vector.y):
				last_dir = ("right" if input_vector.x > 0.0 else "left")
			else:
				last_dir = ("down" if input_vector.y > 0.0 else "up")

			if anim:
				anim.play("run_" + last_dir)
		else:
			velocity = Vector2.ZERO
			if anim:
				anim.play("idle_" + last_dir)

	move_and_slide()

func _on_AnimatedSprite2D_animation_finished() -> void:
	# Reset attack state when done
	if anim and anim.animation.begins_with("attack_"):
		attacking = false
		# disable hitbox when the attack ends
		if attack_hitbox:
			attack_hitbox.monitoring = false

func _set_attack_box_for_dir(dir: String) -> void:
	if not attack_hitbox:
		return

	# 1) Choose offset: auto from shapes if available, else manual hb_off_* exports
	var offset: Vector2
	if body_shape and body_shape.shape and hb_shape and hb_shape.shape:
		var offs := _calc_dir_offsets()
		offset = offs.get(dir, Vector2.ZERO) as Vector2
	else:
		match dir:
			"left":
				offset = hb_off_left
			"right":
				offset = hb_off_right
			"up":
				offset = hb_off_up
			_:
				offset = hb_off_down

	# 2) Choose rotation from per-direction exports
	var rot_deg: float
	match dir:
		"left":
			rot_deg = hb_rot_left_deg
		"right":
			rot_deg = hb_rot_right_deg
		"up":
			rot_deg = hb_rot_up_deg
		_:
			rot_deg = hb_rot_down_deg

	attack_hitbox.position = offset
	attack_hitbox.rotation = deg_to_rad(rot_deg)



# --- Hurtbox & damage handling ---
func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Ignore hits while invulnerable
	if i_frames > 0.0:
		return

	# Accept hits only from configured groups
	var is_damaging := false
	for g in damaging_groups:
		if area.is_in_group(g):
			# If it's an enemy attack, it must be active and a NEW swing
			if area.is_in_group("enemy_attack"):
				if not bool(area.get_meta("active", false)):
					return
				var swing_id := int(area.get_meta("swing_id", 0))
				var key := area.get_instance_id()
				if _last_hit_swing_by_area.get(key, -1) == swing_id:
					return	# already took damage from this exact swing
				_last_hit_swing_by_area[key] = swing_id
			is_damaging = true
			break
	if not is_damaging:
		return

	# Optional: let attacks specify damage on the Area2D (default 1)
	var amount := 1
	if area.has_method("get_damage"):
		amount = int(area.get_damage())
	elif area.has_meta("damage"):
		amount = int(area.get_meta("damage"))

	take_damage(amount)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	health = max(0, health - amount)
	i_frames = i_frames_time

	# Simple feedback: snap to a hurt anim if you have one, else flash current
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("hurt_" + last_dir):
		anim.play("hurt_" + last_dir)
	else:
		# quick flash by toggling modulate; replace with your own effect if you want
		if anim:
			anim.modulate = Color(1, 0.6, 0.6)
			await get_tree().create_timer(0.08).timeout
			anim.modulate = Color(1, 1, 1)

	if health <= 0:
		_die()

func _respawn() -> void:
	# Reset stats
	health = max_health
	i_frames = respawn_i_frames

	# Clear per-attack hit memory so first hit after respawn isn't ignored
	_last_hit_swing_by_area.clear()

	# Clear states & movement BEFORE snapping
	controls_locked = false
	attacking = false
	velocity = Vector2.ZERO

	# Snap to exact spawn on the next idle frame so physics won't push us
	set_deferred("global_position", spawn_pos)
	if debug_respawn:
		print("[player] _respawn() -> spawn_pos ", spawn_pos)

	# Visual reset
	if anim:
		anim.modulate = Color(1, 1, 1)
		anim.play("idle_" + last_dir)

	# Tell enemies to reacquire this instance (critical for post-respawn aggro)
	if get_tree():
		get_tree().call_group("enemies", "on_player_respawned", self)

func _die() -> void:
	controls_locked = true
	attacking = false
	velocity = Vector2.ZERO
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("dead_" + last_dir):
		anim.play("dead_" + last_dir)
		await anim.animation_finished
	_respawn()

# --- Attack hitbox callbacks + helper ---
func _on_attack_area_entered(other_area: Area2D) -> void:
	if not attack_hitbox or not attack_hitbox.monitoring:
		return
	var key := other_area.get_instance_id()
	if _hit_areas.get(key, -1) == _swing_id:
		return
	_hit_areas[key] = _swing_id
	_try_damage_target(other_area.get_parent())

func _on_attack_body_entered(body: Node) -> void:
	if not attack_hitbox or not attack_hitbox.monitoring:
		return
	var key := body.get_instance_id()
	if _hit_bodies.get(key, -1) == _swing_id:
		return
	_hit_bodies[key] = _swing_id
	_try_damage_target(body)

func _try_damage_target(target: Node) -> void:
	if not target:
		return
	# never damage self or any players
	if target == self or target.is_in_group("player"):
		return
	# only damage enemies; pass full knockback to them
	if target.is_in_group("enemies") and target.has_method("take_damage"):
		target.take_damage(attack_damage, global_position, attack_knockback)
# ------------------------------------------------

func _calc_dir_offsets() -> Dictionary:
	var body_half_x := 8.0
	var body_half_y := 8.0
	if body_shape and body_shape.shape is RectangleShape2D:
		var bs: RectangleShape2D = body_shape.shape
		body_half_x = bs.size.x * 0.5
		body_half_y = bs.size.y * 0.5

	var hb_half_x := 6.0
	var hb_half_y := 6.0
	if hb_shape and hb_shape.shape is RectangleShape2D:
		var hs: RectangleShape2D = hb_shape.shape
		hb_half_x = hs.size.x * 0.5
		hb_half_y = hs.size.y * 0.5

	# Offset = half of body + half of hitbox + small margin
	return {
		"left":	Vector2(-(body_half_x + hb_half_x + hitbox_margin), 0),
		"right":Vector2( body_half_x + hb_half_x + hitbox_margin, 0),
		"up":	Vector2(0, -(body_half_y + hb_half_y + hitbox_margin)),
		"down":	Vector2(0,  body_half_y + hb_half_y + hitbox_margin)
	}
