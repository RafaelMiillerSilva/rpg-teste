class_name TroopRosterUI
extends Control

## Gerenciador do Roster de Tropas Recrutadas e Notificações de Combate:
## Organiza em colunas na esquerda os banners com sprite em idle completo e vida de cada tropa.
## Quanto mais tropas recrutadas, menor fica o tamanho dos slots e mais colunas são organizadas.
## Quando uma tropa morre, exibe notificação no topo com a fonte padrão e remove o banner.

const BANNER_CARD_SCENE: PackedScene = preload("res://scenes/troop_banner_card.tscn")
const DEFAULT_FONT: Font = preload("res://assets/font/AncientModernTales-a7Po.ttf")

@onready var roster_container: ScrollContainer = $RosterContainer
@onready var grid_container: GridContainer = $RosterContainer/GridContainer
@onready var notification_container: Control = $NotificationContainer
@onready var notification_label: Label = $NotificationContainer/NotificationLabel

var _cards_by_ally: Dictionary = {}
var _notification_tween: Tween = null
var _allies_container_ref: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_notification_label()
	_find_and_bind_allies_container()

func _setup_notification_label() -> void:
	if not notification_container:
		notification_container = get_node_or_null("NotificationContainer")
	if not notification_label:
		notification_label = get_node_or_null("NotificationContainer/NotificationLabel")

	if notification_container:
		notification_container.modulate.a = 0.0

	if notification_label:
		notification_label.add_theme_font_override("font", DEFAULT_FONT)
		notification_label.add_theme_font_size_override("font_size", 22)
		notification_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		notification_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		notification_label.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.04, 1.0))
		notification_label.add_theme_constant_override("shadow_offset_x", 1)
		notification_label.add_theme_constant_override("shadow_offset_y", 2)
		notification_label.add_theme_constant_override("outline_size", 4)

func _find_and_bind_allies_container() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var world_node: Node = tree.current_scene if (tree and tree.current_scene) else null
	if not world_node:
		world_node = get_parent()

	var allies_node: Node = null
	if world_node:
		allies_node = world_node.get_node_or_null("Allies")

	if not allies_node and is_inside_tree() and has_node("/root/World/Allies"):
		allies_node = get_node("/root/World/Allies")

	if allies_node:
		_allies_container_ref = allies_node
		if not allies_node.child_entered_tree.is_connected(_on_ally_node_added):
			allies_node.child_entered_tree.connect(_on_ally_node_added)
		if not allies_node.child_exiting_tree.is_connected(_on_ally_node_removed):
			allies_node.child_exiting_tree.connect(_on_ally_node_removed)

		for child in allies_node.get_children():
			_register_ally_deferred(child)

	# Também varre quaisquer aliados que já estejam no grupo "allies"
	if tree:
		for ally in tree.get_nodes_in_group("allies"):
			_register_ally_deferred(ally)

func _on_ally_node_added(node: Node) -> void:
	_register_ally_deferred(node)

func _register_ally_deferred(node: Node) -> void:
	call_deferred("_register_ally", node)

func _register_ally(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Node2D):
		return

	# Não registra o player nem unidades que não sejam tropas aliadas recrutadas
	if node.is_in_group("player") or node.name == "Player":
		return

	# Verifica se já está registrado
	if _cards_by_ally.has(node) and is_instance_valid(_cards_by_ally[node]):
		return

	# Aceita unidades do grupo "allies" ou que possuam o sinal "died"
	var is_ally: bool = node.is_in_group("allies") or node.has_signal("died")
	if not is_ally:
		return

	var unit_name: String = "Warrior"
	if node.get("unit_display_name") != null and str(node.get("unit_display_name")) != "":
		unit_name = str(node.get("unit_display_name"))
	elif "archer" in node.name.to_lower():
		unit_name = "Archer"
	elif "lancer" in node.name.to_lower():
		unit_name = "Lancer"
	elif "monk" in node.name.to_lower():
		unit_name = "Monk"

	if not grid_container:
		grid_container = get_node_or_null("RosterContainer/GridContainer")
	if not grid_container:
		return

	var card := BANNER_CARD_SCENE.instantiate() as TroopBannerCard
	grid_container.add_child(card)
	card.setup(node, unit_name)

	_cards_by_ally[node] = card

	# Conecta o sinal de morte da tropa
	if node.has_signal("died"):
		if not node.died.is_connected(_on_ally_died):
			node.died.connect(_on_ally_died)
	else:
		# Fallback se a tropa sair da árvore
		if not node.tree_exiting.is_connected(_on_fallback_ally_exiting.bind(node, unit_name)):
			node.tree_exiting.connect(_on_fallback_ally_exiting.bind(node, unit_name))

	# Recalcula e adapta o tamanho dos slots conforme o número de tropas cresce
	_update_roster_layout()

func _on_ally_died(ally_node: Node2D, unit_name: String) -> void:
	show_death_notification("%s morto em combate" % unit_name)

	if _cards_by_ally.has(ally_node):
		var card: TroopBannerCard = _cards_by_ally[ally_node]
		_cards_by_ally.erase(ally_node)
		if is_instance_valid(card):
			card.play_death_and_remove()
		_update_roster_layout()

func _on_fallback_ally_exiting(ally_node: Node2D, unit_name: String) -> void:
	if _cards_by_ally.has(ally_node):
		var card: TroopBannerCard = _cards_by_ally[ally_node]
		_cards_by_ally.erase(ally_node)
		if is_instance_valid(card):
			card.play_death_and_remove()
		_update_roster_layout()

func _on_ally_node_removed(node: Node) -> void:
	if _cards_by_ally.has(node):
		var card: TroopBannerCard = _cards_by_ally[node]
		_cards_by_ally.erase(node)
		if is_instance_valid(card):
			card.play_death_and_remove()
		_update_roster_layout()

## Sistema dinâmico: quanto mais tropas recrutadas, menor fica o tamanho dos slots e mais colunas se adaptam
func _update_roster_layout() -> void:
	if not grid_container:
		grid_container = get_node_or_null("RosterContainer/GridContainer")
	if not roster_container:
		roster_container = get_node_or_null("RosterContainer")

	var active_count: int = _cards_by_ally.size()

	var card_size: Vector2
	var scale_factor: float
	var columns: int

	if active_count <= 2:
		# 1 a 2 tropas: tamanho grande e destacado
		card_size = Vector2(62, 74)
		scale_factor = 1.0
		columns = maxi(1, mini(active_count, 2))
	elif active_count <= 4:
		# 3 a 4 tropas: tamanho médio em 2 colunas
		card_size = Vector2(54, 66)
		scale_factor = 0.88
		columns = 2
	elif active_count <= 8:
		# 5 a 8 tropas: tamanho menor em 2 ou 3 colunas
		card_size = Vector2(46, 56)
		scale_factor = 0.74
		columns = 2 if active_count <= 6 else 3
	elif active_count <= 14:
		# 9 a 14 tropas: tamanho compacto em 3 colunas
		card_size = Vector2(38, 46)
		scale_factor = 0.60
		columns = 3
	else:
		# 15+ tropas: tamanho mini em 4 colunas para caber grande exército
		card_size = Vector2(32, 40)
		scale_factor = 0.50
		columns = 4

	if grid_container:
		grid_container.columns = columns
		var h_sep: int = maxi(3, int(round(6.0 * scale_factor)))
		var v_sep: int = maxi(3, int(round(6.0 * scale_factor)))
		grid_container.add_theme_constant_override("h_separation", h_sep)
		grid_container.add_theme_constant_override("v_separation", v_sep)

	if roster_container:
		# Expande a largura do container conforme o número de colunas
		var total_w: float = float(columns) * card_size.x + float(columns - 1) * 6.0 + 8.0
		roster_container.size.x = maxf(130.0, total_w)

	# Atualiza todos os cards ativos
	for ally in _cards_by_ally.keys():
		var card = _cards_by_ally[ally]
		if is_instance_valid(card) and card.has_method("apply_layout_size"):
			card.apply_layout_size(card_size, scale_factor)

## Exibe no topo da tela o aviso de tropa morta em combate usando a fonte padrão
func show_death_notification(message: String) -> void:
	if not notification_label:
		notification_label = get_node_or_null("NotificationContainer/NotificationLabel")
	if not notification_container:
		notification_container = get_node_or_null("NotificationContainer")
	if not notification_label or not notification_container:
		return

	notification_label.text = message

	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()

	notification_container.visible = true
	notification_container.modulate.a = 0.0
	notification_container.scale = Vector2(0.9, 0.9)
	notification_container.pivot_offset = notification_container.size * 0.5

	_notification_tween = create_tween()
	# 1. Fade-in suave e escala
	_notification_tween.parallel().tween_property(notification_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_notification_tween.parallel().tween_property(notification_container, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2. Permanece visível por 2.5 segundos
	_notification_tween.tween_interval(2.5)
	# 3. Fade-out elegante
	_notification_tween.tween_property(notification_container, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
