extends Area2D

## Área de Interação das Construções para Abrir o Menu de Upgrades Específico.
## Exibe "[E] Melhorias" e abre a loja exclusiva daquela construção com pausa do jogo ao pressionar E.

@export var building_type: String = "castle" # "archery", "barracks", "castle", "monastery", "pawn_house"

var is_player_in_range: bool = false
@onready var interaction_label: Label = $InteractionLabel if has_node("InteractionLabel") else null

func _ready() -> void:
	if interaction_label:
		interaction_label.visible = false
		_setup_label_text()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _setup_label_text() -> void:
	if not interaction_label:
		return
	match building_type:
		"archery":
			interaction_label.text = "[E] Campo de Tiro"
		"barracks":
			interaction_label.text = "[E] Quartel Real"
		"castle":
			interaction_label.text = "[E] Castelo Real"
		"monastery":
			interaction_label.text = "[E] Monastério"
		"pawn_house":
			interaction_label.text = "[E] Casa dos Peões"
		_:
			interaction_label.text = "[E] Melhorias"

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range:
		return

	# Não abre se estiver em diálogo ou com menu de pausa aberto
	var dialogue_box := get_tree().get_first_node_in_group("dialogue_box")
	if dialogue_box and dialogue_box.get("is_active"):
		return

	var upgrade_menu := get_tree().get_first_node_in_group("upgrade_menu")
	if upgrade_menu and upgrade_menu.get("is_open"):
		return

	var pressed_e := false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		pressed_e = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pressed_e = true

	if pressed_e:
		get_viewport().set_input_as_handled()
		if upgrade_menu and upgrade_menu.has_method("open_menu"):
			SoundManager.play_coin()
			upgrade_menu.open_menu(building_type)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		if interaction_label:
			interaction_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		if interaction_label:
			interaction_label.visible = false
