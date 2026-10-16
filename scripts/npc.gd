extends CharacterBody2D

## Nome de exibição do NPC no diálogo.
@export var npc_name: String = "Monge Curandeiro"

## Custo para contratar o monge como seguidor.
@export var hiring_cost: int = 50

## Velocidade de caminhada do monge ao acompanhar o jogador.
@export var follow_speed: float = 190.0

var is_hired: bool = false
var is_healing: bool = false
var is_player_in_range: bool = false
var target_player: CharacterBody2D = null

@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_label: Label = $InteractionLabel
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var heal_timer: Timer = $HealTimer if has_node("HealTimer") else null

func _ready() -> void:
	add_to_group("npcs")
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

	if heal_timer:
		heal_timer.wait_time = 5.0
		heal_timer.timeout.connect(_on_heal_timer_timeout)

func _physics_process(_delta: float) -> void:
	if not is_hired:
		return

	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if is_healing:
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
			"Olá! Sou um monge curandeiro. Deseja me contratar por 50 moedas de ouro para acompanhá-lo em sua jornada? [Pressione E para Contratar / Afaste-se para Recusar]"
		]
		dialogue_box.start_dialogue(lines, npc_name)

		# Conecta para processar a resposta ao terminar a fala
		if not dialogue_box.dialogue_finished.is_connected(_on_hiring_dialogue_finished):
			dialogue_box.dialogue_finished.connect(_on_hiring_dialogue_finished, CONNECT_ONE_SHOT)
	else:
		var lines: Array[String] = [
			"Estou ao seu lado, nobre guerreiro! Minhas magias de cura restaurarão suas forças."
		]
		dialogue_box.start_dialogue(lines, npc_name)

func _on_hiring_dialogue_finished() -> void:
	# Se o jogador se afastou da área de interação, a contratação é recusada
	if not is_player_in_range:
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player):
		return

	var player_coins: int = player.coins if "coins" in player else 0

	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")

	if player_coins >= hiring_cost:
		# Contratação bem-sucedida!
		if "coins" in player:
			player.coins -= hiring_cost
			if player.has_signal("coins_changed"):
				player.coins_changed.emit(player.coins)

		is_hired = true
		target_player = player

		if heal_timer:
			heal_timer.start(5.0)

		SoundManager.play_coin()
		SoundManager.play_heal()

		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var confirm_lines: Array[String] = [
				"Contrato firmado! Minhas bênçãos e poções o acompanharão em cada batalha."
			]
			dialogue_box.start_dialogue(confirm_lines, npc_name)
	else:
		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var fail_lines: Array[String] = [
				"Você não possui as 50 moedas de ouro necessárias. Derrote mais monstros para juntar ouro!"
			]
			dialogue_box.start_dialogue(fail_lines, npc_name)

func _on_heal_timer_timeout() -> void:
	if not is_hired:
		return

	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if is_instance_valid(target_player):
		var current_hp: int = target_player.current_health if "current_health" in target_player else 100
		var max_hp: int = target_player.max_health if "max_health" in target_player else 100

		# Cura apenas se o jogador estiver vivo e ferido
		if current_hp > 0 and current_hp < max_hp:
			is_healing = true
			velocity = Vector2.ZERO
			if animated_sprite:
				animated_sprite.play("heal")
			if target_player.has_method("heal"):
				target_player.heal(10)
			SoundManager.play_heal()
			if target_player.has_method("trigger_heal_particles"):
				target_player.trigger_heal_particles()

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "heal":
		is_healing = false
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
