extends GoblinBase

## Goblin Normal: Muito rápido (speed = 130), vida baixa (25 HP).
## Persegue o alvo diretamente e golpeia corpo a corpo.

const ATTACK_RANGE: float = 55.0
const ATTACK_COOLDOWN: float = 0.95

func _init() -> void:
	base_max_health = 25
	base_speed = 130.0
	base_damage = 8
	goblin_type_name = "normal"

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_avoidance_timer(delta)

	if not is_instance_valid(current_target) or ("is_dead" in current_target and current_target.is_dead):
		current_target = _find_target()

	if not is_instance_valid(current_target):
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		return

	var dist := global_position.distance_to(current_target.global_position)
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
		velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		move_and_slide()
		var dir := (current_target.global_position - global_position).normalized()
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

	if is_inside_tree():
		var timer := get_tree().create_timer(ATTACK_COOLDOWN, false)
		timer.timeout.connect(func(): can_attack = true)
	else:
		can_attack = true
