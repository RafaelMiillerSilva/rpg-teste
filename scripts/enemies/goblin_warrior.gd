extends GoblinBase

## Goblin Warrior (com Escudo): Vida e armadura maiores.
## Ao atacar, tem 40% de chance de entrar em postura de guarda ('guard').
## Enquanto estiver em guarda, bloqueia 70% de todo dano físico recebido (dano * 0.3).
## Sai da guarda após receber 1 ataque ou se o alvo morrer.

const ATTACK_RANGE: float = 58.0
const ATTACK_COOLDOWN: float = 1.3
const GUARD_DURATION: float = 2.0

var guard_timer: float = 0.0
var _wants_guard: bool = false

func _init() -> void:
	base_max_health = 81
	base_armor = 3
	base_damage = 18
	base_speed = 125.0
	goblin_type_name = "warrior"

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_avoidance_timer(delta)

	# Se estiver em guarda, sai da guarda após 2s sem ataques ou permanece firme bloqueando
	if is_guarding:
		guard_timer -= delta
		if guard_timer <= 0.0:
			is_guarding = false
			is_attacking = false
			_wants_guard = false
			if animated_sprite and animated_sprite.animation == "guard":
				animated_sprite.play("idle")
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			move_and_slide()
			if is_instance_valid(current_target) and animated_sprite:
				var dir := (current_target.global_position - global_position).normalized()
				if abs(dir.x) > 0.05:
					animated_sprite.flip_h = dir.x < 0.0
			if animated_sprite and animated_sprite.animation != "guard":
				animated_sprite.play("guard")
			return

	if not is_instance_valid(current_target) or ("is_dead" in current_target and current_target.is_dead):
		current_target = _find_target()

	if not is_instance_valid(current_target):
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		return

	var dist := global_position.distance_to(current_target.global_position)
	var dir := (current_target.global_position - global_position).normalized()

	var smart_dir := calculate_smart_direction(current_target.global_position)

	if dist > ATTACK_RANGE:
		if not is_attacking:
			apply_smart_movement(smart_dir, delta, speed)
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(smart_dir.x) > 0.05:
					animated_sprite.flip_h = smart_dir.x < 0.0
			check_player_collisions(_perform_attack)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
		if animated_sprite and abs(dir.x) > 0.05:
			animated_sprite.flip_h = dir.x < 0.0
		if can_attack and not is_attacking:
			_perform_attack(current_target)

func _perform_attack(target: Node2D) -> void:
	is_attacking = true
	can_attack = false
	SoundManager.play_slash()

	if animated_sprite:
		var dir := (target.global_position - global_position).normalized()
		if abs(dir.x) > 0.05:
			animated_sprite.flip_h = dir.x < 0.0
		animated_sprite.play("attack")

	if is_instance_valid(target) and target.has_method("take_damage"):
		var knock_dir := (target.global_position - global_position).normalized()
		target.take_damage(damage, knock_dir, self)

	# 40% de chance de preparar postura de guarda para DEPOIS que o golpe terminar
	_wants_guard = (is_instance_valid(target) and not ("is_dead" in target and target.is_dead) and randf() < 0.40)

	# Failsafe de tempo de ataque (a animação tem 4 frames a 10 FPS = 0.4s)
	if is_inside_tree():
		var attack_finish_timer := get_tree().create_timer(0.45, false)
		attack_finish_timer.timeout.connect(func():
			if is_attacking and not is_dead:
				_finish_attack()
		)

	if is_inside_tree():
		var timer := get_tree().create_timer(ATTACK_COOLDOWN, false)
		timer.timeout.connect(func(): can_attack = true)
	else:
		can_attack = true

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "attack":
		_finish_attack()
	elif animated_sprite and animated_sprite.animation != "guard":
		super._on_animation_finished()

func _finish_attack() -> void:
	is_attacking = false
	if _wants_guard and not is_dead and is_instance_valid(current_target) and not ("is_dead" in current_target and current_target.is_dead):
		_wants_guard = false
		is_guarding = true
		guard_timer = GUARD_DURATION
		if animated_sprite:
			animated_sprite.play("guard")
	else:
		_wants_guard = false
		if animated_sprite and animated_sprite.animation == "attack":
			animated_sprite.play("idle")
