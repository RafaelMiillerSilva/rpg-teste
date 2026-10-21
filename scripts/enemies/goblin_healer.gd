extends GoblinBase

## Goblin Healer (Curandeiro):
## Foca em buscar e acompanhar os aliados mais fortes pelo mapa (Rei, Gigante, Mago, Guerreiro),
## mantendo-se na retaguarda deles para curá-los continuamente e desviando ativamente do
## Rei e de seus cavaleiros/tropas aliadas.

const DANGER_RADIUS: float = 240.0
const ALLY_PREFERRED_MIN_DIST: float = 90.0
const ALLY_PREFERRED_MAX_DIST: float = 170.0
const HEAL_RANGE: float = 240.0
const HEAL_COOLDOWN: float = 5.0
const HEAL_AMOUNT: int = 18

var _heal_timer: float = 2.0
var is_healing: bool = false
var focus_ally: GoblinBase = null

func _init() -> void:
	base_max_health = 45
	base_speed = 88.0
	base_damage = 5
	goblin_type_name = "healer"

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_healing:
		velocity = Vector2.ZERO
		return

	update_avoidance_timer(delta)
	_heal_timer -= delta

	# 1. Encontra o aliado mais forte / prioritário para focar
	if not is_instance_valid(focus_ally) or focus_ally.is_dead:
		focus_ally = _find_strongest_goblin_ally()

	# 2. Calcula vetor de desvio do jogador e de seus cavaleiros/aliados
	var repulsion_from_heroes := _calculate_heroes_repulsion()

	# 3. Determina vetor de movimentação em direção ao aliado focado
	var dir_to_ally := Vector2.ZERO
	if is_instance_valid(focus_ally):
		var dist_ally := global_position.distance_to(focus_ally.global_position)
		if dist_ally > ALLY_PREFERRED_MAX_DIST:
			dir_to_ally = calculate_smart_direction(focus_ally.global_position)
		elif dist_ally < ALLY_PREFERRED_MIN_DIST:
			dir_to_ally = (global_position - focus_ally.global_position).normalized()
	else:
		focus_ally = _find_strongest_goblin_ally()

	# 4. Combina navegação: segue o aliado mais forte, mas desvia com alta prioridade se houver heróis por perto
	var move_speed: float = speed
	if repulsion_from_heroes != Vector2.ZERO:
		# Em perigo: desvia ativamente dos cavaleiros/player contornando-os em direção ao aliado
		var blended_dir := (dir_to_ally * 0.35 + repulsion_from_heroes * 0.85).normalized()
		apply_smart_movement(blended_dir, delta, move_speed * 1.15)
		if animated_sprite and animated_sprite.animation != "run":
			animated_sprite.play("run")
		if animated_sprite and abs(blended_dir.x) > 0.05:
			animated_sprite.flip_h = blended_dir.x < 0.0
	elif dir_to_ally != Vector2.ZERO:
		# Caminha pelo mapa acompanhando o aliado forte
		apply_smart_movement(dir_to_ally, delta, move_speed)
		if animated_sprite and animated_sprite.animation != "run":
			animated_sprite.play("run")
		if animated_sprite and abs(dir_to_ally.x) > 0.05:
			animated_sprite.flip_h = dir_to_ally.x < 0.0
	else:
		# Posicionado com segurança atrás do aliado
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		_update_stuck_detector(delta, false)
		if animated_sprite and animated_sprite.animation != "idle" and animated_sprite.animation != "heal":
			animated_sprite.play("idle")

	# 5. Ciclo de cura a cada 5 segundos para aliados no raio de alcance
	if _heal_timer <= 0.0:
		_heal_timer = HEAL_COOLDOWN
		_perform_healing_wave()

## Encontra o aliado goblin mais forte do mapa para acompanhar e priorizar a cura
func _find_strongest_goblin_ally() -> GoblinBase:
	if not is_inside_tree() or not get_tree():
		return null

	var enemies := get_tree().get_nodes_in_group("enemies")
	var best_ally: GoblinBase = null
	var best_score: float = -999999.0

	var strength_weights = {
		"king": 150.0,
		"giant": 100.0,
		"mage": 75.0,
		"warrior": 50.0,
		"range": 25.0,
		"normal": 10.0,
		"healer": 0.0
	}

	for e in enemies:
		if not is_instance_valid(e) or e == self or not (e is GoblinBase) or e.is_dead:
			continue

		var goblin := e as GoblinBase
		var weight: float = strength_weights.get(goblin.goblin_type_name, 10.0)
		var dist: float = global_position.distance_to(goblin.global_position)

		# Pontuação baseada no peso do tipo de goblin
		var score: float = weight * 100.0 - (dist * 0.15)

		# Bônus muito alto se o aliado estiver ferido (necessitando de socorro médico)
		if goblin.current_health < goblin.max_health:
			var missing_pct: float = 1.0 - (float(goblin.current_health) / float(maxi(1, goblin.max_health)))
			score += 350.0 + (missing_pct * 300.0)

		if score > best_score:
			best_score = score
			best_ally = goblin

	return best_ally

## Calcula força de repulsão combinada contra o jogador e seus guerreiros/aliados próximos
func _calculate_heroes_repulsion() -> Vector2:
	if not is_inside_tree() or not get_tree():
		return Vector2.ZERO

	var heroes: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
		heroes.append(player)

	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			heroes.append(ally as Node2D)

	var total_repulsion := Vector2.ZERO
	for hero in heroes:
		var dist := global_position.distance_to(hero.global_position)
		if dist < DANGER_RADIUS:
			var force: float = 1.0 - (dist / DANGER_RADIUS)
			var dir := (global_position - hero.global_position).normalized()
			total_repulsion += dir * force

	return total_repulsion.normalized() if total_repulsion != Vector2.ZERO else Vector2.ZERO

func _perform_healing_wave() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var injured: Array[GoblinBase] = []

	for e in enemies:
		if is_instance_valid(e) and e is GoblinBase and not e.is_dead:
			if global_position.distance_to(e.global_position) <= HEAL_RANGE:
				if e.current_health < e.max_health:
					injured.append(e)

	if injured.is_empty():
		return

	# Prioridade de cura oficial: King > Giant > Mage > Warrior > Range > Normal > Healer
	var priority_order = {
		"king": 6,
		"giant": 5,
		"mage": 4,
		"warrior": 3,
		"range": 2,
		"normal": 1,
		"healer": 0
	}

	injured.sort_custom(func(a: GoblinBase, b: GoblinBase) -> bool:
		var p_a: int = priority_order.get(a.goblin_type_name, 0)
		var p_b: int = priority_order.get(b.goblin_type_name, 0)
		if p_a != p_b:
			return p_a > p_b # Maior força/hierarquia primeiro
		var pct_a: float = float(a.current_health) / float(maxi(1, a.max_health))
		var pct_b: float = float(b.current_health) / float(maxi(1, b.max_health))
		return pct_a < pct_b
	)

	var targets_to_heal = injured.slice(0, 5)
	if targets_to_heal.is_empty():
		return

	is_healing = true
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("heal")

	SoundManager.play_heal()

	for target in targets_to_heal:
		if is_instance_valid(target) and not target.is_dead:
			target.heal(HEAL_AMOUNT)
			_spawn_heal_effect(target)

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "heal":
		is_healing = false
		animated_sprite.play("idle")
	else:
		super._on_animation_finished()

func _spawn_heal_effect(target: Node2D) -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return
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
