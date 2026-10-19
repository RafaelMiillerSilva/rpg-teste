extends CanvasLayer

const UpgradeManager = preload("res://scripts/upgrade_manager.gd")

## Menu de Upgrades por Construção com Pausa no Jogo.
## Exibe apenas as melhorias exclusivas da construção com a qual o jogador interagiu:
## - Archery: Dano de flechas e velocidade de disparo.
## - Barracks: Dano de espada, vida e chance de bloqueio.
## - Castle: Dano do lanceiro e armadura real do Rei.
## - Monastery: Potência de cura e alcance da bênção.
## - Pawn House: Velocidade de corrida e capacidade da bolsa do Peão Coletor.

@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var gold_label: Label = find_child("GoldLabel", true, false) as Label
@onready var close_button: Button = find_child("CloseButton", true, false) as Button
@onready var upgrades_list: VBoxContainer = find_child("UpgradesList", true, false) as VBoxContainer

var is_open: bool = false
var target_player: Node = null
var current_building: String = "castle"

# Dicionário de metadados das melhorias por construção
const BUILDING_DATA: Dictionary = {
	"archery": {
		"title": "🏹 CAMPO DE TIRO - MELHORIAS DO ARQUEIRO",
		"upgrades": [
			{
				"id": "archer_damage",
				"name": "🎯 Flechas Perfurantes (+4 Dano)",
				"desc": "Aumenta o dano de cada flecha disparada pelos arqueiros aliados."
			},
			{
				"id": "archer_speed",
				"name": "⚡ Cadência de Tiro (-12% Intervalo)",
				"desc": "Permite que os arqueiros recarreguem e disparem flechas mais rápido."
			}
		]
	},
	"barracks": {
		"title": "⚔️ QUARTEL REAL - MELHORIAS DO GUERREIRO",
		"upgrades": [
			{
				"id": "warrior_damage",
				"name": "🗡️ Maestria da Espada (+5 Dano)",
				"desc": "Aumenta o dano do corte dos guerreiros da linha de frente."
			},
			{
				"id": "warrior_health",
				"name": "❤️ Vigor de Batalha (+35 HP)",
				"desc": "Aumenta a resistência e vida máxima dos guerreiros."
			},
			{
				"id": "warrior_block",
				"name": "🛡️ Postura com Escudo (+10% Chance)",
				"desc": "Aumenta a chance de entrar em guarda para bloquear 50% de dano."
			}
		]
	},
	"castle": {
		"title": "🏰 CASTELO REAL - LANCEIRO & COROA",
		"upgrades": [
			{
				"id": "lancer_damage",
				"name": "🔱 Lança Real (+6 Dano)",
				"desc": "Aumenta o dano penetrante das estocadas do lanceiro de elite."
			},
			{
				"id": "king_armor",
				"name": "👑 Armadura Real (+1 Redução)",
				"desc": "Aumenta a armadura de absorção direta de dano do Rei."
			}
		]
	},
	"monastery": {
		"title": "✨ MONASTÉRIO SAGRADO - BÊNÇÃOS DO MONGE",
		"upgrades": [
			{
				"id": "monk_heal",
				"name": "💚 Prece Divina (+8 HP por Cura)",
				"desc": "Intensifica a quantidade de vida restaurada pelo pulso de cura do monge."
			},
			{
				"id": "monk_targets",
				"name": "🌟 Bênção em Grupo (+1 Alvo por Cura)",
				"desc": "Permite ao monge abençoar e curar +1 tropa ferida simultaneamente a cada pulso de oração."
			},
			{
				"id": "monk_range",
				"name": "🕊️ Aura Sagrada (+40px Alcance)",
				"desc": "Expande o raio de alcance onde o monge consegue socorrer tropas aliadas."
			}
		]
	},
	"pawn_house": {
		"title": "🏠 CASA DOS PEÕES - COLETOR DE OURO",
		"upgrades": [
			{
				"id": "pawn_recruit",
				"name": "👑 Recrutar Peão Coletor (Único)",
				"desc": "Contrata o peão leal para correr pelo campo recolhendo ouro automaticamente por 1 moeda."
			},
			{
				"id": "pawn_speed",
				"name": "👟 Agilidade do Peão (+25% Velocidade)",
				"desc": "Aumenta expressivamente a velocidade de corrida do coletor de moedas."
			},
			{
				"id": "pawn_capacity",
				"name": "💰 Bolsa de Ouro Reforçada (+25 Capacidade)",
				"desc": "Aumenta o limite de moedas carregadas antes de entregar ao Rei."
			}
		]
	}
}

func _ensure_nodes() -> void:
	if not title_label:
		title_label = find_child("TitleLabel", true, false) as Label
	if not gold_label:
		gold_label = find_child("GoldLabel", true, false) as Label
	if not close_button:
		close_button = find_child("CloseButton", true, false) as Button
	if not upgrades_list:
		upgrades_list = find_child("UpgradesList", true, false) as VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ensure_nodes()

	if close_button and not close_button.pressed.is_connected(close_menu):
		close_button.pressed.connect(close_menu)

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_ESCAPE)):
		close_menu()
		get_viewport().set_input_as_handled()

func open_menu(building_type: String = "castle") -> void:
	_ensure_nodes()
	current_building = building_type
	if not BUILDING_DATA.has(current_building):
		current_building = "castle"

	is_open = true
	if is_inside_tree() and get_tree():
		target_player = get_tree().get_first_node_in_group("player")
		get_tree().paused = true
	visible = true

	update_ui()

	if close_button and close_button.is_inside_tree():
		close_button.grab_focus()

func close_menu() -> void:
	is_open = false
	visible = false
	if is_inside_tree() and get_tree():
		get_tree().paused = false

func _buy(type: String) -> void:
	if not is_instance_valid(target_player) and is_inside_tree() and get_tree():
		target_player = get_tree().get_first_node_in_group("player")

	if UpgradeManager.buy_upgrade(type, target_player):
		update_ui()
	else:
		SoundManager.play_hit()

func update_ui() -> void:
	_ensure_nodes()
	if not is_instance_valid(target_player) and is_inside_tree() and get_tree():
		target_player = get_tree().get_first_node_in_group("player")

	var coins: int = target_player.coins if is_instance_valid(target_player) and "coins" in target_player else 0
	if gold_label:
		gold_label.text = "Tesouro Real: 🪙 %d Moedas de Ouro" % coins

	var data: Dictionary = BUILDING_DATA.get(current_building, BUILDING_DATA["castle"])
	if title_label:
		title_label.text = data.get("title", "🏛️ MELHORIAS DA CONSTRUÇÃO")

	if not upgrades_list:
		return

	# Limpa nós existentes na lista para construir os itens da construção atual
	for child in upgrades_list.get_children():
		upgrades_list.remove_child(child)
		child.queue_free()

	var upgrade_items: Array = data.get("upgrades", [])
	for item_data in upgrade_items:
		var up_id: String = item_data["id"]
		var up_name: String = item_data["name"]
		var up_desc: String = item_data["desc"]

		var lvl: int = UpgradeManager.get_level(up_id)
		var cost: int = UpgradeManager.get_cost(up_id)

		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.16, 0.13, 0.10, 0.95)
		card_style.border_color = Color(0.55, 0.42, 0.22, 1.0)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(8)
		card_style.content_margin_left = 16
		card_style.content_margin_top = 10
		card_style.content_margin_right = 16
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = up_name
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = up_desc
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))
		vbox.add_child(desc_lbl)

		hbox.add_child(vbox)

		var is_pawn_recruited: bool = (lvl > 0)

		var lvl_lbl := Label.new()
		if up_id == "pawn_recruit":
			lvl_lbl.text = "Ativo" if is_pawn_recruited else "Disponível"
		else:
			lvl_lbl.text = "Nível %d" % lvl
		lvl_lbl.custom_minimum_size = Vector2(80, 0)
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_lbl.add_theme_font_size_override("font_size", 13)
		lvl_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5, 1.0) if (up_id == "pawn_recruit" and is_pawn_recruited) else Color(0.5, 0.85, 1.0, 1.0))
		hbox.add_child(lvl_lbl)

		var buy_btn := Button.new()
		var btn_style := StyleBoxFlat.new()
		btn_style.set_border_width_all(1)
		btn_style.set_corner_radius_all(6)

		if up_id == "pawn_recruit":
			if is_pawn_recruited:
				buy_btn.text = "Recrutado ✓"
				buy_btn.disabled = true
				btn_style.bg_color = Color(0.18, 0.28, 0.18, 0.6)
				btn_style.border_color = Color(0.3, 0.6, 0.3, 0.6)
			else:
				buy_btn.text = "Recrutar (🪙 %d)" % cost
				buy_btn.disabled = (coins < cost)
				btn_style.bg_color = Color(0.22, 0.52, 0.25, 0.95) if coins >= cost else Color(0.2, 0.2, 0.2, 0.6)
				btn_style.border_color = Color(0.45, 0.85, 0.45, 1.0) if coins >= cost else Color(0.35, 0.35, 0.35, 0.6)
		else:
			buy_btn.text = "Melhorar (🪙 %d)" % cost
			buy_btn.disabled = (coins < cost)
			btn_style.bg_color = Color(0.22, 0.52, 0.25, 0.95) if coins >= cost else Color(0.2, 0.2, 0.2, 0.6)
			btn_style.border_color = Color(0.45, 0.85, 0.45, 1.0) if coins >= cost else Color(0.35, 0.35, 0.35, 0.6)

		buy_btn.custom_minimum_size = Vector2(150, 36)
		buy_btn.add_theme_stylebox_override("normal", btn_style)

		var captured_id: String = up_id
		buy_btn.pressed.connect(func(): _buy(captured_id))
		hbox.add_child(buy_btn)

		card.add_child(hbox)
		upgrades_list.add_child(card)
