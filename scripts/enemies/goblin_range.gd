extends GoblinBase

## Goblin Range (Atirador): Mantém distância média e dispara projéteis lentos a cada 2.5s.

const GOBLIN_DART_SCENE: PackedScene = preload("res://scenes/enemies/goblin_dart.tscn")
const PREFERRED_MIN_DIST: float = 230.0
const PREFERRED_MAX_DIST: float = 340.0
const SHOOT_COOLDOWN: float = 2.5

var _shoot_timer: float = 1.0 # Primeiro disparo após 1.0s de aproximação

func _init() -> void:
	base_max_health = 12
	base_speed = 100.0
	base_damage = 8
	goblin_type_name = "range"

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Sistema Anti-Bugs / Anti-Travamento de 5s: executa recuo se estiver em reversão
	if _is_reversing:
		apply_smart_movement(Vector2.ZERO, delta, speed)
		return

	update_avoidance_timer(delta)

	_shoot_timer -= delta

	if not is_instance_valid(current_target) or ("is_dead" in current_target and current_target.is_dead):
		current_target = _find_target()

	if not is_instance_valid(current_target):
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		return

	var dist := global_position.distance_to(current_target.global_position)
	var dir := (current_target.global_position - global_position).normalized()
	var smart_dir := calculate_smart_direction(current_target.global_position)

	# Virar sprite para o alvo
	if animated_sprite and abs(dir.x) > 0.05:
		animated_sprite.flip_h = dir.x < 0.0

	# Manutenção de distância média (kiting) com anti-travamento
	if dist < PREFERRED_MIN_DIST:
		# Muito perto dos heróis: recua estrategicamente com prevenção de travamento
		apply_smart_movement(-dir, delta, speed)
	elif dist > PREFERRED_MAX_DIST:
		# Muito longe: avança em direção ao alvo contornando obstáculos
		if not is_attacking:
			apply_smart_movement(smart_dir, delta, speed)
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(smart_dir.x) > 0.05:
					animated_sprite.flip_h = smart_dir.x < 0.0
	else:
		# Em distância ideal de disparo: desacelera e atira
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		_update_stuck_detector(delta, false)
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	# Disparo a cada 2.5s
	if _shoot_timer <= 0.0 and dist <= 420.0 and not is_attacking:
		_shoot_dart(current_target)

func _shoot_dart(target: Node2D) -> void:
	is_attacking = true
	_shoot_timer = SHOOT_COOLDOWN

	if animated_sprite:
		animated_sprite.play("attack")

	# Instancia o dardo no final do frame ou após breve animação
	if is_inside_tree():
		var timer := get_tree().create_timer(0.25, false)
		timer.timeout.connect(func():
			if not is_dead and is_instance_valid(target) and GOBLIN_DART_SCENE:
				var dart = GOBLIN_DART_SCENE.instantiate()
				dart.global_position = global_position + Vector2(0, -10)
				dart.direction = (target.global_position - global_position).normalized()
				dart.damage = damage
				dart.speed = 220.0 # Projétil lento
				dart.shooter = self
				get_parent().add_child(dart)
		)
