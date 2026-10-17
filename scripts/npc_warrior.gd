extends CharacterBody2D

## Nome de exibição do guerreiro aliado no diálogo.
@export var npc_name: String = "Guerreiro Leal"

## Custo para contratar o guerreiro como aliado.
@export var hiring_cost: int = 20

## Velocidade ao seguir o jogador ou avançar nos monstros.
@export var follow_speed: float = 210.0

## Alcance máximo para detectar monstros ao redor (220 pixels).
@export var detection_range: float = 220.0

## Distância para desferir o golpe de espada.
@export var attack_range: float = 55.0

## Dano causado pelo golpe de espada do guerreiro.
@export var attack_damage: int = 20

var is_hired: bool = false
var is_attacking: bool = false
var can_attack: bool = true
var is_player_in_range: bool = false
var target_player: CharacterBody2D = null

@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_label: Label = $InteractionLabel
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

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

func _physics_process(_delta: float) -> void:
	if not is_hired:
		return

	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Busca por monstros próximos no raio de 220 pixels
	var closest_enemy := _find_closest_enemy()

	if is_instance_valid(closest_enemy):
		var dist_to_enemy: float = global_position.distance_to(closest_enemy.global_position)
		var dir_to_enemy: Vector2 = (closest_enemy.global_position - global_position).normalized()

		if dist_to_enemy <= attack_range:
			# Alcance de golpe! Ataca se a recarga de 1.0s estiver pronta
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
			# Avança rapidamente em direção ao inimigo
			velocity = dir_to_enemy * (follow_speed * 1.15)
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(dir_to_enemy.x) > 0.05:
					animated_sprite.flip_h = dir_to_enemy.x < 0.0
	elif is_instance_valid(target_player):
		# Sem inimigos por perto: acompanha o Rei
		var distance: float = global_position.distance_to(target_player.global_position)

		# Ponto de escolta ligeiramente ao lado/atrás do Rei
		var target_pos := target_player.global_position
		if target_player.velocity.length() > 20.0:
			target_pos -= target_player.velocity.normalized() * 55.0

		var to_target := target_pos - global_position

		if distance > 85.0:
			var direction: Vector2 = to_target.normalized() if to_target.length() > 0.0 else (target_player.global_position - global_position).normalized()
			velocity = direction * follow_speed
			move_and_slide()
			if animated_sprite:
				if animated_sprite.animation != "run":
					animated_sprite.play("run")
				if abs(direction.x) > 0.05:
					animated_sprite.flip_h = direction.x < 0.0
		elif distance < 45.0:
			# Recua ligeiramente se estiver colado no jogador
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
	SoundManager.play_slash()

	if animated_sprite:
		animated_sprite.play("attack")

	# Causa dano no inimigo
	if is_instance_valid(enemy) and enemy.has_method("take_damage"):
		var knock_dir := (enemy.global_position - global_position).normalized()
		enemy.take_damage(attack_damage, knock_dir)

	# Cooldown de 1.0 segundo entre os ataques
	if is_inside_tree():
		var timer := get_tree().create_timer(1.0)
		timer.timeout.connect(func(): can_attack = true)
	else:
		can_attack = true

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "attack":
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
			"Saudações, Majestade! Sou um guerreiro fiel e luto na linha de frente com minha espada. Deseja me contratar por 20 moedas de ouro? [Pressione E para Contratar / Afaste-se para Recusar]"
		]
		dialogue_box.start_dialogue(lines, npc_name)

		if not dialogue_box.dialogue_finished.is_connected(_on_hiring_dialogue_finished):
			dialogue_box.dialogue_finished.connect(_on_hiring_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		var lines: Array[String] = [
			"Minha lâmina está a serviço de Vossa Majestade! Nenhum invasor passará por nós."
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
				"Pela honra e pela coroa! Minha espada protegerá Vossa Majestade na linha de frente."
			]
			dialogue_box.start_dialogue(confirm_lines, npc_name)
	else:
		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var fail_lines: Array[String] = [
				"Você não possui as 20 moedas de ouro necessárias. Derrote monstros para juntar o ouro, Majestade!"
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
