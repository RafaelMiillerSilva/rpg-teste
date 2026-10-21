extends CharacterBody2D

## Recrutador Estático Permanente: Mestre Monge do Monastério.
## Permite recrutar continuamente novas unidades de ally_monk.tscn por 60 moedas.

@export var npc_name: String = "Mestre do Monastério"
@export var hiring_cost: int = 60
@export var spawn_offset: Vector2 = Vector2(0, 40)

var is_player_in_range: bool = false
const ALLY_SCENE: PackedScene = preload("res://scenes/ally_monk.tscn")

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
	# Recrutador permanente não sofre dano nem empurrão
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
		if "coins" in player:
			player.coins -= hiring_cost
			if player.has_signal("coins_changed"):
				player.coins_changed.emit(player.coins)

		SoundManager.play_coin()
		SoundManager.play_equip()
		_spawn_ally()

		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var confirm_lines: Array[String] = [
				"Contratação realizada! Mais um monge devoto foi enviado para integrar e curar seu esquadrão real."
			]
			dialogue_box.start_dialogue(confirm_lines, npc_name)
	else:
		SoundManager.play_denied()
		if dialogue_box and dialogue_box.has_method("start_dialogue"):
			var fail_lines: Array[String] = [
				"Você não possui as %d moedas necessárias. Derrote monstros para juntar mais ouro!" % hiring_cost
			]
			dialogue_box.start_dialogue(fail_lines, npc_name)

func _on_cancel_hiring() -> void:
	pass

func _spawn_ally() -> void:
	if not ALLY_SCENE:
		return
	var ally := ALLY_SCENE.instantiate() as CharacterBody2D
	ally.global_position = global_position + spawn_offset

	var world_scene := get_tree().current_scene
	var allies_container := world_scene.get_node_or_null("Allies") if world_scene else null
	if allies_container:
		allies_container.add_child(ally)
	elif world_scene:
		world_scene.add_child(ally)
	elif get_parent():
		get_parent().add_child(ally)

func _on_interaction_area_body_entered(_body: Node2D) -> void:
	is_player_in_range = false
	if interaction_label:
		interaction_label.visible = false

func _on_interaction_area_body_exited(_body: Node2D) -> void:
	is_player_in_range = false
	if interaction_label:
		interaction_label.visible = false
