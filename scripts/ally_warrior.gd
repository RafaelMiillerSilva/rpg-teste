extends CharacterBody2D

const UpgradeManager = preload("res://scripts/upgrade_manager.gd")
const STUN_EFFECT_SCENE: PackedScene = preload("res://scenes/stun_effect.tscn")
const DUST_EFFECT_SCENE: PackedScene = preload("res://scenes/dust_effect.tscn")

## Unidade Móvel Aliada: Guerreiro da Linha de Frente.
## Participa do esquadrão do Rei, forma círculo defensivo e combate inimigos corpo a corpo.

signal health_updated(current: int, max_val: int)
signal died(ally_node: Node2D, unit_name: String)

@export var unit_display_name: String = "Warrior"
@export var base_max_health: int = 280
@export var base_armor: int = 5
@export var base_damage: int = 40
@export var base_speed: float = 210.0
@export var attack_range: float = 68.0
@export var detection_range: float = 230.0

var max_health: int = 280
var current_health: int = 280
var armor: int = 5

var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_guarding: bool = false
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

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var armor_label: Label = $ArmorLabel if has_node("ArmorLabel") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("allies")
	add_to_group("allies_melee")
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
	return base_damage + UpgradeManager.get_bonus_damage()

func get_attack_cooldown() -> float:
	return 1.0 * UpgradeManager.get_attack_cooldown_multiplier()

## Calcula o alcance efetivo de ataque considerando o tamanho físico de alvos grandes (ex: Giant)
func get_effective_attack_range(target: Node2D) -> float:
	var base_r := attack_range
	if not is_instance_valid(target):
		return base_r
	if target.get("goblin_type_name") == "giant" or target.name.to_lower().contains("giant"):
		return 118.0
	var col := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape:
		if col.shape is RectangleShape2D:
			var sz: Vector2 = (col.shape as RectangleShape2D).size
			var half_dim: float = maxf(sz.x, sz.y) * 0.5
			return maxf(base_r, half_dim + 45.0)
		elif col.shape is CircleShape2D:
			return maxf(base_r, (col.shape as CircleShape2D).radius + 45.0)
	return base_r

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

	if is_attacking:
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		_update_stuck_detector(delta, false)
		return

	var king := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var dist_to_king: float = global_position.distance_to(king.global_position) if is_instance_valid(king) else 0.0

	# Sistema Anti-Travamento: se ficar muito distante do player (ou travado tentando andar), teleporte com fumaça Dust_02.png
	if is_instance_valid(king):
		if dist_to_king > 480.0 or (_stuck_timer >= 3.0 and dist_to_king > 180.0):
			_teleport_to_formation(king)
			return

	var is_low_health: bool = (current_health < int(round(float(max_health) * 0.25)))
	var king_too_far: bool = is_instance_valid(king) and (dist_to_king > 280.0)

	# Se a vida estiver abaixo de 25% OU se o Rei se distanciou muito, prioriza voltar/recuar para o círculo do Rei
	if is_instance_valid(king) and (is_low_health or king_too_far):
		is_guarding = false
		_move_in_formation(king, delta, true if king_too_far else false)
		# Se estiver próximo da formação e um monstro colado, contra-ataca no local sem sair da formação
		if can_attack and not is_attacking and not king_too_far:
			target_enemy = _find_closest_enemy()
			if is_instance_valid(target_enemy) and global_position.distance_to(target_enemy.global_position) <= get_effective_attack_range(target_enemy):
				_attack_enemy(target_enemy)
		_update_stuck_detector(delta, _is_trying_to_move)
		return

	target_enemy = _find_closest_enemy()

	# Se estiver em guarda, verifica se ainda há inimigos em um raio de 180px
	if is_guarding:
		var enemy_nearby := false
		if is_instance_valid(target_enemy) and global_position.distance_to(target_enemy.global_position) <= 180.0:
			enemy_nearby = true

		if not enemy_nearby:
			is_guarding = false
			if animated_sprite and animated_sprite.animation == "guard":
				animated_sprite.play("idle")
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			move_and_slide()
			if animated_sprite:
				var dir_e: Vector2 = (target_enemy.global_position - global_position).normalized()
				if abs(dir_e.x) > 0.05:
					animated_sprite.flip_h = dir_e.x < 0.0
				if animated_sprite.animation != "guard":
					animated_sprite.play("guard")
			_update_stuck_detector(delta, false)
			return

	if is_instance_valid(target_enemy):
		# Em combate com monstros próximos
		var dist: float = global_position.distance_to(target_enemy.global_position)
		var dir: Vector2 = (target_enemy.global_position - global_position).normalized()
		var eff_range: float = get_effective_attack_range(target_enemy)

		if dist <= eff_range:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			move_and_slide()
			if abs(dir.x) > 0.05 and animated_sprite:
				animated_sprite.flip_h = dir.x < 0.0

			if can_attack:
				_attack_enemy(target_enemy)
			else:
				if animated_sprite and animated_sprite.animation != "idle":
					animated_sprite.play("idle")
		else:
			# Avança até o inimigo com rota recalculada se ativo
			var move_dir := dir
			if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
				move_dir = (dir * 0.45 + _bypass_direction * 0.75).normalized()
			velocity = velocity.move_toward(move_dir * (base_speed * 1.15), 600.0 * delta)
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(move_dir.x) > 0.05:
					animated_sprite.flip_h = move_dir.x < 0.0
			_is_trying_to_move = true
	elif is_instance_valid(king):
		# Fora de combate: formação em círculo em volta do Rei
		_move_in_formation(king, delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

	_update_stuck_detector(delta, _is_trying_to_move)

## Efeito de fumaça usando a textura Dust_02.png (animação dust_2)
func _spawn_dust_02(pos: Vector2) -> void:
	if not DUST_EFFECT_SCENE or not is_inside_tree():
		return
	var dust := DUST_EFFECT_SCENE.instantiate() as Node2D
	dust.global_position = pos
	dust.scale = Vector2(1.5, 1.5)
	if dust.has_method("setup_dust_2"):
		dust.setup_dust_2()
	var parent_node := get_parent()
	if parent_node:
		parent_node.call_deferred("add_child", dust)

## Retorna a posição ideal de formação da unidade em torno do Rei
func _get_formation_position(king: CharacterBody2D) -> Vector2:
	var allies := get_tree().get_nodes_in_group("allies_melee")
	var valid_allies: Array[Node2D] = []
	for a in allies:
		if is_instance_valid(a) and not a.get("is_dead"):
			valid_allies.append(a as Node2D)

	var my_idx := valid_allies.find(self)
	if my_idx == -1:
		my_idx = 0

	var total_melee: int = maxi(1, valid_allies.size())
	var radius: float = 135.0 + (float(total_melee) * 10.0)
	var angle: float = float(my_idx) * (TAU / float(total_melee))
	return king.global_position + Vector2(cos(angle), sin(angle)) * radius

## Sistema Anti-Travamento: Teleporta o guerreiro de volta para a formação com fumaça Dust_02.png
func _teleport_to_formation(king: CharacterBody2D) -> void:
	var target_pos := _get_formation_position(king)

	# Fumaça Dust_02.png na posição atual para sumir
	_spawn_dust_02(global_position)

	# Teleporte instantâneo
	global_position = target_pos
	velocity = Vector2.ZERO

	# Fumaça Dust_02.png na posição de destino para aparecer
	_spawn_dust_02(global_position)

	_stuck_timer = 0.0
	_stuck_interval_timer = 0.0
	_is_reversing = false
	_bypass_timer = 0.0
	_bypass_direction = Vector2.ZERO
	_stuck_check_pos = global_position
	target_enemy = null

func _move_in_formation(king: CharacterBody2D, delta: float, sprint: bool = false) -> void:
	var formation_pos: Vector2 = _get_formation_position(king)

	var dist_to_pos: float = global_position.distance_to(formation_pos)

	if dist_to_pos > 25.0:
		var dir := (formation_pos - global_position).normalized()
		if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
			dir = (dir * 0.45 + _bypass_direction * 0.75).normalized()
		var move_speed: float = base_speed * 1.5 if sprint else base_speed
		if dist_to_pos > 180.0 and not sprint:
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
	if not is_trying_to_move or is_dead or is_stunned or is_attacking or is_guarding or _is_reversing:
		_stuck_timer = 0.0
		_stuck_check_pos = global_position
		_stuck_interval_timer = 0.0
		return

	_stuck_interval_timer += delta
	if _stuck_interval_timer >= 0.5:
		var dist_moved: float = global_position.distance_to(_stuck_check_pos)
		# Se em 0.5s tentando andar a tropa moveu menos de 15px (bloqueada por colisão)
		if dist_moved < 15.0:
			_stuck_timer += _stuck_interval_timer
		else:
			_stuck_timer = 0.0
			_stuck_check_pos = global_position
		_stuck_interval_timer = 0.0

	# Se atingiu 5.0 segundos travado andando sem sair da posição
	if _stuck_timer >= 5.0:
		_trigger_anti_stuck()

## Sistema Anti-Bugs: Ativa o recuo para trás
func _trigger_anti_stuck() -> void:
	_stuck_timer = 0.0
	_stuck_interval_timer = 0.0
	_is_reversing = true
	_reverse_timer = 1.0 # Anda para trás durante 1 segundo

	# Determina direção contrária (andar para trás)
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

	# Força recálculo de alvos e limpa posições de checagem
	target_enemy = null
	_stuck_check_pos = global_position

func _attack_enemy(enemy: Node2D) -> void:
	is_attacking = true
	can_attack = false
	SoundManager.play_slash()

	if animated_sprite:
		var cd_mult: float = UpgradeManager.get_attack_cooldown_multiplier()
		var anim_speed_scale: float = clampf(1.0 / maxf(0.1, cd_mult), 1.0, 3.0)
		animated_sprite.speed_scale = anim_speed_scale
		animated_sprite.play("attack")

	if is_instance_valid(enemy) and enemy.has_method("take_damage"):
		var knock_dir := (enemy.global_position - global_position).normalized()
		enemy.take_damage(get_total_damage(), knock_dir, self)

		# Se o inimigo NÃO morrer no golpe, 40% de chance (+ bônus de upgrade) de entrar em guarda
		if is_instance_valid(enemy) and not ("is_dead" in enemy and enemy.is_dead) and ("current_health" in enemy and enemy.current_health > 0):
			var block_chance: float = clampf(0.40 + (float(UpgradeManager.get_level("warrior_block")) * 0.10), 0.40, 0.80)
			if randf() < block_chance:
				is_guarding = true

	if is_inside_tree():
		var timer := get_tree().create_timer(get_attack_cooldown())
		timer.timeout.connect(func(): can_attack = true)
	else:
		can_attack = true

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "attack":
		is_attacking = false
		animated_sprite.speed_scale = 1.0
		if is_guarding:
			animated_sprite.play("guard")
		else:
			animated_sprite.play("idle")

func _find_closest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_dist: float = detection_range

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = enemy

	return closest

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, _attacker = null) -> void:
	if is_dead:
		return

	var raw_damage: float = float(amount)
	# Enquanto estiver em guarda: recebe 50% de redução de dano e sai da guarda após absorver o impacto
	if is_guarding:
		raw_damage *= 0.5
		is_guarding = false
		if animated_sprite and animated_sprite.animation == "guard":
			animated_sprite.play("idle")

	var final_damage := maxi(1, int(round(raw_damage)) - get_total_armor())
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
	is_attacking = false
	is_guarding = false
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
