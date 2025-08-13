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
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var level_root := get_tree().current_scene

const CORNER_EPS := 2.0

var _repath_accum := 0.0
var _aggro_scan_accum := 0.0	# NEW: periodic aggro scan
var aggro := false
var player: Node2D = null

var is_attacking := false
var is_dead := false
var hurt_lock := false
var attack_cooldown := 0.0
var hit_this_swing := false
var _swing_id := 0

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

	# Find the player
	_try_get_player()

	# Ensure AggroArea is active
	if aggro_area:
		if not aggro_area.body_entered.is_connected(_on_aggro_enter):
			aggro_area.body_entered.connect(_on_aggro_enter)
		if not aggro_area.body_exited.is_connected(_on_aggro_exit):
			aggro_area.body_exited.connect(_on_aggro_exit)
		aggro_area.monitoring = true

	# Ensure the AggroArea's mask includes the player's layer (bullet-proof)
	_sync_aggro_mask_to_player()	# NEW

	# Attack hitbox setup
	if attack_hitbox and not attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered):
		attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	attack_hitbox.monitoring = false
	if attack_hitbox and not attack_hitbox.is_in_group("enemy_attack"):
		attack_hitbox.add_to_group("enemy_attack")
	attack_hitbox.set_meta("damage", 1)
	attack_hitbox.set_meta("active", false)
	attack_hitbox.set_meta("swing_id", _swing_id)

	# Listen for respawned players from scene (optional) AND via group broadcast
	if level_root and level_root.has_signal("player_spawned") and not level_root.player_spawned.is_connected(_on_player_spawned):
		level_root.player_spawned.connect(_on_player_spawned)

	_play("idle")

	if not is_in_group("enemies"):
		add_to_group("enemies")

func _try_get_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			var by_name := get_tree().get_root().find_child("player", true, false)
			if by_name is Node2D:
				player = by_name
	if is_instance_valid(player):
		print("[CZ] have player:", player.name, " at ", player.global_position)

func _sync_aggro_mask_to_player() -> void:
	if not aggro_area:
		return
	# If player exists and is a physics body, ensure AggroArea can see it
	if is_instance_valid(player) and player is PhysicsBody2D:
		var p_layer := (player as PhysicsBody2D).collision_layer
		if p_layer != 0:
			aggro_area.collision_mask |= p_layer
			print("[CZ] AggroArea mask set to include player layer (mask now): ", aggro_area.collision_mask)

func _on_player_spawned(p: Node2D) -> void:
	print("[CZ] on_player_spawned")
	player = p
	aggro = false
	agent.target_position = p.global_position
	_repath_accum = repath_interval
	_sync_aggro_mask_to_player()	# NEW
	_force_aggro_check()

func _on_aggro_enter(body: Node) -> void:
	if is_dead:
		return
	if body.is_in_group("player"):
		player = body as Node2D			# << ensure we chase the CURRENT instance
		aggro = true
		agent.target_position = player.global_position
		_repath_accum = repath_interval	# << force an immediate repath this frame


func _on_aggro_exit(body: Node) -> void:
	if is_dead:
		return
	if body.is_in_group("player"):
		print("[CZ] aggro exit -> FALSE")
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

	# Reacquire player if lost; also keep mask in sync
	if player == null or not is_instance_valid(player):
		_try_get_player()
		_sync_aggro_mask_to_player()
		if is_instance_valid(player):
			agent.target_position = player.global_position
			_repath_accum = repath_interval

	# Safety: keep hitbox cold when not attacking
	if not is_attacking and attack_hitbox and attack_hitbox.monitoring:
		attack_hitbox.monitoring = false
		attack_hitbox.set_meta("active", false)

	# Periodic aggro wake-up (in case signals didn't fire)
	_aggro_scan_accum += delta
	if _aggro_scan_accum >= 0.2:
		_aggro_scan_accum = 0.0
		_force_aggro_check()

	# Attack lock
	if is_attacking:
		agent.target_position = global_position
		velocity = Vector2.ZERO
		if sprite and not sprite.is_playing():
			is_attacking = false
			attack_hitbox.monitoring = false
			attack_hitbox.set_meta("active", false)
		move_and_slide()
		return

	var dir := Vector2.ZERO

	if aggro and is_instance_valid(player):
		_repath_accum += delta
		if _repath_accum >= repath_interval:
			agent.target_position = player.global_position
			_repath_accum = 0.0

		if not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			var to_next := next - global_position
			if to_next.length() > CORNER_EPS:
				dir = to_next.normalized()
	else:
		agent.target_position = global_position

	# --- Attack gate ---
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

			_swing_id += 1
			attack_hitbox.set_meta("swing_id", _swing_id)
			attack_hitbox.monitoring = true
			attack_hitbox.set_meta("active", true)

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
	attack_hitbox.monitoring = false
	attack_hitbox.set_meta("active", false)
	if is_instance_valid(player):
		agent.target_position = player.global_position
	_repath_accum = repath_interval

func _on_attack_hitbox_body_entered(body: Node) -> void:
	if is_dead or not is_attacking:
		return
	if not hit_this_swing and (body == player or body.is_in_group("player")):
		if "take_damage" in body:
			body.take_damage(1)
		hit_this_swing = true

func start_attack() -> void:
	if is_dead or hurt_lock:
		return
	is_attacking = true
	hit_this_swing = false
	attack_cooldown = attack_cooldown_time
	_swing_id += 1
	attack_hitbox.set_meta("swing_id", _swing_id)
	attack_hitbox.monitoring = true
	attack_hitbox.set_meta("active", true)
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
	attack_hitbox.monitoring = false
	attack_hitbox.set_meta("active", false)
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

func on_player_respawned(p: Node2D) -> void:
	player = p
	is_attacking = false                 # << prevent being stuck in attack lock
	hurt_lock = false
	if attack_hitbox:
		attack_hitbox.monitoring = false
		attack_hitbox.set_meta("active", false)

	# Don’t force aggro=false here; let the checks decide correctly.
	_repath_accum = 0.0
	agent.target_position = p.global_position

	_force_aggro_check()                 # << if you respawn inside the zone, this re-arms aggro


func _force_aggro_check() -> void:
	_try_get_player()
	if not is_instance_valid(player):
		return
	if aggro_area and aggro_area.monitoring:
		var bodies := aggro_area.get_overlapping_bodies()
		if bodies and bodies.has(player):
			if not aggro:
				print("[CZ] force aggro via overlap")
			aggro = true
			return
	# distance fallback
	var wake_dist := stop_distance * 3.0
	if global_position.distance_to(player.global_position) <= wake_dist:
		if not aggro:
			print("[CZ] force aggro via distance")
		aggro = true
