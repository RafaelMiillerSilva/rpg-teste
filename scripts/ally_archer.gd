extends CharacterBody2D

const UpgradeManager = preload("res://scripts/upgrade_manager.gd")
const STUN_EFFECT_SCENE: PackedScene = preload("res://scenes/stun_effect.tscn")

## Unidade Móvel Aliada: Arqueiro de Suporte Rápido.
## Dispara flechas precisas à distância e forma círculo defensivo com o esquadrão.

signal health_updated(current: int, max_val: int)
signal died(ally_node: Node2D, unit_name: String)

@export var unit_display_name: String = "Archer"
@export var base_max_health: int = 220
@export var base_armor: int = 1
@export var base_damage: int = 15
@export var base_speed: float = 205.0
@export var attack_range: float = 380.0
@export var min_safe_dist: float = 200.0
@export var arrow_speed: float = 550.0

var max_health: int = 220
var current_health: int = 220
var armor: int = 1

var is_dead: bool = false
var is_shooting: bool = false
var can_shoot: bool = true
var is_stunned: bool = false
var _stun_timer: float = 0.0
var _stun_effect_instance: Node2D = null
var target_enemy: Node2D = null

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

const ARROW_SCENE: PackedScene = preload("res://scenes/arrow.tscn")

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

func get_total_damage() -> int:
	return base_damage + UpgradeManager.get_archer_bonus_damage()

func get_shoot_cooldown() -> float:
	return 0.7 * UpgradeManager.get_archer_cooldown_multiplier()

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

	if is_shooting:
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
		# Se estiver próximo o suficiente do círculo do Rei e can_shoot, pode atirar nos inimigos à vista sem sair do lugar
		if can_shoot and not is_low_health and not king_too_far:
			target_enemy = _find_closest_enemy()
			if is_instance_valid(target_enemy) and global_position.distance_to(target_enemy.global_position) <= attack_range:
				_shoot_at_enemy(target_enemy)
		_update_stuck_detector(delta, _is_trying_to_move)
		return

	target_enemy = _find_closest_enemy()

	if is_instance_valid(target_enemy):
		var dist: float = global_position.distance_to(target_enemy.global_position)
		var dir: Vector2 = (target_enemy.global_position - global_position).normalized()

		if dist < min_safe_dist:
			# Muito perto do inimigo: afasta-se na direção oposta (kiting), mantendo a mira
			var retreat_dir := -dir
			if is_instance_valid(king) and dist_to_king > 180.0:
				# Se o Rei estiver se distanciando, recua em direção ao Rei
				retreat_dir = (retreat_dir * 0.5 + (king.global_position - global_position).normalized() * 0.5).normalized()

			if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
				retreat_dir = (retreat_dir * 0.45 + _bypass_direction * 0.75).normalized()

			velocity = velocity.move_toward(retreat_dir * base_speed, 650.0 * delta)
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				animated_sprite.speed_scale = 1.0
				if abs(dir.x) > 0.05:
					animated_sprite.flip_h = dir.x < 0.0
			_is_trying_to_move = true

			if can_shoot:
				_shoot_at_enemy(target_enemy)
		elif dist <= attack_range:
			# Alcance seguro de disparo à distância: para e atira
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			move_and_slide()
			if abs(dir.x) > 0.05 and animated_sprite:
				animated_sprite.flip_h = dir.x < 0.0

			if can_shoot:
				_shoot_at_enemy(target_enemy)
			else:
				if animated_sprite and animated_sprite.animation != "idle":
					animated_sprite.play("idle")
					animated_sprite.speed_scale = 1.0
		else:
			# Fora de alcance: aproxima-se até o alcance máximo de tiro (com rota recalculada se ativo)
			var move_dir := dir
			if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
				move_dir = (dir * 0.45 + _bypass_direction * 0.75).normalized()
			velocity = velocity.move_toward(move_dir * base_speed, 600.0 * delta)
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				animated_sprite.speed_scale = 1.0
				if abs(move_dir.x) > 0.05:
					animated_sprite.flip_h = move_dir.x < 0.0
			_is_trying_to_move = true
	elif is_instance_valid(king):
		_move_in_formation(king, delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
			animated_sprite.speed_scale = 1.0

	_update_stuck_detector(delta, _is_trying_to_move)

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
			animated_sprite.speed_scale = 1.0
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
	if not is_trying_to_move or is_dead or is_stunned or is_shooting or _is_reversing:
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

	target_enemy = null
	_stuck_check_pos = global_position

func _shoot_at_enemy(enemy_node: Node2D) -> void:
	if not is_instance_valid(enemy_node):
		return

	is_shooting = true
	can_shoot = false
	velocity = Vector2.ZERO

	var dir: Vector2 = (enemy_node.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	if animated_sprite:
		animated_sprite.flip_h = dir.x < 0.0
		var cd_mult: float = UpgradeManager.get_archer_cooldown_multiplier()
		var anim_speed_scale: float = clampf(1.0 / maxf(0.1, cd_mult), 1.0, 3.0)
		animated_sprite.speed_scale = anim_speed_scale
		animated_sprite.play("shoot")

	if ARROW_SCENE:
		var arrow := ARROW_SCENE.instantiate()
		arrow.global_position = global_position + dir * 20.0
		arrow.direction = dir
		arrow.speed = arrow_speed
		arrow.damage = get_total_damage()
		arrow.is_player_ally = true
		if "shooter" in arrow:
			arrow.shooter = self

		var scene_root := get_tree().current_scene
		if scene_root:
			scene_root.add_child(arrow)
		elif get_parent():
			get_parent().add_child(arrow)

	SoundManager.play_hit()

	if is_inside_tree():
		var timer := get_tree().create_timer(get_shoot_cooldown())
		timer.timeout.connect(func(): can_shoot = true)
	else:
		can_shoot = true

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "shoot":
		is_shooting = false
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")

func _find_closest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_dist: float = attack_range

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= min_dist:
			min_dist = dist
			closest = enemy

	return closest

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
	is_shooting = false
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
