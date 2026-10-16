extends CharacterBody2D

enum State { ENTERING_MAP, CHASING_PLAYER }

## Estado atual de navegação do arqueiro inimigo
var current_state: State = State.ENTERING_MAP

## Ponto de passagem da clareira por onde o inimigo deve entrar
var gate_position: Vector2 = Vector2.ZERO

## Controle do sistema anti-travamento (desvio de obstáculos)
var avoidance_timer: float = 0.0
var avoidance_direction: Vector2 = Vector2.ZERO

## Watchdog para impedir que inimigos fiquem presos ou sumam fora do mapa
var time_outside: float = 0.0

## Vida inicial do arqueiro vermelho.
@export var health: int = 25

## Velocidade base de movimentação.
@export var base_speed: float = 80.0

## Incremento de velocidade a cada novo turno.
@export var speed_increase_per_turn: float = 8.0

## Turno atual deste arqueiro.
@export var turn: int = 1:
	set(value):
		turn = value
		_update_speed()

## Velocidade atual de movimentação em pixels por segundo.
@export var speed: float = 80.0

## Distâncias de combate para arqueiro
const MIN_DISTANCE: float = 250.0
const MAX_DISTANCE: float = 400.0

var is_shooting: bool = false
var is_dead: bool = false
var target_player: CharacterBody2D = null

## Temporizador procedural para cadência lenta de tiro (2.8 a 3.2s)
var shoot_timer: float = 0.0
var next_shoot_interval: float = 3.0

const ARROW_SCENE: PackedScene = preload("res://scenes/arrow.tscn")
const ITEM_PICKUP_SCENE: PackedScene = preload("res://scenes/item_pickup.tscn")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	_update_speed()
	next_shoot_interval = randf_range(2.8, 3.2)
	shoot_timer = randf_range(0.5, 1.5) # Disparo inicial dessincronizado

	if gate_position == Vector2.ZERO or _is_inside_village():
		current_state = State.CHASING_PLAYER

	if animated_sprite:
		animated_sprite.play("idle")
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

func _update_speed() -> void:
	speed = base_speed + float(maxi(0, turn - 1)) * speed_increase_per_turn

func _is_inside_village() -> bool:
	return global_position.x >= 140.0 and global_position.x <= 1860.0 and global_position.y >= 140.0 and global_position.y <= 1360.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Atualiza o timer do sistema anti-travamento
	if avoidance_timer > 0.0:
		avoidance_timer -= delta
	else:
		avoidance_direction = Vector2.ZERO

	# Garante referência ao jogador
	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	var base_direction := Vector2.ZERO

	match current_state:
		State.ENTERING_MAP:
			time_outside += delta
			# Watchdog: se não conseguir entrar em 6 segundos, puxa para a clareira e ativa perseguição
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

				if dist_to_gate < 40.0 or _is_inside_village():
					current_state = State.CHASING_PLAYER
					time_outside = 0.0
				else:
					base_direction = to_gate.normalized() if dist_to_gate > 0.0 else Vector2.ZERO

		State.CHASING_PLAYER:
			# Failsafe de retorno ao mapa caso empurrado
			if not _is_inside_village():
				time_outside += delta
				if time_outside > 2.0:
					global_position = Vector2(clampf(global_position.x, 200.0, 1800.0), clampf(global_position.y, 200.0, 1300.0))
					time_outside = 0.0
			else:
				time_outside = 0.0

			if is_instance_valid(target_player):
				var to_player := target_player.global_position - global_position
				var dist_to_player := to_player.length()

				# Controle de distância segura (entre 250 e 400 pixels)
				if dist_to_player > MAX_DISTANCE:
					# Muito longe: aproxima-se do jogador
					base_direction = to_player.normalized()
				elif dist_to_player < MIN_DISTANCE:
					# Muito perto: recua suavemente mantendo distância segura
					base_direction = -to_player.normalized()
				else:
					# Na distância perfeita de tiro (250..400px): para para disparar
					base_direction = Vector2.ZERO

				# Processamento do disparo com cadência lenta (2.8 a 3.2s)
				if not is_shooting:
					shoot_timer += delta
					if shoot_timer >= next_shoot_interval:
						# Dispara se o jogador estiver visível até o alcance de tiro
						if dist_to_player <= 450.0:
							_shoot_at_player(target_player)
						shoot_timer = 0.0
						next_shoot_interval = randf_range(2.8, 3.2)

	# Aplica desvio do sistema anti-travamento
	var final_direction := base_direction
	if avoidance_timer > 0.0 and avoidance_direction != Vector2.ZERO:
		final_direction = (base_direction * 0.4 + avoidance_direction * 0.8).normalized()

	var desired_velocity := Vector2.ZERO
	if not is_shooting and final_direction != Vector2.ZERO:
		desired_velocity = final_direction * speed

	velocity = velocity.move_toward(desired_velocity, 600.0 * delta)
	move_and_slide()

	# Anti-travamento ao colidir com obstáculos
	if get_slide_collision_count() > 0 and not is_shooting:
		if velocity.length() < 25.0 and desired_velocity.length() > 20.0:
			if avoidance_timer <= 0.0:
				var collision := get_slide_collision(0)
				var normal := collision.get_normal()
				var perp_a := Vector2(-normal.y, normal.x)
				var perp_b := Vector2(normal.y, -normal.x)
				if perp_b.dot(base_direction) > perp_a.dot(base_direction):
					avoidance_direction = perp_b
				elif perp_a.dot(base_direction) > perp_b.dot(base_direction):
					avoidance_direction = perp_a
				else:
					avoidance_direction = perp_a if randf() < 0.5 else perp_b
				avoidance_timer = 0.5

	# Atualiza visual do sprite
	if animated_sprite and not is_shooting:
		var is_moving: bool = velocity.length() > 10.0
		if is_moving:
			animated_sprite.play("run")
			if abs(desired_velocity.x) > 0.1:
				animated_sprite.flip_h = desired_velocity.x < 0.0
			elif abs(velocity.x) > 0.1:
				animated_sprite.flip_h = velocity.x < 0.0
		else:
			animated_sprite.play("idle")
			if is_instance_valid(target_player):
				var dir_x: float = target_player.global_position.x - global_position.x
				if abs(dir_x) > 0.1:
					animated_sprite.flip_h = dir_x < 0.0

func _shoot_at_player(player_node: CharacterBody2D) -> void:
	if not is_instance_valid(player_node) or is_dead:
		return

	is_shooting = true
	velocity = Vector2.ZERO

	var dir: Vector2 = (player_node.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	if animated_sprite:
		animated_sprite.flip_h = dir.x < 0.0
		animated_sprite.play("shoot")

	# Instancia a flecha mirando no jogador
	if ARROW_SCENE:
		var arrow := ARROW_SCENE.instantiate()
		arrow.global_position = global_position + dir * 20.0
		arrow.direction = dir
		arrow.speed = 450.0
		arrow.damage = 15
		arrow.is_player_ally = false

		var scene_root := get_tree().current_scene
		if scene_root:
			scene_root.add_child(arrow)
		elif get_parent():
			get_parent().add_child(arrow)

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "shoot":
		is_shooting = false
		if velocity.length() > 10.0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	health -= amount

	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 220.0

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
	is_shooting = false

	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	var death_tween := create_tween().set_parallel(true)
	var fall_angle: float = 90.0 if (animated_sprite and animated_sprite.flip_h) else -90.0
	if animated_sprite:
		death_tween.tween_property(animated_sprite, "rotation_degrees", fall_angle, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.35)

	death_tween.chain().tween_callback(_on_death_complete)

func _on_death_complete() -> void:
	_drop_gold()
	queue_free()

func _drop_gold() -> void:
	if not ITEM_PICKUP_SCENE:
		return
	var coin := ITEM_PICKUP_SCENE.instantiate()
	if "item_type" in coin:
		coin.item_type = "coin"
	coin.global_position = global_position

	var world_scene := get_tree().current_scene
	var pickups_container := world_scene.get_node_or_null("Pickups") if world_scene else null
	if pickups_container:
		pickups_container.add_child(coin)
	elif get_parent():
		get_parent().add_child(coin)
