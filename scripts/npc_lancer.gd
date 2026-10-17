extends CharacterBody2D

## Nome de exibição do lanceiro de elite no diálogo.
@export var npc_name: String = "Lanceiro Real de Elite"

## Custo para contratar o lanceiro como aliado da guarda real.
@export var hiring_cost: int = 100

## Velocidade ao seguir o jogador ou avançar nos monstros.
@export var follow_speed: float = 210.0

## Alcance máximo para detectar monstros ao redor (260 pixels).
@export var detection_range: float = 260.0

## Distância segura para desferir a estocada de lança (70 a 90 pixels).
@export var attack_range: float = 88.0

## Dano causado pela estocada perfurante da lança.
@export var attack_damage: int = 35

## Tempo de recarga entre os golpes de lança (1.0 segundo).
@export var attack_cooldown: float = 1.0

var is_hired: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_player_in_range: bool = false
var target_player: CharacterBody2D = null
var last_attack_dir: Vector2 = Vector2.RIGHT
var hit_enemies: Array[Node2D] = []

@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_label: Label = $InteractionLabel
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var spear_hitbox: Area2D = $SpearHitbox if has_node("SpearHitbox") else null
@onready var spear_collision: CollisionShape2D = $SpearHitbox/CollisionShape2D if has_node("SpearHitbox/CollisionShape2D") else null

func _ready() -> void:
	add_to_group("npcs")
	add_to_group("allies")
	collision_layer = 4
	collision_mask = 1
	y_sort_enabled = true

	if animated_sprite:
		animated_sprite.play("idle")
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

	if interaction_label:
		interaction_label.visible = false

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	if spear_hitbox:
		spear_hitbox.monitoring = false
		if spear_collision:
			spear_collision.disabled = true
		if not spear_hitbox.body_entered.is_connected(_on_spear_hitbox_body_entered):
			spear_hitbox.body_entered.connect(_on_spear_hitbox_body_entered)

func _physics_process(_delta: float) -> void:
	if not is_hired:
		return

	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Busca por monstros próximos no raio de 260 pixels
	var closest_enemy := _find_closest_enemy()

	if is_instance_valid(closest_enemy):
		var dist_to_enemy: float = global_position.distance_to(closest_enemy.global_position)
		var dir_to_enemy: Vector2 = (closest_enemy.global_position - global_position).normalized()

		if dist_to_enemy <= attack_range:
			# Alcance de estocada da lança (70 a 90 pixels de distância segura)
			velocity = Vector2.ZERO
			move_and_slide()
			if abs(dir_to_enemy.x) > 0.05 and animated_sprite:
				animated_sprite.flip_h = dir_to_enemy.x < 0.0

			if can_attack:
				_attack_enemy(closest_enemy)
			else:
				if animated_sprite and animated_sprite.animation != "idle":
					animated_sprite.play("idle")
		else:
			# Avança até a distância segura de combate da lança
			velocity = dir_to_enemy * (follow_speed * 1.1)
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(dir_to_enemy.x) > 0.05:
					animated_sprite.flip_h = dir_to_enemy.x < 0.0
	elif is_instance_valid(target_player):
		# Sem inimigos por perto: acompanha o Rei na formação de escolta
		var distance: float = global_position.distance_to(target_player.global_position)

		# Posição de flanco ligeiramente à frente e ao lado da marcha
		var target_pos := target_player.global_position
		if target_player.velocity.length() > 20.0:
			target_pos -= target_player.velocity.normalized() * 50.0 + Vector2(-30.0, 15.0)

		var to_target := target_pos - global_position

		if distance > 90.0:
			var direction: Vector2 = to_target.normalized() if to_target.length() > 0.0 else (target_player.global_position - global_position).normalized()
			velocity = direction * follow_speed
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(direction.x) > 0.05:
					animated_sprite.flip_h = direction.x < 0.0
		elif distance < 45.0:
			# Recua ligeiramente se estiver colado no Rei
			var repulse_dir: Vector2 = (global_position - target_player.global_position).normalized()
			if repulse_dir == Vector2.ZERO:
				repulse_dir = Vector2.DOWN
			velocity = repulse_dir * (follow_speed * 0.5)
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(repulse_dir.x) > 0.05:
					animated_sprite.flip_h = repulse_dir.x < 0.0
		else:
			velocity = Vector2.ZERO
			move_and_slide()
			if animated_sprite and animated_sprite.animation != "idle":
				animated_sprite.play("idle")

func _attack_enemy(enemy: Node2D) -> void:
	is_attacking = true
	can_attack = false
	hit_enemies.clear()

	last_attack_dir = (enemy.global_position - global_position).normalized()
	if last_attack_dir == Vector2.ZERO:
		last_attack_dir = Vector2.RIGHT

	if animated_sprite:
		animated_sprite.flip_h = last_attack_dir.x < 0.0
		animated_sprite.play("attack")

	SoundManager.play_slash()

	# Configura a área de golpe alongada (80x24) projetada na frente da lança
	if spear_hitbox and spear_collision:
		spear_hitbox.position = last_attack_dir * 60.0 + Vector2(0, 15.0)
		spear_hitbox.rotation = last_attack_dir.angle()
		spear_collision.disabled = false
		spear_hitbox.monitoring = true

		# Processa inimigos que já estão na trajetória no início do golpe
		var overlapping := spear_hitbox.get_overlapping_bodies()
		for body in overlapping:
			_process_enemy_hit(body)

	# Cooldown de 1.0 segundo entre os ataques de lança
	if is_inside_tree():
		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func(): can_attack = true)
	else:
		can_attack = true

func _on_spear_hitbox_body_entered(body: Node2D) -> void:
	if is_attacking:
		_process_enemy_hit(body)

func _process_enemy_hit(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if body.is_in_group("enemies") and not body in hit_enemies and body.has_method("take_damage"):
		hit_enemies.append(body)
		var knock_dir := (body.global_position - global_position).normalized()
		if knock_dir == Vector2.ZERO:
			knock_dir = last_attack_dir
		body.take_damage(attack_damage, knock_dir)

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "attack":
		if spear_collision:
			spear_collision.disabled = true
		if spear_hitbox:
			spear_hitbox.monitoring = false
		is_attacking = false
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range:
		return

	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")
	if dialogue_box and dialogue_box.get("is_active"):
		return

	var pressed_interact := false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		pressed_interact = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pressed_interact = true

	if pressed_interact:
		get_viewport().set_input_as_handled()
		trigger_dialogue()

func trigger_dialogue() -> void:
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")
	if not dialogue_box or not dialogue_box.has_method("start_dialogue"):
		return

	if interaction_label:
		interaction_label.visible = false

	if not is_hired:
		var lines: Array[String] = [
			"Saudações, Majestade! Sou um lanceiro de elite da guarda real. Minha lança perfura inimigos com grande alcance. Deseja me contratar por 100 moedas de ouro? [Pressione E para Contratar / Afaste-se para Recusar]"
		]
		dialogue_box.start_dialogue(lines, npc_name)

		if not dialogue_box.dialogue_finished.is_connected(_on_hiring_dialogue_finished):
			dialogue_box.dialogue_finished.connect(_on_hiring_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		var lines: Array[String] = [
			"Minha lança está a postos, Majestade! A guarda real manterá as defesas inabaláveis."
		]
		dialogue_box.start_dialogue(lines, npc_name)

func _on_hiring_dialogue_finished() -> void:
	if not is_player_in_range:
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player):
		return

	var player_coins: int = player.coins if "coins" in player else 0
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")

	if player_coins >= hiring_cost:
		if "coins" in player:
			player.coins -= hiring_cost
			if player.has_signal("coins_changed"):
				player.coins_changed.emit(player.coins)

		is_hired = true
		target_player = player
		SoundManager.play_coin()

		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var confirm_lines: Array[String] = [
				"Pela guarda real e pela coroa! Minha lança perfurará qualquer invasor com precisão implacável."
			]
			dialogue_box.start_dialogue(confirm_lines, npc_name)
	else:
		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var fail_lines: Array[String] = [
				"Você não possui as 100 moedas de ouro necessárias. Derrote monstros para juntar o ouro, Majestade!"
			]
			dialogue_box.start_dialogue(fail_lines, npc_name)

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		target_player = body as CharacterBody2D
		if interaction_label and not is_hired:
			interaction_label.visible = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		if interaction_label:
			interaction_label.visible = false
