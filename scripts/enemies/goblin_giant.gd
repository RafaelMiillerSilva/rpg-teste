extends GoblinBase

## Goblin Giant (Gigante Mini-Boss):
## Vida colossal e passos pesados com screen shake suave.
## Possui 2 goblins nas costas que disparam dardos rápidos continuamente enquanto caminha.
## Ao se aproximar de qualquer herói, desfere golpe esmagador no chão (área circular de 120px)
## com cooldown de 3.0s, causando alto dano em área.

const GOBLIN_DART_SCENE: PackedScene = preload("res://scenes/enemies/goblin_dart.tscn")
const DUST_SCENE: PackedScene = preload("res://scenes/dust_effect.tscn")
const SMASH_RANGE: float = 125.0
const SMASH_AREA_RADIUS: float = 160.0
const SMASH_COOLDOWN: float = 3.0
const DART_COOLDOWN: float = 1.2

var _smash_cooldown_timer: float = 1.5
var _dart_timer: float = 0.8
var _step_shake_timer: float = 0.35

func _init() -> void:
	base_max_health = 400
	base_damage = 39
	base_speed = 87.5
	base_armor = 4
	goblin_type_name = "giant"


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_avoidance_timer(delta)

	_smash_cooldown_timer -= delta
	_dart_timer -= delta

	if not is_instance_valid(current_target) or ("is_dead" in current_target and current_target.is_dead):
		current_target = _find_target()

	if not is_instance_valid(current_target):
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		return

	var dist := global_position.distance_to(current_target.global_position)
	var smart_dir := calculate_smart_direction(current_target.global_position)

	if animated_sprite and abs(smart_dir.x) > 0.05:
		animated_sprite.flip_h = smart_dir.x < 0.0

	# 1. Disparo contínuo dos 2 goblins nas costas enquanto caminha
	if _dart_timer <= 0.0 and dist <= 500.0:
		_dart_timer = DART_COOLDOWN
		_shoot_back_mounted_darts(current_target)

	# 2. Movimentação e Ataque Esmagador (Smash)
	if dist > SMASH_RANGE:
		if not is_attacking:
			apply_smart_movement(smart_dir, delta, speed)
			if animated_sprite:
				if animated_sprite.animation != "run" and animated_sprite.animation != "run_shot":
					animated_sprite.play("run")

			# Passos pesados geram screen shake suave
			_step_shake_timer -= delta
			if _step_shake_timer <= 0.0:
				_step_shake_timer = 0.45
				_apply_step_shake()
			check_player_collisions(func(_target):
				if _smash_cooldown_timer <= 0.0 and not is_attacking:
					_perform_smash_attack()
			)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		if _smash_cooldown_timer <= 0.0 and not is_attacking:
			_perform_smash_attack()

func _shoot_back_mounted_darts(target: Node2D) -> void:
	if not is_inside_tree() or not is_instance_valid(target) or not GOBLIN_DART_SCENE:
		return
	# Dispara 2 dardos rápidos
	for offset_pos in [Vector2(-20, -50), Vector2(20, -50)]:
		var dart = GOBLIN_DART_SCENE.instantiate()
		dart.global_position = global_position + offset_pos
		var spread_angle := randf_range(-0.15, 0.15)
		var base_dir: Vector2 = (target.global_position - dart.global_position).normalized()
		dart.direction = base_dir.rotated(spread_angle)
		dart.damage = 10
		dart.speed = 360.0 # Dardo rápido
		dart.shooter = self
		get_parent().call_deferred("add_child", dart)

func _perform_smash_attack() -> void:
	is_attacking = true
	_smash_cooldown_timer = SMASH_COOLDOWN
	SoundManager.play_slash()

	if animated_sprite:
		animated_sprite.play("smash")

	if is_inside_tree():
		var timer := get_tree().create_timer(0.35, false)
		timer.timeout.connect(func():
			if is_dead:
				return
			_execute_smash_impact()
		)

		# Failsafe para destravar após o smash (6 frames a 10 FPS = 0.60s)
		var finish_timer := get_tree().create_timer(0.65, false)
		finish_timer.timeout.connect(func():
			if is_attacking and not is_dead:
				_finish_smash()
		)

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "smash":
		_finish_smash()
	else:
		super._on_animation_finished()

func _finish_smash() -> void:
	is_attacking = false
	if animated_sprite and animated_sprite.animation == "smash":
		animated_sprite.play("idle")

func _execute_smash_impact() -> void:
	# Impacto estrondoso com Screen Shake
	_apply_screen_shake(7.0, 0.35)
	SoundManager.play_hit()

	# Spawna nuvens de poeira (dust) ao redor do impacto
	_spawn_smash_dust_ring()

	# Aplica dano alto em área circular a todos os heróis e aplica Stun por 1s
	var victims: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
		if global_position.distance_to(player.global_position) <= SMASH_AREA_RADIUS:
			victims.append(player)

	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			if global_position.distance_to(ally.global_position) <= SMASH_AREA_RADIUS:
				victims.append(ally as Node2D)

	for victim in victims:
		var knock_dir := (victim.global_position - global_position).normalized()
		if victim.has_method("take_damage"):
			victim.take_damage(damage, knock_dir * 1.6, self)
		if victim.has_method("apply_stun"):
			victim.apply_stun(1.0)

func _spawn_smash_dust_ring() -> void:
	if not is_inside_tree() or not DUST_SCENE:
		return
	var parent_node := get_parent()
	if not parent_node:
		return

	var facing_sign := -1.0 if (animated_sprite and animated_sprite.flip_h) else 1.0
	var impact_center := global_position + Vector2(facing_sign * 35.0, 30.0)
	var count := 8
	for i in range(count):
		var angle := (float(i) / float(count)) * TAU + randf_range(-0.2, 0.2)
		var dist := randf_range(40.0, 80.0)
		var dust := DUST_SCENE.instantiate() as Node2D
		dust.global_position = impact_center + Vector2(cos(angle), sin(angle)) * dist
		dust.scale = Vector2.ONE * randf_range(0.9, 1.3)
		parent_node.call_deferred("add_child", dust)


func _apply_step_shake() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	var dist := global_position.distance_to(player.global_position)
	if dist < 650.0:
		var intensity := (1.0 - (dist / 650.0)) * 2.2
		_apply_screen_shake(intensity, 0.15)

func _apply_screen_shake(intensity: float, duration: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if not is_instance_valid(camera):
		return

	var tween := camera.create_tween()
	var shake_offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	tween.tween_property(camera, "offset", shake_offset, duration * 0.5)
	tween.tween_property(camera, "offset", Vector2.ZERO, duration * 0.5)

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, attacker: Node = null) -> void:
	# O Gigante colossal possui massa pesada e estabilidade maciça: quase imune a empurrões de golpes normais
	super.take_damage(amount, knockback_dir * 0.1, attacker)

