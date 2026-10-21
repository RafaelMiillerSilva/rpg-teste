extends CharacterBody2D

enum State { ENTERING_MAP, CHASING_PLAYER }

## Estado atual de navegação do inimigo
var current_state: State = State.ENTERING_MAP

## Ponto de passagem da clareira por onde o inimigo deve entrar
var gate_position: Vector2 = Vector2.ZERO

## Controle do sistema anti-travamento (desvio de obstáculos)
var avoidance_timer: float = 0.0
var avoidance_direction: Vector2 = Vector2.ZERO

## Sistema Anti-Bugs / Anti-Travamento (Detecção de 5s travado andando sem sair da posição)
var _stuck_timer: float = 0.0
var _stuck_check_pos: Vector2 = Vector2.ZERO
var _stuck_interval_timer: float = 0.0
var _is_reversing: bool = false
var _reverse_timer: float = 0.0
var _reverse_direction: Vector2 = Vector2.ZERO

## Watchdog para impedir que inimigos fiquem presos ou sumam fora do mapa
var time_outside: float = 0.0

## Vida inicial do inimigo.
@export var health: int = 30
@export var max_health: int = 30

## Armadura do inimigo (reduz dano direto)
@export var armor: int = 1

## Velocidade base de movimentação do inimigo (Turno 1).
@export var base_speed: float = 80.0

## Incremento de velocidade a cada novo turno.
@export var speed_increase_per_turn: float = 12.0

## Turno atual deste inimigo (recalcula a velocidade automaticamente).
@export var turn: int = 1:
	set(value):
		turn = value
		_update_speed()

## Velocidade atual de movimentação em pixels por segundo.
@export var speed: float = 80.0

## Alcance corpo a corpo para disparar o golpe de espada.
@export var attack_range: float = 52.0

## Dano causado ao jogador pelo golpe.
@export var attack_damage: int = 10

## Cooldown entre ataques para evitar golpes contínuos imediatos.
@export var attack_cooldown: float = 0.8

var can_attack: bool = true
var is_attacking: bool = false
var target_player: Node2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null
@onready var sprite = $AnimatedSprite2D # Retrocompatibilidade
@onready var color_rect = $AnimatedSprite2D # Retrocompatibilidade

func _ready() -> void:
	add_to_group("enemies")
	_stuck_check_pos = global_position
	_update_speed()
	max_health = health
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
		health_bar.value = health
		health_bar.show_percentage = false

	target_player = get_tree().get_first_node_in_group("player") as Node2D

	# Se não recebeu gate_position válida ou já estiver dentro do vilarejo, persegue o jogador direto
	if gate_position == Vector2.ZERO or _is_inside_village():
		current_state = State.CHASING_PLAYER

	if animated_sprite:
		animated_sprite.play("idle")
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

func _update_speed() -> void:
	speed = base_speed + float(maxi(0, turn - 1)) * speed_increase_per_turn

func _is_inside_village() -> bool:
	return global_position.x >= 250.0 and global_position.x <= 7750.0 and global_position.y >= 250.0 and global_position.y <= 5750.0

func _physics_process(delta: float) -> void:
	# Atualiza o timer do sistema anti-travamento
	if avoidance_timer > 0.0:
		avoidance_timer -= delta
	else:
		avoidance_direction = Vector2.ZERO

	# Se estiver executando recuo anti-stuck (andando para trás por 1 segundo)
	if _is_reversing:
		_reverse_timer -= delta
		velocity = _reverse_direction * (speed * 0.85)
		move_and_slide()
		if animated_sprite and not is_attacking:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
			if abs(_reverse_direction.x) > 0.05:
				animated_sprite.flip_h = _reverse_direction.x < 0.0
		if _reverse_timer <= 0.0:
			_is_reversing = false
			_apply_route_recalculation()
		_update_stuck_detector(delta, false)
		return

	# Garante referência ao alvo válido (ou retorna ao Rei se o alvo tiver morrido)
	if not is_instance_valid(target_player) or ("is_dead" in target_player and target_player.is_dead):
		target_player = get_tree().get_first_node_in_group("player") as Node2D

	var base_direction := Vector2.ZERO

	# Máquina de estados: ENTERING_MAP -> CHASING_PLAYER
	match current_state:
		State.ENTERING_MAP:
			time_outside += delta
			# Watchdog: se não conseguir entrar na clareira em 6 segundos, teleporta para o gate e ativa perseguição
			if time_outside > 6.0:
				if gate_position != Vector2.ZERO:
					global_position = gate_position
				current_state = State.CHASING_PLAYER
				time_outside = 0.0
			elif gate_position == Vector2.ZERO:
				current_state = State.CHASING_PLAYER
			else:
				var to_gate := gate_position - global_position
				var dist_to_gate := to_gate.length()

				# Se estiver a menos de 40 pixels da clareira ou cruzar para dentro dos limites do vilarejo
				if dist_to_gate < 40.0 or _is_inside_village():
					current_state = State.CHASING_PLAYER
					time_outside = 0.0
					if is_instance_valid(target_player):
						base_direction = (target_player.global_position - global_position).normalized()
				else:
					base_direction = to_gate.normalized() if dist_to_gate > 0.0 else Vector2.ZERO

		State.CHASING_PLAYER:
			# Failsafe: caso o inimigo tenha sido empurrado para fora do mapa, puxa de volta para o gramado
			if not _is_inside_village():
				time_outside += delta
				if time_outside > 2.0:
					global_position = Vector2(clampf(global_position.x, 350.0, 7650.0), clampf(global_position.y, 350.0, 5650.0))
					time_outside = 0.0
			else:
				time_outside = 0.0

			if is_instance_valid(target_player):
				var to_player := target_player.global_position - global_position
				var dist_to_player := to_player.length()

				# Se o inimigo estiver ao norte do castelo central (4000, 2450) e o jogador estiver ao sul,
				# direciona para contornar o castelo pelos lados em vez de prender na parede de trás
				if global_position.y < 2400.0 and target_player.global_position.y > 2500.0 and abs(global_position.x - 4000.0) < 180.0:
					var bypass_x: float = 3800.0 if global_position.x <= 4000.0 else 4200.0
					base_direction = (Vector2(bypass_x, 2520.0) - global_position).normalized()
				else:
					base_direction = to_player.normalized() if dist_to_player > 0.0 else Vector2.ZERO

				# Executa o golpe se estiver em alcance de ataque
				if dist_to_player <= attack_range and can_attack:
					_attack_player(target_player)

	# Aplica desvio do sistema anti-travamento se ativo
	var final_direction := base_direction
	if avoidance_timer > 0.0 and avoidance_direction != Vector2.ZERO:
		final_direction = (base_direction * 0.4 + avoidance_direction * 0.8).normalized()

	var desired_velocity := Vector2.ZERO
	if not is_attacking and final_direction != Vector2.ZERO:
		desired_velocity = final_direction * speed

	# Move gradualmente até a velocidade desejada (preservando knockbacks)
	velocity = velocity.move_toward(desired_velocity, 600.0 * delta)
	move_and_slide()

	# Sistema anti-travamento: detecta bloqueio por obstáculos (árvores ou construções)
	if get_slide_collision_count() > 0 and not is_attacking:
		if velocity.length() < 25.0 and desired_velocity.length() > 20.0:
			if avoidance_timer <= 0.0:
				var collision := get_slide_collision(0)
				var normal := collision.get_normal()
				var perp_a := Vector2(-normal.y, normal.x)
				var perp_b := Vector2(normal.y, -normal.x)

				# Escolhe a direção perpendicular que melhor avança em direção ao alvo
				if perp_b.dot(base_direction) > perp_a.dot(base_direction):
					avoidance_direction = perp_b
				elif perp_a.dot(base_direction) > perp_b.dot(base_direction):
					avoidance_direction = perp_a
				else:
					avoidance_direction = perp_a if randf() < 0.5 else perp_b

				avoidance_timer = 0.5

	# Atualiza detector de travamento de 5 segundos
	var is_trying_to_move: bool = desired_velocity.length() > 20.0 and not is_attacking
	_update_stuck_detector(delta, is_trying_to_move)

	# Atualiza animação e orientação horizontal apenas quando não estiver atacando
	if animated_sprite and not is_attacking:
		var is_moving: bool = velocity.length() > 10.0
		if is_moving:
			animated_sprite.play("walk")
			animated_sprite.speed_scale = clampf(speed / maxf(1.0, base_speed), 0.5, 3.0)
			if abs(desired_velocity.x) > 0.1:
				animated_sprite.flip_h = desired_velocity.x < 0.0
			elif abs(velocity.x) > 0.1:
				animated_sprite.flip_h = velocity.x < 0.0
		else:
			animated_sprite.play("idle")
			animated_sprite.speed_scale = 1.0

	# Verifica se colidiu fisicamente com o jogador durante o deslocamento
	_check_player_collisions()

## Sistema Anti-Bugs: Detecta se a tropa ficou 5 segundos travada andando sem sair da posição
func _update_stuck_detector(delta: float, is_trying: bool) -> void:
	if not is_trying or is_dead or is_attacking or _is_reversing:
		_stuck_timer = 0.0
		_stuck_check_pos = global_position
		_stuck_interval_timer = 0.0
		return

	_stuck_interval_timer += delta
	if _stuck_interval_timer >= 0.5:
		var dist_moved: float = global_position.distance_to(_stuck_check_pos)
		# Se em 0.5s tentando andar a tropa moveu menos de 15px (bloqueada por colisão ou obstáculos)
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

	var backward_dir := -velocity.normalized()
	if backward_dir == Vector2.ZERO:
		if is_instance_valid(target_player):
			backward_dir = (global_position - target_player.global_position).normalized()
		else:
			backward_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

	var angle_offset: float = randf_range(0.35, 0.75) * (-1.0 if randf() < 0.5 else 1.0)
	_reverse_direction = backward_dir.rotated(angle_offset).normalized()

## Sistema Anti-Bugs: Recalcula a rota contornando lateralmente o obstáculo
func _apply_route_recalculation() -> void:
	var perp := Vector2(-_reverse_direction.y, _reverse_direction.x)
	if randf() < 0.5:
		perp = -perp
	avoidance_direction = perp
	avoidance_timer = 2.0 # Mantém o desvio de rota por 2 segundos

	_stuck_check_pos = global_position
	target_player = get_tree().get_first_node_in_group("player") as Node2D

func _check_player_collisions() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and (collider.is_in_group("player") or collider.is_in_group("allies")) and collider.has_method("take_damage"):
			if can_attack:
				_attack_player(collider as Node2D)
			break

func _attack_player(player_node: Node2D) -> void:
	if not can_attack or not is_instance_valid(player_node):
		return

	can_attack = false
	is_attacking = true

	# Vira o sprite na direção do ataque e dispara animação 'attack'
	var dir_to_player: Vector2 = player_node.global_position - global_position
	if animated_sprite:
		if abs(dir_to_player.x) > 0.1:
			animated_sprite.flip_h = dir_to_player.x < 0.0
		animated_sprite.play("attack")

	# Toca o som do golpe com a espada
	SoundManager.play_hit()

	var knockback_dir: Vector2 = dir_to_player.normalized()
	if knockback_dir == Vector2.ZERO:
		knockback_dir = Vector2.DOWN

	player_node.take_damage(attack_damage, knockback_dir, self)

	# Temporizador para recarga do ataque
	if is_inside_tree():
		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func(): can_attack = true)
	else:
		can_attack = true

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "attack":
		is_attacking = false
		if velocity.length() > 10.0:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")

const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/item_pickup.tscn")
var is_dead: bool = false

## Aplica dano com redução de armadura, atualiza barra de vida, pisca e troca agro para o atacante
func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, attacker = null) -> void:
	if is_dead:
		return

	SoundManager.play_hit()
	var final_damage := maxi(1, amount - armor)
	health -= final_damage

	if health_bar:
		health_bar.value = health

	# IA Avançada de Agro: se quem atacou estiver próximo (até 450px), foca nele
	if is_instance_valid(attacker) and attacker != self:
		var dist_to_atk: float = global_position.distance_to(attacker.global_position)
		if dist_to_atk <= 450.0:
			target_player = attacker

	# Empurrão resultante do golpe
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 250.0

	# Efeito visual de piscar em branco rapidamente ao receber dano
	if animated_sprite:
		animated_sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
		var tween := create_tween()
		if tween:
			tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)

	if health <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	can_attack = false
	is_attacking = false
	_is_reversing = false
	_stuck_timer = 0.0

	SoundManager.play_enemy_death()

	# Desativa colisões e processamento de física imediatamente
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
			animated_sprite.frame = 0
		animated_sprite.stop()

	# Queda de 90 graus para o lado com fade out
	var death_tween := create_tween().set_parallel(true)
	var fall_angle: float = 90.0 if (animated_sprite and animated_sprite.flip_h) else -90.0
	if animated_sprite:
		death_tween.tween_property(animated_sprite, "rotation_degrees", fall_angle, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.35)

	# Ao concluir a animação de morte, instancia o ouro e remove o nó
	death_tween.chain().tween_callback(_on_death_complete)

func _on_death_complete() -> void:
	_drop_loot()
	queue_free()

func _drop_loot() -> void:
	if not ITEM_PICKUP_SCENE:
		return

	var world_scene := get_tree().current_scene
	var pickups_container := world_scene.get_node_or_null("Pickups") if world_scene else null
	var parent_node := pickups_container if pickups_container else get_parent()
	if not parent_node:
		return

	# Drop garantido de 1 moeda de ouro
	var coin := ITEM_PICKUP_SCENE.instantiate()
	if "item_type" in coin:
		coin.item_type = "coin"
	coin.global_position = global_position
	parent_node.add_child(coin)

	# 5% de chance de dropar também uma Poção de Vida
	if randf() <= 0.05:
		var potion := ITEM_PICKUP_SCENE.instantiate()
		if "item_type" in potion:
			potion.item_type = "potion"
		potion.global_position = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		parent_node.add_child(potion)
