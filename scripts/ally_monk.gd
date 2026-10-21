extends CharacterBody2D

const UpgradeManager = preload("res://scripts/upgrade_manager.gd")
const STUN_EFFECT_SCENE: PackedScene = preload("res://scenes/stun_effect.tscn")

## Unidade Móvel Aliada: Monge Curandeiro.
## Prioriza a cura da unidade mais ferida (menor porcentagem de vida) no raio de 350px a cada 5s.

signal health_updated(current: int, max_val: int)
signal died(ally_node: Node2D, unit_name: String)

@export var unit_display_name: String = "Monk"
@export var base_max_health: int = 260
@export var base_armor: int = 1
@export var base_speed: float = 190.0
@export var heal_range: float = 350.0
@export var heal_amount: int = 20

var max_health: int = 260
var current_health: int = 260
var armor: int = 1

var is_dead: bool = false
var is_healing: bool = false
var is_stunned: bool = false
var _stun_timer: float = 0.0
var _stun_effect_instance: Node2D = null
var heal_cooldown_timer: float = 0.0
const HEAL_INTERVAL: float = 5.0

## Sistema Anti-Bugs / Anti-Travamento (Detecção de 5s travado andando sem sair da posição)
var _stuck_timer: float = 0.0
var _stuck_check_pos: Vector2 = Vector2.ZERO
var _stuck_interval_timer: float = 0.0
var _is_reversing: bool = false
var _reverse_timer: float = 0.0
var _reverse_direction: Vector2 = Vector2.ZERO
var _bypass_direction: Vector2 = Vector2.ZERO
var _bypass_timer: float = 0.0
var _is_trying_to_move: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var armor_label: Label = $ArmorLabel if has_node("ArmorLabel") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("allies")
	add_to_group("allies_range")
	collision_layer = 4
	collision_mask = 1
	y_sort_enabled = true
	_stuck_check_pos = global_position

	_update_stats_from_upgrades()
	current_health = max_health

	if UpgradeManager.upgrades_changed.is_connected(_on_upgrades_changed) == false:
		UpgradeManager.upgrades_changed.connect(_on_upgrades_changed)

	_setup_health_bar()
	_setup_armor_label()

	if animated_sprite:
		animated_sprite.play("idle")
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

func _setup_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func _setup_armor_label() -> void:
	if not armor_label:
		if has_node("ArmorLabel"):
			armor_label = $ArmorLabel as Label
		else:
			armor_label = Label.new()
			armor_label.name = "ArmorLabel"
			armor_label.z_index = 10
			armor_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			armor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			armor_label.offset_left = -24.0
			armor_label.offset_top = -47.0
			armor_label.offset_right = 24.0
			armor_label.offset_bottom = -33.0
			armor_label.add_theme_font_size_override("font_size", 10)
			armor_label.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0, 1.0))
			armor_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
			armor_label.add_theme_constant_override("shadow_offset_x", 1)
			armor_label.add_theme_constant_override("shadow_offset_y", 1)
			armor_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
			armor_label.add_theme_constant_override("outline_size", 2)
			add_child(armor_label)
	_update_armor_label()

func _update_armor_label() -> void:
	if armor_label:
		armor_label.text = "🛡️ %d" % get_total_armor()

func _on_upgrades_changed() -> void:
	var old_max := max_health
	_update_stats_from_upgrades()
	var diff := max_health - old_max
	if diff > 0:
		current_health = mini(max_health, current_health + diff)
	_update_health_bar()
	_update_armor_label()

func _update_stats_from_upgrades() -> void:
	max_health = base_max_health + UpgradeManager.get_bonus_health()
	armor = base_armor + UpgradeManager.get_bonus_armor()

func get_total_armor() -> int:
	return armor

func get_total_heal_amount() -> int:
	return heal_amount + UpgradeManager.get_monk_bonus_heal()

func get_total_heal_range() -> float:
	return heal_range + UpgradeManager.get_monk_bonus_range()

## Retorna a quantidade total de alvos curados simultaneamente pelo monge (1 base + upgrades)
func get_total_heal_targets() -> int:
	return 1 + UpgradeManager.get_monk_bonus_targets()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_stunned:
		_stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		if _stun_timer <= 0.0:
			is_stunned = false
		return

	# Sistema Anti-Bugs: recuo de desengasgo (andar para trás se travado por 5s)
	if _is_reversing:
		_reverse_timer -= delta
		velocity = velocity.move_toward(_reverse_direction * (base_speed * 0.95), 650.0 * delta)
		move_and_slide()
		if animated_sprite:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
			if abs(_reverse_direction.x) > 0.05:
				animated_sprite.flip_h = _reverse_direction.x < 0.0
		if _reverse_timer <= 0.0:
			_is_reversing = false
			_apply_route_recalculation()
		return

	# Atualiza o temporizador de contorno de rota recalculada
	if _bypass_timer > 0.0:
		_bypass_timer -= delta
		if _bypass_timer <= 0.0:
			_bypass_direction = Vector2.ZERO

	_is_trying_to_move = false

	# Temporizador de cura prioritária (a cada 5 segundos)
	heal_cooldown_timer -= delta
	if heal_cooldown_timer <= 0.0 and not is_healing:
		_try_priority_heal()

	if is_healing:
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		_update_stuck_detector(delta, false)
		return

	var king := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var dist_to_king: float = global_position.distance_to(king.global_position) if is_instance_valid(king) else 0.0

	var is_low_health: bool = (current_health < int(round(float(max_health) * 0.25)))
	var king_too_far: bool = is_instance_valid(king) and (dist_to_king > 280.0)

	# Se a vida estiver abaixo de 25% OU se o Rei se distanciou muito, prioriza voltar/recuar para o círculo do Rei
	if is_instance_valid(king) and (is_low_health or king_too_far):
		_move_in_formation(king, delta, true if king_too_far else false)
		_update_stuck_detector(delta, _is_trying_to_move)
		return

	# Prioridade de socorro: correr em direção a tropas com menos de 40% de vida que estejam fora do alcance de cura
	var urgent_target := _find_urgent_ally_outside_range()
	if is_instance_valid(urgent_target):
		var dir := (urgent_target.global_position - global_position).normalized()
		if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
			dir = (dir * 0.45 + _bypass_direction * 0.75).normalized()
		var run_speed: float = base_speed * 1.35
		velocity = velocity.move_toward(dir * run_speed, 650.0 * delta)
		move_and_slide()
		if animated_sprite:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
			if abs(dir.x) > 0.05:
				animated_sprite.flip_h = dir.x < 0.0
		_is_trying_to_move = true
		_update_stuck_detector(delta, _is_trying_to_move)
		return

	if is_instance_valid(king):
		_move_in_formation(king, delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	_update_stuck_detector(delta, _is_trying_to_move)

## Encontra um aliado vivo com menos de 40% de vida que esteja além do raio de cura atual
func _find_urgent_ally_outside_range() -> Node2D:
	var tree := get_tree()
	if not tree:
		return null

	var candidates: Array[Dictionary] = []
	var check_node = func(node: Node2D):
		if not is_instance_valid(node) or node.get("is_dead") == true or node == self:
			return
		var cur_hp: float = float(node.current_health) if "current_health" in node else 100.0
		var max_hp: float = float(node.max_health) if "max_health" in node else 100.0
		if max_hp <= 0.0:
			return
		var ratio := cur_hp / max_hp
		if ratio > 0.0 and ratio < 0.40:
			var dist := global_position.distance_to(node.global_position)
			if dist > get_total_heal_range():
				candidates.append({
					"target": node,
					"ratio": ratio,
					"dist": dist
				})

	for p in tree.get_nodes_in_group("player"):
		check_node.call(p as Node2D)
	for a in tree.get_nodes_in_group("allies"):
		check_node.call(a as Node2D)

	if candidates.is_empty():
		return null

	# Ordena pelo mais crítico (menor porcentagem de vida)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["ratio"], b["ratio"]):
			return a["dist"] < b["dist"]
		return a["ratio"] < b["ratio"]
	)

	return candidates[0]["target"] as Node2D

## Busca todas as unidades nos grupos "player" e "allies" em até 350px
## e aplica a cura nos aliados com menor porcentagem de vida de acordo com a quantidade permitida por pulso
func _try_priority_heal() -> void:
	var tree := get_tree()
	if not tree:
		return

	var targets: Array[Node2D] = []

	var players := tree.get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.get("is_dead"):
			targets.append(p as Node2D)

	var allies := tree.get_nodes_in_group("allies")
	for a in allies:
		if is_instance_valid(a) and not a.get("is_dead"):
			targets.append(a as Node2D)

	var wounded_candidates: Array[Dictionary] = []

	for t in targets:
		var dist := global_position.distance_to(t.global_position)
		if dist <= get_total_heal_range():
			var cur_hp: float = float(t.current_health) if "current_health" in t else 100.0
			var max_hp: float = float(t.max_health) if "max_health" in t else 100.0

			if cur_hp > 0.0 and cur_hp < max_hp:
				var ratio := cur_hp / max_hp
				wounded_candidates.append({
					"target": t,
					"ratio": ratio
				})

	if wounded_candidates.size() > 0:
		# Ordena por menor proporção de vida primeiro (mais necessitados primeiro)
		wounded_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["ratio"] < b["ratio"]
		)

		var max_targets: int = get_total_heal_targets()
		var chosen_targets: Array[Node2D] = []
		for i in range(mini(max_targets, wounded_candidates.size())):
			chosen_targets.append(wounded_candidates[i]["target"] as Node2D)

		_perform_heal_multi(chosen_targets)
		heal_cooldown_timer = HEAL_INTERVAL
	else:
		# Se ninguém estiver ferido no alcance, verifica novamente após 1 segundo
		heal_cooldown_timer = 1.0

func _perform_heal_multi(targets: Array[Node2D]) -> void:
	if targets.is_empty():
		return

	is_healing = true
	velocity = Vector2.ZERO

	if animated_sprite:
		animated_sprite.play("heal")

	SoundManager.play_heal()

	var amount := get_total_heal_amount()
	for target in targets:
		if not is_instance_valid(target):
			continue
		if target.has_method("heal"):
			target.heal(amount)
		elif "current_health" in target and "max_health" in target:
			target.current_health = mini(target.max_health, target.current_health + amount)

		if target.has_method("trigger_heal_particles"):
			target.trigger_heal_particles()

func _perform_heal(target: Node2D) -> void:
	if is_instance_valid(target):
		_perform_heal_multi([target])

func _move_in_formation(king: CharacterBody2D, delta: float, sprint: bool = false) -> void:
	var allies := get_tree().get_nodes_in_group("allies_range")
	var valid_allies: Array[Node2D] = []
	for a in allies:
		if is_instance_valid(a) and not a.get("is_dead"):
			valid_allies.append(a as Node2D)

	var my_idx := valid_allies.find(self)
	if my_idx == -1:
		my_idx = 0

	var total_range: int = maxi(1, valid_allies.size())
	# Círculo interno (mais próximo do Rei) para tropas Range (Arqueiro e Monge)
	var radius: float = 65.0 + (float(total_range) * 8.0)
	var angle: float = float(my_idx) * (TAU / float(total_range))
	var formation_pos: Vector2 = king.global_position + Vector2(cos(angle), sin(angle)) * radius

	var dist_to_pos: float = global_position.distance_to(formation_pos)

	if dist_to_pos > 20.0:
		var dir := (formation_pos - global_position).normalized()
		if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
			dir = (dir * 0.45 + _bypass_direction * 0.75).normalized()
		var move_speed: float = base_speed * 1.5 if sprint else base_speed
		if dist_to_pos > 160.0 and not sprint:
			move_speed = base_speed * 1.35
		velocity = velocity.move_toward(dir * move_speed, 650.0 * delta)
		move_and_slide()
		if animated_sprite:
			if animated_sprite.animation != "run":
				animated_sprite.play("run")
			if abs(dir.x) > 0.05:
				animated_sprite.flip_h = dir.x < 0.0
		_is_trying_to_move = true
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		_is_trying_to_move = false

## Sistema Anti-Bugs: Detecta se a tropa ficou 5 segundos travada andando sem sair da posição
func _update_stuck_detector(delta: float, is_trying_to_move: bool) -> void:
	if not is_trying_to_move or is_dead or is_stunned or is_healing or _is_reversing:
		_stuck_timer = 0.0
		_stuck_check_pos = global_position
		_stuck_interval_timer = 0.0
		return

	_stuck_interval_timer += delta
	if _stuck_interval_timer >= 0.5:
		var dist_moved: float = global_position.distance_to(_stuck_check_pos)
		if dist_moved < 15.0:
			_stuck_timer += _stuck_interval_timer
		else:
			_stuck_timer = 0.0
			_stuck_check_pos = global_position
		_stuck_interval_timer = 0.0

	if _stuck_timer >= 5.0:
		_trigger_anti_stuck()

## Sistema Anti-Bugs: Ativa o recuo para trás
func _trigger_anti_stuck() -> void:
	_stuck_timer = 0.0
	_stuck_interval_timer = 0.0
	_is_reversing = true
	_reverse_timer = 1.0 # Anda para trás durante 1 segundo

	var backward_dir := -velocity.normalized()
	if backward_dir == Vector2.ZERO:
		var king := get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(king):
			backward_dir = (global_position - king.global_position).normalized()
		else:
			backward_dir = Vector2.DOWN

	var angle_offset: float = randf_range(0.35, 0.75) * (-1.0 if randf() < 0.5 else 1.0)
	_reverse_direction = backward_dir.rotated(angle_offset).normalized()

## Sistema Anti-Bugs: Recalcula a rota contornando lateralmente o obstáculo
func _apply_route_recalculation() -> void:
	var perp := Vector2(-_reverse_direction.y, _reverse_direction.x)
	if randf() < 0.5:
		perp = -perp
	_bypass_direction = perp
	_bypass_timer = 2.0

	_stuck_check_pos = global_position

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "heal":
		is_healing = false
		animated_sprite.play("idle")

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, _attacker = null) -> void:
	if is_dead:
		return

	var final_damage := maxi(1, amount - get_total_armor())
	current_health -= final_damage
	_update_health_bar()
	SoundManager.play_hit()

	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 180.0

	if animated_sprite:
		animated_sprite.modulate = Color(2.0, 1.2, 1.2, 1.0)
		var tw := create_tween()
		if tw:
			tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)

	if current_health <= 0:
		_die()

## Aplica atordoamento (Stun) de 1.0s: bloqueia ações e exibe estrelas sobre a cabeça
func apply_stun(duration: float = 1.0) -> void:
	if is_dead:
		return
	is_stunned = true
	_stun_timer = maxf(_stun_timer, duration)
	is_healing = false
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")

	if is_instance_valid(_stun_effect_instance):
		_stun_effect_instance.refresh_duration(_stun_timer)
	elif STUN_EFFECT_SCENE and is_inside_tree():
		_stun_effect_instance = STUN_EFFECT_SCENE.instantiate() as Node2D
		_stun_effect_instance.setup(self, duration, Vector2(0, -48))
		var parent_node := get_parent()
		if parent_node:
			parent_node.call_deferred("add_child", _stun_effect_instance)

func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = mini(max_health, current_health + amount)
	_update_health_bar()

	if animated_sprite:
		animated_sprite.modulate = Color(1.2, 2.2, 1.2, 1.0)
		var tw := create_tween()
		if tw:
			tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.25)

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	health_updated.emit(current_health, max_health)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self, unit_display_name)
	if is_instance_valid(_stun_effect_instance):
		_stun_effect_instance.queue_free()
	remove_from_group("allies")
	remove_from_group("allies_range")
	set_physics_process(false)

	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var tween := create_tween().set_parallel(true)
	var fall_angle: float = 90.0 if (animated_sprite and animated_sprite.flip_h) else -90.0
	if animated_sprite:
		tween.tween_property(animated_sprite, "rotation_degrees", fall_angle, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.35)
	if health_bar:
		tween.tween_property(health_bar, "modulate:a", 0.0, 0.2)
	if armor_label:
		tween.tween_property(armor_label, "modulate:a", 0.0, 0.2)

	tween.chain().tween_callback(queue_free)
