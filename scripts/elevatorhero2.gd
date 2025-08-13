extends CharacterBody2D

@export var speed: float = 120.0
@export var debug_respawn: bool = false

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

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()

	# Handle attacking
	if Input.is_action_just_pressed("attack") and not attacking:
		attacking = true
		if anim:
			anim.play("attack_" + last_dir)
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
