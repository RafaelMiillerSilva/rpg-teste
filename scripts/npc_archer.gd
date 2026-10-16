extends CharacterBody2D

## Nome de exibição do arqueiro aliado no diálogo.
@export var npc_name: String = "Mestre Arqueiro"

## Custo para contratar o arqueiro como aliado.
@export var hiring_cost: int = 80

## Velocidade de caminhada ao seguir o jogador.
@export var follow_speed: float = 205.0

## Alcance máximo para detectar e atirar em monstros.
@export var attack_range: float = 380.0

## Velocidade da flecha aliada (alta velocidade).
@export var arrow_speed: float = 550.0

## Dano da flecha aliada.
@export var arrow_damage: int = 15

var is_hired: bool = false
var is_shooting: bool = false
var is_player_in_range: bool = false
var target_player: CharacterBody2D = null

const ARROW_SCENE: PackedScene = preload("res://scenes/arrow.tscn")

@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_label: Label = $InteractionLabel
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var shoot_timer: Timer = $ShootTimer if has_node("ShootTimer") else null

func _ready() -> void:
	add_to_group("npcs")
	add_to_group("allies")
	collision_layer = 4
	collision_mask = 1

	if animated_sprite:
		animated_sprite.play("idle")
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)

	if interaction_label:
		interaction_label.visible = false

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

	if shoot_timer:
		shoot_timer.wait_time = 0.7
		shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _physics_process(_delta: float) -> void:
	if not is_hired:
		return

	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	# Se estiver executando a animação de tiro rápido, para para disparar
	if is_shooting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_instance_valid(target_player):
		var distance: float = global_position.distance_to(target_player.global_position)

		# Ponto de acompanhamento: quando o jogador anda, mira logo atrás dos passos do herói
		var target_pos := target_player.global_position
		if target_player.velocity.length() > 20.0:
			target_pos -= target_player.velocity.normalized() * 60.0

		var to_target := target_pos - global_position

		if distance > 100.0:
			var direction: Vector2 = to_target.normalized() if to_target.length() > 0.0 else (target_player.global_position - global_position).normalized()
			velocity = direction * follow_speed
			move_and_slide()
			if animated_sprite:
				animated_sprite.play("run")
				if abs(direction.x) > 0.1:
					animated_sprite.flip_h = direction.x < 0.0
		elif distance < 50.0:
			# Se o jogador se aproximar muito, recua suavemente para liberar espaço
			var repulse_dir: Vector2 = (global_position - target_player.global_position).normalized()
			if repulse_dir == Vector2.ZERO:
				repulse_dir = Vector2.DOWN
			velocity = repulse_dir * (follow_speed * 0.6)
			move_and_slide()
			if animated_sprite:
				animated_sprite.play("run")
				if abs(repulse_dir.x) > 0.1:
					animated_sprite.flip_h = repulse_dir.x < 0.0
		else:
			velocity = Vector2.ZERO
			move_and_slide()
			if animated_sprite:
				animated_sprite.play("idle")


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
			"Olá! Sou um mestre arqueiro. Deseja me contratar por 80 moedas de ouro para cobrir suas costas com tiros rápidos? [E para Contratar / Afaste-se para Recusar]"
		]
		dialogue_box.start_dialogue(lines, npc_name)

		if not dialogue_box.dialogue_finished.is_connected(_on_hiring_dialogue_finished):
			dialogue_box.dialogue_finished.connect(_on_hiring_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		var lines: Array[String] = [
			"Minhas flechas cobrirão seu avanço! Nenhum monstro escapará da minha mira."
		]
		dialogue_box.start_dialogue(lines, npc_name)

func _on_hiring_dialogue_finished() -> void:
	# Se o jogador se afastou da área do NPC, a contratação é cancelada
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

		if shoot_timer:
			shoot_timer.start(0.7)

		SoundManager.play_coin()

		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var confirm_lines: Array[String] = [
				"Contrato firmado! Minhas flechas rápidas cobrirão suas costas em cada batalha."
			]
			dialogue_box.start_dialogue(confirm_lines, npc_name)
	else:
		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var fail_lines: Array[String] = [
				"Você não possui as 80 moedas de ouro necessárias. Derrote mais monstros para juntar o ouro!"
			]
			dialogue_box.start_dialogue(fail_lines, npc_name)

## Cadência rápida de tiro: a cada 0.7 segundos dispara contra o inimigo mais próximo no raio de 380px
func _on_shoot_timer_timeout() -> void:
	if not is_hired:
		return

	var target_enemy := _find_closest_enemy()
	if not is_instance_valid(target_enemy):
		return

	_shoot_at_enemy(target_enemy)

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

func _shoot_at_enemy(enemy_node: Node2D) -> void:
	if not is_instance_valid(enemy_node):
		return

	is_shooting = true
	velocity = Vector2.ZERO

	var dir: Vector2 = (enemy_node.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	if animated_sprite:
		animated_sprite.flip_h = dir.x < 0.0
		animated_sprite.play("shoot")

	if ARROW_SCENE:
		var arrow := ARROW_SCENE.instantiate()
		arrow.global_position = global_position + dir * 20.0
		arrow.direction = dir
		arrow.speed = arrow_speed
		arrow.damage = arrow_damage
		arrow.is_player_ally = true

		var scene_root := get_tree().current_scene
		if scene_root:
			scene_root.add_child(arrow)
		elif get_parent():
			get_parent().add_child(arrow)

	SoundManager.play_hit()

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "shoot":
		is_shooting = false
		if is_hired and is_instance_valid(target_player) and global_position.distance_to(target_player.global_position) > 90.0:
			animated_sprite.play("run")
		else:
			animated_sprite.play("idle")

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")
		if not (dialogue_box and dialogue_box.get("is_active")) and interaction_label:
			interaction_label.visible = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		if interaction_label:
			interaction_label.visible = false
