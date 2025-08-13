extends CharacterBody2D
# Godot 4.x

# ---- Tunables ----
@export var speed: float = 70.0
@export var stop_distance: float = 25.0
@export var sprite_path: NodePath            # leave empty if your sprite is named "AnimatedSprite2D"
@export var repath_interval: float = 0.2
@export var attack_cooldown_time: float = 0.25   # small lockout after each attack

# ---- Nodes / state ----
@onready var agent: NavigationAgent2D = $agent
@onready var aggro_area: Area2D = $AggroArea
@onready var sprite: AnimatedSprite2D = null
@onready var attack_hitbox: Area2D = $AttackHitbox	# NEW: hitbox node reference
@onready var level_root := get_tree().current_scene	# NEW: playground root to listen for respawns

const CORNER_EPS := 2.0

var _repath_accum := 0.0
var aggro := false
var player: Node2D = null

var is_attacking := false
var is_dead := false
var hurt_lock := false
var attack_cooldown := 0.0
var hit_this_swing := false	# NEW: to prevent multiple hits per swing
var _swing_id := 0			# NEW: increments each attack to tag the swing

func _ready() -> void:
	agent.target_desired_distance = stop_distance

	# Resolve sprite once, honoring sprite_path if provided
	if sprite_path != NodePath(""):
		sprite = get_node_or_null(sprite_path)
	if sprite == null:
		sprite = get_node_or_null("Visuals/AnimatedSprite2D")
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D")

	# Force attack to be non-looping (defensive)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.sprite_frames.set_animation_loop("attack", false)

	# Find the player once; we won't chase until aggro == true
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		var by_name := get_tree().get_root().find_child("player", true, false)
		if by_name is Node2D:
			player = by_name

	# Connect aggro signals (avoid duplicate connects)
	if aggro_area and not aggro_area.body_entered.is_connected(_on_aggro_enter):
		aggro_area.body_entered.connect(_on_aggro_enter)
	if aggro_area and not aggro_area.body_exited.is_connected(_on_aggro_exit):
		aggro_area.body_exited.connect(_on_aggro_exit)
	if aggro_area:
		aggro_area.monitoring = true	# NEW: ensure overlap queries work

	# Connect attack hitbox signals (avoid duplicates)
	if attack_hitbox and not attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered):
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	attack_hitbox.monitoring = false	# Off until swing moment
	if attack_hitbox and not attack_hitbox.is_in_group("enemy_attack"):
		attack_hitbox.add_to_group("enemy_attack")	# NEW: so player Hurtbox can recognize it
	attack_hitbox.set_meta("damage", 1)			# NEW: optional, lets player read damage
	attack_hitbox.set_meta("active", false)		# NEW: only true during swing
	attack_hitbox.set_meta("swing_id", _swing_id)	# NEW: initialize tag

	# Listen for respawned players from playground
	if level_root and level_root.has_signal("player_spawned") and not level_root.player_spawned.is_connected(_on_player_spawned):
		level_root.player_spawned.connect(_on_player_spawned)	# NEW

	_play("idle")
	
	add_to_group("enemies")	# NEW: for group broadcast from playground

func _on_player_spawned(p: Node2D) -> void:	# NEW
	player = p
	aggro = false
	agent.target_position = p.global_position
	_repath_accum = repath_interval
	_force_aggro_check()	# NEW: immediately re-arm aggro if already overlapping

func _on_aggro_enter(body: Node) -> void:
	if is_dead:
		return
	if body == player or body.is_in_group("player"):
		aggro = true

func _on_aggro_exit(body: Node) -> void:
	if is_dead:
		return
	if body == player or body.is_in_group("player"):
		aggro = false
		agent.target_position = global_position
		velocity = Vector2.ZERO
		_play("idle")

func _physics_process(delta: float) -> void:
	# Timers
	if attack_cooldown > 0.0:
		attack_cooldown -= delta

	# Lockouts
	if is_dead or hurt_lock:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Reacquire player if we lost the reference (e.g., after respawn/scene swap)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		# when re-grabbing, force a repath right away
		if is_instance_valid(player):
			agent.target_position = player.global_position
			_repath_accum = repath_interval

	# Safety: if we're not attacking, the hitbox must be cold
	if not is_attacking and attack_hitbox and attack_hitbox.monitoring:
		attack_hitbox.monitoring = false
		attack_hitbox.set_meta("active", false)	# NEW

	# If we have a player and our AggroArea overlaps them, force aggro = true
	if not aggro and aggro_area and is_instance_valid(player):
		var bodies := aggro_area.get_overlapping_bodies()
		if bodies and bodies.has(player):
			aggro = true

	# Attack state — keep position and fail-safe exit if anim stopped (non-loop)
	if is_attacking:
		agent.target_position = global_position
		velocity = Vector2.ZERO
		if sprite:
			if not sprite.is_playing():
				# Shouldn't happen (we one-shot), but unstick if it does
				is_attacking = false
				attack_hitbox.monitoring = false
				attack_hitbox.set_meta("active", false)	# NEW
		move_and_slide()
		return

	var dir := Vector2.ZERO

	if aggro and is_instance_valid(player):
		_repath_accum += delta
		# Repath on cadence
		if _repath_accum >= repath_interval:
			agent.target_position = player.global_position
			_repath_accum = 0.0

		if not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			var to_next := next - global_position
			if to_next.length() > CORNER_EPS:
				dir = to_next.normalized()
	else:
		# idle: keep target on self so agent doesn't wander
		agent.target_position = global_position

	# --- Attack gate (stricter + cooldown) ---
	if aggro and is_instance_valid(player) and attack_cooldown <= 0.0:
		var dist_to_player := global_position.distance_to(player.global_position)
		var ready_to_attack: bool = agent.is_navigation_finished() and dist_to_player <= stop_distance
		if ready_to_attack:
			agent.target_position = global_position
			is_attacking = true
			hit_this_swing = false
			attack_cooldown = attack_cooldown_time
			velocity = Vector2.ZERO

			if sprite:
				if sprite.animation != "attack" or not sprite.is_playing():
					sprite.play("attack")
					sprite.frame = 0
					sprite.speed_scale = 1.0
				if not sprite.animation_finished.is_connected(_on_attack_finished):
					sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)

			# Enable hitbox at attack start
			_swing_id += 1									# NEW
			attack_hitbox.set_meta("swing_id", _swing_id)	# NEW
			attack_hitbox.monitoring = true
			attack_hitbox.set_meta("active", true)			# NEW

			move_and_slide()
			return

	# --- Move & animate ---
	velocity = dir * speed
	move_and_slide()

	if dir.length_squared() > 0.0001:
		_play("walk")
		if sprite:
			sprite.flip_h = dir.x < 0
	else:
		_play("idle")

func _on_attack_finished() -> void:
	is_attacking = false
	attack_hitbox.monitoring = false	# disable hitbox after swing
	attack_hitbox.set_meta("active", false)	# NEW
	if is_instance_valid(player):
		agent.target_position = player.global_position
	_repath_accum = repath_interval

# ---- NEW: Attack hitbox collision ----
func _on_attack_hitbox_body_entered(body: Node) -> void:
	if is_dead or not is_attacking:
		return
	if not hit_this_swing and (body == player or body.is_in_group("player")):
		if "take_damage" in body:
			body.take_damage(1)	# damage player
		hit_this_swing = true

# ---- Combat-ish hooks ----
func start_attack() -> void:
	if is_dead or hurt_lock:
		return
	is_attacking = true
	hit_this_swing = false
	attack_cooldown = attack_cooldown_time
	# Enable hitbox and tag swing here too (if you call start_attack() directly)
	_swing_id += 1									# NEW
	attack_hitbox.set_meta("swing_id", _swing_id)	# NEW
	attack_hitbox.monitoring = true
	attack_hitbox.set_meta("active", true)			# NEW
	_play("attack")
	if sprite and not sprite.animation_finished.is_connected(_on_attack_finished):
		sprite.animation_finished.connect(_on_attack_finished, CONNECT_ONE_SHOT)

func take_damage(amount: int) -> void:
	if is_dead:
		return
	_play("hurt")
	hurt_lock = true
	if sprite and not sprite.animation_finished.is_connected(_on_hurt_finished):
		sprite.animation_finished.connect(_on_hurt_finished, CONNECT_ONE_SHOT)

func _on_hurt_finished() -> void:
	hurt_lock = false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	agent.target_position = global_position
	attack_hitbox.monitoring = false	# disable hitbox on death
	attack_hitbox.set_meta("active", false)	# NEW
	_play("dead")
	if sprite and not sprite.animation_finished.is_connected(_on_dead_anim_finished):
		sprite.animation_finished.connect(_on_dead_anim_finished, CONNECT_ONE_SHOT)

func _on_dead_anim_finished() -> void:
	queue_free()

func _play(anim: String) -> void:
	if not sprite:
		push_warning("[Enemy] sprite is NULL. Set `sprite_path` to your AnimatedSprite2D.")
		return
	if not sprite.sprite_frames:
		push_warning("[Enemy] sprite has no SpriteFrames resource.")
		return
	if not sprite.sprite_frames.has_animation(anim):
		push_warning("[Enemy] missing animation: '%s' (falling back to 'idle')" % anim)
		if sprite.sprite_frames.has_animation("idle"):
			if sprite.animation != "idle" or not sprite.is_playing():
				sprite.play("idle")
		return

	var frames: int = sprite.sprite_frames.get_frame_count(anim)
	var is_looping: bool = sprite.sprite_frames.get_animation_loop(anim)
	var fps: float = sprite.sprite_frames.get_animation_speed(anim)

	if frames <= 1:
		push_warning("[Enemy] animation '%s' has %d frame(s) -> will look like sliding." % [anim, frames])
	if anim in ["walk","idle"] and not is_looping:
		push_warning("[Enemy] '%s' is not set to loop; set it to Loop in the editor." % anim)

	if sprite.animation != anim or not sprite.is_playing():
		print("[Enemy] play -> ", anim)
		sprite.play(anim)
		sprite.speed_scale = 1.0

# --- NEW: explicit respawn callback used by call_group("enemies", ...)
func on_player_respawned(p: Node2D) -> void:
	player = p
	aggro = false
	agent.target_position = p.global_position
	_repath_accum = 0.0
	_force_aggro_check()	# NEW

# --- NEW: helper to re-arm aggro when player is already inside the area or close
func _force_aggro_check() -> void:
	if not is_instance_valid(player):
		return
	if aggro_area and aggro_area.monitoring:
		var bodies := aggro_area.get_overlapping_bodies()
		if bodies and bodies.has(player):
			aggro = true
			return
	# distance fallback
	if global_position.distance_to(player.global_position) <= stop_distance * 3.0:
		aggro = true
