extends StaticBody2D

## Nome de exibição do NPC no diálogo.
@export var npc_name: String = "Guardião"

var is_player_in_range: bool = false
var quest_rewarded: bool = false

@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_label: Label = $InteractionLabel

func _ready() -> void:
	add_to_group("npcs")

	if interaction_label:
		interaction_label.visible = false

	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range:
		return

	# Checa se a caixa de diálogo já está ativa
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

	# Garante que o rótulo reapareça ao final do diálogo se o jogador ainda estiver perto
	if not dialogue_box.dialogue_finished.is_connected(_on_dialogue_finished):
		dialogue_box.dialogue_finished.connect(_on_dialogue_finished)

	# Verifica se ainda há inimigos vivos
	var enemies := get_tree().get_nodes_in_group("enemies")
	var living_enemies: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			living_enemies.append(e)

	if living_enemies.size() > 0:
		# Missão ativa: ainda existem monstros
		var lines: Array[String] = [
			"Olá, aventureiro!",
			"Monstros vermelhos invadiram a nossa sala.",
			"Por favor, derrote todos eles com sua espada!"
		]
		dialogue_box.start_dialogue(lines, npc_name)
	else:
		# Missão concluída: todos os monstros foram eliminados
		if not quest_rewarded:
			var lines: Array[String] = [
				"Incrível, você limpou a sala!",
				"Você é um verdadeiro herói. Tome 50 de vida como recompensa!"
			]
			dialogue_box.start_dialogue(lines, npc_name)
			if not dialogue_box.dialogue_finished.is_connected(_on_quest_reward_dialogue_finished):
				dialogue_box.dialogue_finished.connect(_on_quest_reward_dialogue_finished, CONNECT_ONE_SHOT)
		else:
			var lines: Array[String] = [
				"Obrigado por nos salvar!",
				"A sala está em paz e segura graças à sua bravura."
			]
			dialogue_box.start_dialogue(lines, npc_name)

func _on_quest_reward_dialogue_finished() -> void:
	quest_rewarded = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("heal"):
		player.heal(50)

func _on_dialogue_finished() -> void:
	if is_player_in_range and interaction_label:
		interaction_label.visible = true

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")
		if not (dialogue_box and dialogue_box.get("is_active")):
			interaction_label.visible = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		interaction_label.visible = false
