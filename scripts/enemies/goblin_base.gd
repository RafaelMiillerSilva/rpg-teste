class_name GoblinBase
extends CharacterBody2D

## Classe Base para todos os Goblins invasores.
## Gerencia vida, dano, escala por turno, IA de perseguição/alvo e morte.

const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/item_pickup.tscn")

@export var base_max_health: int = 25
@export var base_damage: int = 8
@export var base_speed: float = 130.0
@export var base_armor: int = 0
@export var goblin_type_name: String = "normal" # "normal", "range", "warrior", "healer", "giant"

var turn: int = 1:
	set(val):
		turn = val
		_apply_turn_scaling()

var max_health: int = 25
var current_health: int = 25
var damage: int = 8
var speed: float = 130.0
var armor: int = 0

var is_dead: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_guarding: bool = false
var current_target: Node2D = null

## Sistema de movimentação inteligente anti-travamento (lógica dos warriors inimigos)
var avoidance_timer: float = 0.0
var avoidance_direction: Vector2 = Vector2.ZERO
var time_outside: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null

var _hit_tween: Tween

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 3
	collision_mask = 3
	y_sort_enabled = true
	_apply_turn_scaling()
	_setup_health_bar()

	if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

## Configura vida, dano, velocidade e armadura com escalonamento por turno (1.025 por turno)
func _apply_turn_scaling() -> void:
	var t: int = maxi(1, turn)
	var scale_factor: float = pow(1.025, float(t - 1))
	damage = int(round(float(base_damage) * scale_factor))
	max_health = int(round(float(base_max_health) * scale_factor))
	current_health = max_health
	armor = int(round(float(base_armor) * scale_factor)) if base_armor > 0 else 0
	speed = base_speed * scale_factor
	_update_health_bar()

func _setup_health_bar() -> void:
	if health_bar:
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.12, 0.12, 0.12, 0.85)
		bg_style.set_corner_radius_all(2)
		health_bar.add_theme_stylebox_override("background", bg_style)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.90, 0.15, 0.15, 1.0)
		fill_style.set_corner_radius_all(2)
		health_bar.add_theme_stylebox_override("fill", fill_style)

		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.show_percentage = false
		health_bar.visible = (current_health < max_health)

func _update_health_bar() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = (current_health < max_health)

func _is_inside_village() -> bool:
	return global_position.x >= 250.0 and global_position.x <= 7750.0 and global_position.y >= 250.0 and global_position.y <= 5750.0

func update_avoidance_timer(delta: float) -> void:
	if avoidance_timer > 0.0:
		avoidance_timer -= delta
	else:
		avoidance_direction = Vector2.ZERO

	# Failsafe para evitar que goblins fiquem presos ou sumam fora do mapa
	if not _is_inside_village():
		time_outside += delta
		if time_outside > 2.0:
			global_position = Vector2(clampf(global_position.x, 350.0, 7650.0), clampf(global_position.y, 350.0, 5650.0))
			time_outside = 0.0
	else:
		time_outside = 0.0

## Calcula a direção inteligente com desvio do castelo e vetor anti-travamento
func calculate_smart_direction(target_pos: Vector2) -> Vector2:
	var to_target := target_pos - global_position
	var dist := to_target.length()
	var base_direction := Vector2.ZERO

	# Se estiver ao norte do castelo central (4000, 2450) e o alvo estiver ao sul,
	# contorna o castelo pelas laterais em vez de prender na parede de trás
	if global_position.y < 2400.0 and target_pos.y > 2500.0 and abs(global_position.x - 4000.0) < 220.0:
		var bypass_x: float = 3780.0 if global_position.x <= 4000.0 else 4220.0
		base_direction = (Vector2(bypass_x, 2520.0) - global_position).normalized()
	else:
		base_direction = to_target.normalized() if dist > 0.0 else Vector2.ZERO

	# Aplica desvio do sistema anti-travamento se ativo
	var final_direction := base_direction
	if avoidance_timer > 0.0 and avoidance_direction != Vector2.ZERO:
		final_direction = (base_direction * 0.4 + avoidance_direction * 0.8).normalized()

	return final_direction

## Aplica aceleração suave, move_and_slide e atualiza o sistema anti-travamento por normais de colisão
func apply_smart_movement(target_dir: Vector2, delta: float, move_speed: float = -1.0) -> void:
	if move_speed < 0.0:
		move_speed = speed

	var desired_velocity := target_dir * move_speed
	velocity = velocity.move_toward(desired_velocity, 650.0 * delta)
	move_and_slide()

	# Sistema anti-travamento: detecta bloqueio por obstáculos (árvores, construções, outros goblins)
	if get_slide_collision_count() > 0 and not is_attacking:
		if velocity.length() < 25.0 and desired_velocity.length() > 20.0:
			if avoidance_timer <= 0.0:
				var collision := get_slide_collision(0)
				var normal := collision.get_normal()
				var perp_a := Vector2(-normal.y, normal.x)
				var perp_b := Vector2(normal.y, -normal.x)

				# Escolhe a direção perpendicular que melhor avança em direção ao alvo
				if perp_b.dot(target_dir) > perp_a.dot(target_dir):
					avoidance_direction = perp_b
				elif perp_a.dot(target_dir) > perp_b.dot(target_dir):
					avoidance_direction = perp_a
				else:
					avoidance_direction = perp_a if randf() < 0.5 else perp_b

				avoidance_timer = 0.5

## Verifica colisões físicas com o jogador ou aliados durante o deslocamento para atacar imediatamente
func check_player_collisions(attack_callable: Callable) -> void:
	if not can_attack or is_attacking:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and (collider.is_in_group("player") or collider.is_in_group("allies")) and collider.has_method("take_damage"):
			attack_callable.call(collider as Node2D)
			break

func _find_target() -> Node2D:
	if not is_inside_tree() or not get_tree():
		return null
	var candidates: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
		candidates.append(player)

	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			candidates.append(ally as Node2D)

	if candidates.is_empty():
		return null

	var closest: Node2D = null
	var min_dist: float = 999999.0
	for cand in candidates:
		var d := global_position.distance_to(cand.global_position)
		if d < min_dist:
			min_dist = d
			closest = cand
	return closest

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, attacker: Node = null) -> void:
	if is_dead:
		return

	var final_damage: int = amount

	# Postura de Guarda do Goblin Warrior: bloqueia 70% de todo dano físico (recebe apenas 30%)
	if is_guarding:
		final_damage = maxi(1, int(round(float(amount) * 0.3)))
		is_guarding = false # Sai da guarda após absorver o golpe
		is_attacking = false
		if "guard_timer" in self:
			self.guard_timer = 0.0
		if "_wants_guard" in self:
			self._wants_guard = false
		if animated_sprite and animated_sprite.animation == "guard":
			animated_sprite.play("idle")
	else:
		final_damage = maxi(1, final_damage - armor)

	current_health -= final_damage
	_update_health_bar()
	SoundManager.play_hit()

	# Flash vermelho de impacto
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	modulate = Color(1.6, 0.3, 0.3, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "modulate", Color.WHITE, 0.2)

	# Efeito de recuo (knockback) proporcional
	if knockback_dir != Vector2.ZERO:
		velocity += knockback_dir * 110.0

	# Agro imediato no atacante se for herói válido
	if is_instance_valid(attacker) and attacker is Node2D:
		current_target = attacker as Node2D

	if current_health <= 0:
		die()

func heal(amount: int) -> void:
	if is_dead or current_health >= max_health:
		return
	current_health = mini(max_health, current_health + amount)
	_update_health_bar()

	# Flash verde suave de cura
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	modulate = Color(0.4, 1.8, 0.5, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	can_attack = false
	is_attacking = false
	is_guarding = false

	# Cancela flash de impacto para não interferir no fade de morte
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	modulate = Color.WHITE

	# Para imediatamente todo e qualquer movimento
	velocity = Vector2.ZERO
	set_physics_process(false)

	# Desativa colisões para não atrapalhar outros combatentes
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if health_bar:
		health_bar.visible = false

	# Para de correr imediatamente: volta ao frame estático de idle
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
			animated_sprite.frame = 0
		animated_sprite.stop()

	# Drop de Moedas de Ouro no chão e 10% de chance de Poção de Vida
	_drop_loot()

	# Ao morrer gira 90 graus para TRÁS (caindo de costas no chão):
	# Se flip_h for true (olhando para a esquerda), tomba para a direita (+90 graus = para trás)
	# Se flip_h for false (olhando para a direita), tomba para a esquerda (-90 graus = para trás)
	if animated_sprite:
		var fall_angle: float = 90.0 if animated_sprite.flip_h else -90.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(animated_sprite, "rotation_degrees", fall_angle, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.45)
		tween.chain().tween_callback(queue_free)
	else:
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.45)
		tween.chain().tween_callback(queue_free)

func _drop_loot() -> void:
	if not is_inside_tree() or not ITEM_PICKUP_SCENE:
		return
	var parent_node := get_parent()
	if not parent_node:
		return

	# Drop garantido de Moeda de Ouro
	var coin = ITEM_PICKUP_SCENE.instantiate()
	coin.global_position = global_position
	if "item_type" in coin:
		coin.item_type = "coin"
	parent_node.call_deferred("add_child", coin)

	# 10% de chance de todos os goblins droparem poção
	if randf() <= 0.10:
		var potion = ITEM_PICKUP_SCENE.instantiate()
		potion.global_position = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		if "item_type" in potion:
			potion.item_type = "potion"
		parent_node.call_deferred("add_child", potion)

func _on_animation_finished() -> void:
	if animated_sprite and (animated_sprite.animation == "attack" or animated_sprite.animation == "smash"):
		is_attacking = false
		animated_sprite.play("idle")
