extends GoblinBase

## Goblin Healer (Curandeiro):
## Fica na retaguarda recuada (mantém distância mínima de 300px dos heróis).
## A cada 5 segundos, busca até 5 goblins feridos e cura 15 de vida em cada um.
## Prioridade de cura: Giant > Warrior > Range > Normal.

const MIN_HERO_DISTANCE: float = 300.0
const HEAL_COOLDOWN: float = 5.0
const HEAL_AMOUNT: int = 15

var _heal_timer: float = 3.0 # Primeiro ciclo de cura após 3.0s

func _init() -> void:
	base_max_health = 40
	base_speed = 95.0
	base_damage = 5
	goblin_type_name = "healer"

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_avoidance_timer(delta)

	_heal_timer -= delta

	# 1. Manter distância de segurança de 300px de qualquer herói (Player ou Aliados)
	var hero_threat := _find_closest_hero()
	if is_instance_valid(hero_threat):
		var dist := global_position.distance_to(hero_threat.global_position)
		var dir := (hero_threat.global_position - global_position).normalized()
		var smart_dir := calculate_smart_direction(hero_threat.global_position)

		if animated_sprite and abs(smart_dir.x) > 0.05:
			animated_sprite.flip_h = smart_dir.x < 0.0

		if dist < MIN_HERO_DISTANCE:
			# Muito perto: foge na direção oposta!
			velocity = velocity.move_toward(-dir * speed, 500.0 * delta)
			move_and_slide()
			if animated_sprite and animated_sprite.animation != "run":
				animated_sprite.play("run")
		elif dist > 500.0:
			# Muito longe da batalha: aproxima-se com cautela contornando obstáculos
			apply_smart_movement(smart_dir, delta, speed * 0.7)
			if animated_sprite and animated_sprite.animation != "run":
				animated_sprite.play("run")
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			move_and_slide()
			if animated_sprite and animated_sprite.animation != "idle" and animated_sprite.animation != "heal":
				animated_sprite.play("idle")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		move_and_slide()

	# 2. Ciclo de cura a cada 5 segundos
	if _heal_timer <= 0.0:
		_heal_timer = HEAL_COOLDOWN
		_perform_healing_wave()

func _find_closest_hero() -> Node2D:
	if not is_inside_tree() or not get_tree():
		return null
	var heroes: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
		heroes.append(player)
	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			heroes.append(ally as Node2D)

	var closest: Node2D = null
	var min_d := 999999.0
	for h in heroes:
		var d := global_position.distance_to(h.global_position)
		if d < min_d:
			min_d = d
			closest = h
	return closest

func _perform_healing_wave() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var injured: Array[GoblinBase] = []

	for e in enemies:
		if is_instance_valid(e) and e is GoblinBase and not e.is_dead:
			if e.current_health < e.max_health:
				injured.append(e)

	if injured.is_empty():
		return

	# Prioridade de cura oficial: Giant > Warrior > Range > Normal > Healer
	var priority_order = {
		"giant": 5,
		"warrior": 4,
		"range": 3,
		"normal": 2,
		"healer": 1
	}

	injured.sort_custom(func(a: GoblinBase, b: GoblinBase) -> bool:
		var p_a: int = priority_order.get(a.goblin_type_name, 0)
		var p_b: int = priority_order.get(b.goblin_type_name, 0)
		if p_a != p_b:
			return p_a > p_b # Maior prioridade primeiro
		# Em caso de empate, cura o que tiver menor percentual de vida
		var pct_a: float = float(a.current_health) / float(maxi(1, a.max_health))
		var pct_b: float = float(b.current_health) / float(maxi(1, b.max_health))
		return pct_a < pct_b
	)

	# Cura até 5 goblins feridos
	var targets_to_heal = injured.slice(0, 5)
	if targets_to_heal.is_empty():
		return

	if animated_sprite:
		animated_sprite.play("heal")

	SoundManager.play_heal()

	for target in targets_to_heal:
		if is_instance_valid(target) and not target.is_dead:
			target.heal(HEAL_AMOUNT)
			_spawn_heal_effect(target)

func _spawn_heal_effect(target: Node2D) -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return
	# Efeito visual de brilho de cura sobre o goblin
	var effect := Sprite2D.new()
	effect.texture = preload("res://assets/tiny_swords/Units/Blue Units/Monk/Heal_Effect.png")
	effect.hframes = 11
	effect.frame = 5
	effect.scale = Vector2(0.65, 0.65)
	effect.modulate = Color(0.4, 2.0, 0.6, 0.9)
	target.add_child(effect)
	effect.position = Vector2(0, -15)

	var tween := effect.create_tween()
	tween.tween_property(effect, "position:y", -35.0, 0.6)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.6)
	tween.tween_callback(effect.queue_free)
