extends CharacterBody2D

## Recrutador Estático da Casa dos Peões.
## Permite recrutar o Peão Coletor de Ouro por 1 moeda de ouro.

@export var npc_name: String = "Mestre dos Peões"
@export var hiring_cost: int = 1
@export var spawn_offset: Vector2 = Vector2(30, 25)

var is_player_in_range: bool = false
const PAWN_GOLD_SCENE: PackedScene = preload("res://scenes/pawn_gold.tscn")

@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var interaction_label: Label = get_node_or_null("InteractionLabel")
@export var health: int = 9999
@export var max_health: int = 9999

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("npcs")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	y_sort_enabled = true

	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").disabled = true

	if animated_sprite:
		animated_sprite.play("idle")

	if interaction_label:
		interaction_label.visible = false

	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false

func take_damage(_amount: int = 0, _knockback: Vector2 = Vector2.ZERO, _attacker = null) -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	# Diálogo desativado por enquanto (compra de tropas feita exclusivamente nas construções)
	return

func trigger_dialogue() -> void:
	# Diálogo desativado por enquanto (compra de tropas feita exclusivamente nas construções)
	return

func _on_confirm_hiring() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not is_instance_valid(player):
		return

	var player_coins: int = player.coins if "coins" in player else 0
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")

	if player_coins >= hiring_cost:
		player.coins -= hiring_cost
		if player.has_signal("coins_changed"):
			player.coins_changed.emit(player.coins)

		UpgradeManager.pawn_recruited = true
		SoundManager.play_coin()
		SoundManager.play_equip()
		_spawn_pawn()

		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var confirm_lines: Array[String] = [
				"Contratação realizada! Vosso Peão Coletor de Ouro começou os trabalhos e já está caçando moedas pelo reino! Aprimore suas habilidades na Casa dos Peões logo ao lado."
			]
			dialogue_box.start_dialogue(confirm_lines, npc_name)
	else:
		SoundManager.play_denied()
		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var fail_lines: Array[String] = [
				"Majestade, precisais de pelo menos %d moeda de ouro para contratar o Peão Coletor!" % hiring_cost
			]
			dialogue_box.start_dialogue(fail_lines, npc_name)

func _on_cancel_hiring() -> void:
	pass

func _spawn_pawn() -> void:
	if not PAWN_GOLD_SCENE:
		return
	var pawn := PAWN_GOLD_SCENE.instantiate() as CharacterBody2D
	pawn.global_position = global_position + spawn_offset

	var world_scene := get_tree().current_scene
	var helpers_container := world_scene.get_node_or_null("Allies") if world_scene else null
	if helpers_container:
		helpers_container.add_child(pawn)
	elif world_scene:
		world_scene.add_child(pawn)
	elif get_parent():
		get_parent().add_child(pawn)

func _on_interaction_area_body_entered(_body: Node2D) -> void:
	is_player_in_range = false
	if interaction_label:
		interaction_label.visible = false

func _on_interaction_area_body_exited(_body: Node2D) -> void:
	is_player_in_range = false
	if interaction_label:
		interaction_label.visible = false
