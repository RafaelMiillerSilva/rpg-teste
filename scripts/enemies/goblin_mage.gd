class_name GoblinMage
extends GoblinBase

## Goblin Mage (Mago das Chamas):
## Surge a partir do Turno 25 (2.5% da horda).
## Comportamento padrão de longo alcance (Kiting similar ao arqueiro).
## Lança projétil de bola de fogo a cada 2.0s causando 35 de dano que ignora armadura,
## provoca explosão em área com empurrão e incendeia os alvos por 5s (5 dano/s).

const GOBLIN_FIREBALL_SCENE: PackedScene = preload("res://scenes/enemies/goblin_fireball.tscn")
const PREFERRED_MIN_DIST: float = 230.0
const PREFERRED_MAX_DIST: float = 350.0
const MAX_ATTACK_RANGE: float = 430.0
const SHOOT_COOLDOWN: float = 2.0

var _shoot_timer: float = 1.0 # Primeiro disparo após 1.0s de posicionamento

func _init() -> void:
	base_max_health = 100
	max_health = 100
	current_health = 100
	base_speed = 95.0
	base_damage = 40
	base_armor = 0
	goblin_type_name = "mage"

func _ready() -> void:
	super._ready()
	if animated_sprite:
		animated_sprite.scale = Vector2(1.4, 1.4)

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

	# Orientação horizontal do sprite
	if animated_sprite and abs(dir.x) > 0.05:
		animated_sprite.flip_h = dir.x < 0.0

	# Comportamento padrão de arqueiro / longo alcance (Kiting) com anti-travamento
	if dist < PREFERRED_MIN_DIST:
		# Muito próximo dos heróis: recua estrategicamente com prevenção de travamento
		apply_smart_movement(-dir, delta, speed)
	elif dist > PREFERRED_MAX_DIST:
		# Muito longe: aproxima-se usando navegação inteligente
		if not is_attacking:
			apply_smart_movement(smart_dir, delta, speed)
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(smart_dir.x) > 0.05:
					animated_sprite.flip_h = smart_dir.x < 0.0
	else:
		# Em distância ideal de disparo: desacelera e foca no lançamento da bola de fogo
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		_update_stuck_detector(delta, false)
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	# Disparo a cada 2.0s
	if _shoot_timer <= 0.0 and dist <= MAX_ATTACK_RANGE and not is_attacking:
		_cast_fireball(current_target)

func _cast_fireball(target: Node2D) -> void:
	is_attacking = true
	_shoot_timer = SHOOT_COOLDOWN

	if animated_sprite:
		animated_sprite.play("attack")

	# Dispara a bola de fogo no ápice da invocação
	if is_inside_tree():
		var timer := get_tree().create_timer(0.28, false)
		timer.timeout.connect(func():
			if not is_dead and is_instance_valid(target) and GOBLIN_FIREBALL_SCENE:
				var fireball = GOBLIN_FIREBALL_SCENE.instantiate()
				fireball.global_position = global_position + Vector2(0, -16)
				fireball.direction = (target.global_position - global_position).normalized()
				fireball.damage = damage
				fireball.shooter = self
				var parent_node := get_parent()
				if parent_node:
					parent_node.call_deferred("add_child", fireball)
		)

		# Reseta postura de ataque após a conjuração
		var finish_timer := get_tree().create_timer(0.6, false)
		finish_timer.timeout.connect(func():
			if is_attacking and not is_dead:
				is_attacking = false
				if animated_sprite:
					animated_sprite.play("idle")
		)
