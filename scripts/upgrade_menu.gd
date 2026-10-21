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

# Dicionário de metadados das melhorias e recrutamento exclusivo por construção
const BUILDING_DATA: Dictionary = {
	"archery": {
		"title": "🏹 CAMPO DE TIRO - RECRUTAMENTO & MELHORIAS",
		"recruit": {
			"id": "recruit_archer",
			"name": "Arqueiro Real",
			"cost": 35,
			"desc": "Arqueiro de disparo rápido à distância. Dá suporte contínuo ao esquadrão.",
			"icon": "res://assets/ui/troops/icon_archer.png",
			"unit_name": "archer"
		},
		"upgrades": [
			{
				"id": "archer_damage",
				"name": "🎯 Flechas Perfurantes",
				"desc": "Aumenta o dano de cada flecha disparada pelos arqueiros aliados."
			},
			{
				"id": "archer_speed",
				"name": "⚡ Cadência de Tiro",
				"desc": "Permite que os arqueiros recarreguem e disparem flechas mais rápido."
			}
		]
	},
	"barracks": {
		"title": "⚔️ QUARTEL REAL - RECRUTAMENTO & MELHORIAS",
		"recruit": {
			"id": "recruit_warrior",
			"name": "Guerreiro Real",
			"cost": 30,
			"desc": "Infantaria de choque com espada e escudo. Bloqueia ataques e protege o Rei.",
			"icon": "res://assets/ui/troops/icon_warrior.png",
			"unit_name": "warrior"
		},
		"upgrades": [
			{
				"id": "warrior_damage",
				"name": "🗡️ Maestria da Espada",
				"desc": "Aumenta o dano do corte dos guerreiros da linha de frente."
			},
			{
				"id": "warrior_health",
				"name": "❤️ Vigor de Batalha",
				"desc": "Aumenta a resistência e vida máxima dos guerreiros."
			},
			{
				"id": "warrior_block",
				"name": "🛡️ Postura com Escudo",
				"desc": "Aumenta a chance de entrar em guarda para bloquear 50% de dano."
			}
		]
	},
	"castle": {
		"title": "🏰 CASTELO REAL - RECRUTAMENTO & COROA",
		"recruit": {
			"id": "recruit_lancer",
			"name": "Lanceiro Real",
			"cost": 45,
			"desc": "Lanceiro de elite com alcance estendido e dano perfurante concentrado.",
			"icon": "res://assets/ui/troops/icon_lancer.png",
			"unit_name": "lancer"
		},
		"upgrades": [
			{
				"id": "lancer_damage",
				"name": "🔱 Lança Real",
				"desc": "Aumenta o dano penetrante das estocadas do lanceiro de elite."
			},
			{
				"id": "king_armor",
				"name": "👑 Armadura Real do Rei",
				"desc": "Aumenta a armadura de absorção direta de dano do Rei."
			}
		]
	},
	"monastery": {
		"title": "✨ MONASTÉRIO SAGRADO - RECRUTAMENTO & BÊNÇÃOS",
		"recruit": {
			"id": "recruit_monk",
			"name": "Monge Curandeiro",
			"cost": 50,
			"desc": "Monge devoto que cura periodicamente as tropas mais feridas do esquadrão.",
			"icon": "res://assets/ui/troops/icon_monk.png",
			"unit_name": "monk"
		},
		"upgrades": [
			{
				"id": "monk_heal",
				"name": "💚 Prece Divina",
				"desc": "Intensifica a quantidade de vida restaurada pelo pulso de cura do monge."
			},
			{
				"id": "monk_targets",
				"name": "🌟 Bênção em Grupo",
				"desc": "Permite ao monge abençoar e curar +1 tropa ferida simultaneamente a cada pulso de oração."
			},
			{
				"id": "monk_range",
				"name": "🕊️ Aura Sagrada",
				"desc": "Expande o raio de alcance onde o monge consegue socorrer tropas aliadas."
			}
		]
	},
	"pawn_house": {
		"title": "🏠 CASA DOS PEÕES - RECRUTAMENTO & COLETA",
		"recruit": {
			"id": "pawn_recruit",
			"name": "Peão Coletor de Ouro",
			"cost": 1,
			"desc": "Ajudante leal imortal que corre pelo campo recolhendo moedas e entregando ao Rei.",
			"icon": "pawn",
			"unit_name": "pawn"
		},
		"upgrades": [
			{
				"id": "pawn_speed",
				"name": "👟 Agilidade do Peão",
				"desc": "Aumenta expressivamente a velocidade de corrida do coletor de moedas."
			},
			{
				"id": "pawn_capacity",
				"name": "💰 Bolsa de Ouro Reforçada",
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
	add_to_group("upgrade_menu")
	visible = false
	_ensure_nodes()

	if close_button:
		if not close_button.pressed.is_connected(close_menu):
			close_button.pressed.connect(close_menu)
		close_button.mouse_entered.connect(SoundManager.play_hover)

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
		if target_player:
			if target_player.has_method("freeze_player"):
				target_player.freeze_player()
			elif target_player.has_method("freeze"):
				target_player.freeze()
		get_tree().paused = true
	visible = true

	update_ui()

	if close_button and close_button.is_inside_tree():
		close_button.grab_focus()

func close_menu() -> void:
	is_open = false
	visible = false
	if is_inside_tree() and get_tree():
		if not is_instance_valid(target_player):
			target_player = get_tree().get_first_node_in_group("player")
		if target_player:
			if target_player.has_method("unfreeze_player"):
				target_player.unfreeze_player()
			elif target_player.has_method("unfreeze"):
				target_player.unfreeze()
		get_tree().paused = false

func _buy(type: String) -> void:
	if not is_instance_valid(target_player) and is_inside_tree() and get_tree():
		target_player = get_tree().get_first_node_in_group("player")

	if UpgradeManager.buy_upgrade(type, target_player):
		update_ui()
	else:
		SoundManager.play_denied()

func _get_troop_current_stats(unit_type: String) -> Dictionary:
	match unit_type:
		"warrior":
			var cur_hp: int = 280 + UpgradeManager.get_warrior_bonus_health()
			var cur_dmg: int = 40 + UpgradeManager.get_warrior_bonus_damage()
			var cur_arm: int = 5 + UpgradeManager.get_king_bonus_armor()
			var cur_block: int = int(clampf(0.40 + UpgradeManager.get_warrior_block_bonus(), 0.40, 0.80) * 100)
			return {
				"summary": "❤️ Vida atual: %d HP   |   🗡️ Dano atual: %d   |   🛡️ Armadura: %d   |   🛡️ Bloqueio: %d%%" % [cur_hp, cur_dmg, cur_arm, cur_block]
			}
		"archer":
			var cur_hp: int = 220 + UpgradeManager.get_warrior_bonus_health()
			var cur_dmg: int = 15 + UpgradeManager.get_archer_bonus_damage()
			var cur_cd: float = 0.70 * UpgradeManager.get_archer_cooldown_multiplier()
			return {
				"summary": "❤️ Vida atual: %d HP   |   🎯 Dano atual: %d   |   ⚡ Cadência: %.2fs   |   🏹 Alcance: 380px" % [cur_hp, cur_dmg, cur_cd]
			}
		"lancer":
			var cur_hp: int = 360 + UpgradeManager.get_warrior_bonus_health()
			var cur_dmg: int = 35 + UpgradeManager.get_lancer_bonus_damage()
			var cur_arm: int = 3 + UpgradeManager.get_king_bonus_armor()
			return {
				"summary": "❤️ Vida atual: %d HP   |   🔱 Dano atual: %d   |   🛡️ Armadura: %d   |   🔱 Perfuração: 150px" % [cur_hp, cur_dmg, cur_arm]
			}
		"monk":
			var cur_hp: int = 260 + UpgradeManager.get_warrior_bonus_health()
			var cur_heal: int = 20 + UpgradeManager.get_monk_bonus_heal()
			var cur_targets: int = 1 + UpgradeManager.get_monk_bonus_targets()
			var cur_range: int = 350 + int(UpgradeManager.get_monk_bonus_range())
			return {
				"summary": "❤️ Vida atual: %d HP   |   💚 Cura atual: %d HP   |   🌟 Alvos: %d   |   🕊️ Alcance: %dpx" % [cur_hp, cur_heal, cur_targets, cur_range]
			}
		"pawn":
			var cur_cap: int = UpgradeManager.get_pawn_max_capacity()
			var cur_spd: int = int(190.0 * UpgradeManager.get_pawn_speed_multiplier())
			return {
				"summary": "💰 Capacidade atual: %d Moedas   |   👟 Velocidade atual: %d   |   ✨ Imortal (Coleta Ouro)" % [cur_cap, cur_spd]
			}
		_:
			return {"summary": ""}

func _get_upgrade_current_stat_text(up_id: String) -> String:
	match up_id:
		"warrior_damage":
			var cur: int = 40 + UpgradeManager.get_warrior_bonus_damage()
			return "dano atual %d (+5) upgrade" % cur
		"warrior_health":
			var cur: int = 280 + UpgradeManager.get_warrior_bonus_health()
			return "vida atual %d HP (+35 HP) upgrade" % cur
		"warrior_block":
			var cur: int = int(clampf(0.40 + UpgradeManager.get_warrior_block_bonus(), 0.40, 0.80) * 100)
			return "chance de bloqueio atual %d%% (+10%%) upgrade" % cur
		"archer_damage":
			var cur: int = 15 + UpgradeManager.get_archer_bonus_damage()
			return "dano atual %d (+4) upgrade" % cur
		"archer_speed":
			var cur: float = 0.70 * UpgradeManager.get_archer_cooldown_multiplier()
			return "intervalo atual %.2fs (-12%%) upgrade" % cur
		"lancer_damage":
			var cur: int = 35 + UpgradeManager.get_lancer_bonus_damage()
			return "dano atual %d (+6) upgrade" % cur
		"king_armor":
			var cur: int = UpgradeManager.get_king_bonus_armor()
			if is_instance_valid(target_player) and target_player.has_method("get_total_armor"):
				cur = int(target_player.get_total_armor())
			return "armadura atual %d (+1) upgrade" % cur
		"monk_heal":
			var cur: int = 20 + UpgradeManager.get_monk_bonus_heal()
			return "cura atual %d HP (+8 HP) upgrade" % cur
		"monk_targets":
			var cur: int = 1 + UpgradeManager.get_monk_bonus_targets()
			return "alvos simultâneos atuais %d (+1) upgrade" % cur
		"monk_range":
			var cur: int = 350 + int(UpgradeManager.get_monk_bonus_range())
			return "alcance atual %dpx (+40px) upgrade" % cur
		"pawn_speed":
			var cur: int = int(190.0 * UpgradeManager.get_pawn_speed_multiplier())
			return "velocidade atual %d (+25%%) upgrade" % cur
		"pawn_capacity":
			var cur: int = UpgradeManager.get_pawn_max_capacity()
			return "capacidade atual %d moedas (+25) upgrade" % cur
		_:
			return ""

func _get_unit_count(unit_type: String) -> int:
	if not is_inside_tree() or not get_tree():
		return 0
	if unit_type == "pawn":
		return get_tree().get_nodes_in_group("pawns").size()
	var count := 0
	for ally in get_tree().get_nodes_in_group("allies"):
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			var u_name: String = str(ally.get("unit_display_name")).to_lower()
			if u_name == unit_type.to_lower():
				count += 1
	return count

func _create_recruit_card(recruit_data: Dictionary, coins: int) -> Control:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.20, 0.16, 0.11, 0.98)
	card_style.border_color = Color(0.92, 0.76, 0.28, 1.0) # Borda dourada nobre
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 16
	card_style.content_margin_top = 12
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)

	# 1. Ícone do Personagem à esquerda
	var icon_box := PanelContainer.new()
	var icon_box_style := StyleBoxFlat.new()
	icon_box_style.bg_color = Color(0.12, 0.09, 0.06, 0.95)
	icon_box_style.border_color = Color(0.85, 0.70, 0.30, 1.0)
	icon_box_style.set_border_width_all(2)
	icon_box_style.set_corner_radius_all(8)
	icon_box.add_theme_stylebox_override("panel", icon_box_style)
	icon_box.custom_minimum_size = Vector2(66, 66)

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(60, 60)

	var unit_type: String = recruit_data.get("unit_name", "")
	var icon_path: String = recruit_data.get("icon", "")
	if unit_type == "pawn" or icon_path == "pawn":
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/tiny_swords/Units/Blue Units/Pawn/Pawn_Idle.png")
		atlas.region = Rect2(0, 0, 192, 192)
		tex_rect.texture = atlas
	elif ResourceLoader.exists(icon_path):
		tex_rect.texture = load(icon_path)
	icon_box.add_child(tex_rect)
	hbox.add_child(icon_box)

	# 2. Informações e Atributos Atuais à Direita do Ícone
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)

	# Linha do Nome e Contagem no Exército
	var top_line := HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 10)

	var name_lbl := Label.new()
	name_lbl.text = "👑 " + recruit_data.get("name", "Tropa Real")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	top_line.add_child(name_lbl)

	var count := _get_unit_count(unit_type)
	var count_lbl := Label.new()
	if unit_type == "pawn":
		count_lbl.text = "• Contratado" if UpgradeManager.is_pawn_recruited() else "• Disponível"
		count_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5, 1.0) if UpgradeManager.is_pawn_recruited() else Color(0.7, 0.8, 0.9, 1.0))
	else:
		count_lbl.text = "• No Exército: %d" % count
		count_lbl.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0, 1.0))
	count_lbl.add_theme_font_size_override("font_size", 13)
	top_line.add_child(count_lbl)
	vbox.add_child(top_line)

	# Linha de Atributos Atuais da Tropa (destacada à direita do ícone)
	var stats_data := _get_troop_current_stats(unit_type)
	var stats_lbl := Label.new()
	stats_lbl.text = stats_data.get("summary", "")
	stats_lbl.add_theme_font_size_override("font_size", 13)
	stats_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75, 1.0))
	vbox.add_child(stats_lbl)

	# Linha de Descrição da Função
	var desc_lbl := Label.new()
	desc_lbl.text = recruit_data.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	vbox.add_child(desc_lbl)

	hbox.add_child(vbox)

	# 3. Botão de Recrutamento
	var cost: int = recruit_data.get("cost", 30)
	var is_pawn_already_bought: bool = (unit_type == "pawn" and UpgradeManager.is_pawn_recruited())
	var can_afford: bool = (coins >= cost and not is_pawn_already_bought)

	var buy_btn := Button.new()
	var btn_style := StyleBoxFlat.new()
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)

	if is_pawn_already_bought:
		buy_btn.text = "Contratado"
		buy_btn.disabled = true
		btn_style.bg_color = Color(0.18, 0.18, 0.18, 0.6)
		btn_style.border_color = Color(0.35, 0.35, 0.35, 0.5)
	else:
		buy_btn.text = "Recrutar (🪙 %d)" % cost
		buy_btn.disabled = not can_afford
		btn_style.bg_color = Color(0.20, 0.55, 0.25, 0.95) if can_afford else Color(0.2, 0.2, 0.2, 0.6)
		btn_style.border_color = Color(0.45, 0.90, 0.45, 1.0) if can_afford else Color(0.35, 0.35, 0.35, 0.6)

	buy_btn.custom_minimum_size = Vector2(160, 42)
	buy_btn.add_theme_stylebox_override("normal", btn_style)

	var recruit_id: String = recruit_data.get("id", "")
	buy_btn.mouse_entered.connect(SoundManager.play_hover)
	buy_btn.pressed.connect(func(): _buy(recruit_id))
	hbox.add_child(buy_btn)

	card.add_child(hbox)
	return card

func _create_upgrade_card(item_data: Dictionary, coins: int) -> Control:
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
	vbox.add_theme_constant_override("separation", 3)

	# Nome da melhoria
	var name_lbl := Label.new()
	name_lbl.text = up_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))
	vbox.add_child(name_lbl)

	# Atributo Atual com bônus: ex: "dano atual 30 (+5) upgrade"
	var stat_text := _get_upgrade_current_stat_text(up_id)
	if not stat_text.is_empty():
		var stat_lbl := Label.new()
		stat_lbl.text = stat_text
		stat_lbl.add_theme_font_size_override("font_size", 13)
		stat_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0, 1.0))
		vbox.add_child(stat_lbl)

	# Descrição da melhoria
	var desc_lbl := Label.new()
	desc_lbl.text = up_desc
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1.0))
	vbox.add_child(desc_lbl)

	hbox.add_child(vbox)

	var lvl_lbl := Label.new()
	lvl_lbl.text = "Nível %d" % lvl
	lvl_lbl.custom_minimum_size = Vector2(80, 0)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 1.0))
	hbox.add_child(lvl_lbl)

	var buy_btn := Button.new()
	var btn_style := StyleBoxFlat.new()
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(6)
	var can_afford: bool = (coins >= cost)
	buy_btn.text = "Melhorar (🪙 %d)" % cost
	buy_btn.disabled = not can_afford
	btn_style.bg_color = Color(0.22, 0.52, 0.25, 0.95) if can_afford else Color(0.2, 0.2, 0.2, 0.6)
	btn_style.border_color = Color(0.45, 0.85, 0.45, 1.0) if can_afford else Color(0.35, 0.35, 0.35, 0.6)

	buy_btn.custom_minimum_size = Vector2(150, 36)
	buy_btn.add_theme_stylebox_override("normal", btn_style)

	var captured_id: String = up_id
	buy_btn.mouse_entered.connect(SoundManager.play_hover)
	buy_btn.pressed.connect(func(): _buy(captured_id))
	hbox.add_child(buy_btn)

	card.add_child(hbox)
	return card

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

	# 1. Compra de Soldados em PRIMEIRO LUGAR na loja da construção
	if data.has("recruit"):
		var recruit_card := _create_recruit_card(data["recruit"], coins)
		upgrades_list.add_child(recruit_card)

		# Separador elegante entre o recrutamento e as melhorias
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 10)
		upgrades_list.add_child(sep)

	# 2. Melhorias da construção com os atributos atuais exibidos
	var upgrade_items: Array = data.get("upgrades", [])
	for item_data in upgrade_items:
		var up_card := _create_upgrade_card(item_data, coins)
		upgrades_list.add_child(up_card)
