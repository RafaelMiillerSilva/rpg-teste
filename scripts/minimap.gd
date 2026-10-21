class_name Minimap
extends Control

## Minimapa Tático em Tempo Real no HUD.
## Plota proporcionalmente em escala 1:50 (mapa 8000x6000 para moldura 160x120):
## - Pontos Verdes: O Rei (com coroa) e todas as tropas aliadas contratadas.
## - Pontos Vermelhos: Todos os goblins invasores (com destaque maior para o Gigante).
## - Pontos Amarelos: Moedas de ouro espalhadas pelo chão do mapa.
## - Pontos Azuis: Peão Coletor de Ouro.

const MAP_WIDTH: float = 8000.0
const MAP_HEIGHT: float = 6000.0
const SCALE_X: float = 160.0 / MAP_WIDTH   # 0.02 (1 / 50)
const SCALE_Y: float = 120.0 / MAP_HEIGHT  # 0.02 (1 / 50)

func _ready() -> void:
	custom_minimum_size = Vector2(160, 120)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# 1. Fundo escuro translúcido com moldura dourada real
	var bg_rect := Rect2(0, 0, 160, 120)
	draw_rect(bg_rect, Color(0.06, 0.06, 0.09, 0.82), true)
	draw_rect(bg_rect, Color(0.85, 0.72, 0.32, 0.9), false, 2.0)

	# Linhas sutis dos limites da Vila (centro aproximado 3000..5000 X, 2400..3800 Y)
	var village_rect := Rect2(3000.0 * SCALE_X, 2400.0 * SCALE_Y, 2000.0 * SCALE_X, 1400.0 * SCALE_Y)
	draw_rect(village_rect, Color(0.4, 0.45, 0.55, 0.25), false, 1.0)

	# 2. Pontos Amarelos: Moedas de Ouro no chão
	var coins := get_tree().get_nodes_in_group("coins")
	for coin in coins:
		if is_instance_valid(coin) and coin.is_inside_tree() and not coin.is_queued_for_deletion():
			var mpos := Vector2(coin.global_position.x * SCALE_X, coin.global_position.y * SCALE_Y)
			if bg_rect.has_point(mpos):
				draw_circle(mpos, 1.8, Color(1.0, 0.88, 0.25, 0.95))

	# 3. Pontos Vermelhos: Todos os Goblins Invasores
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_queued_for_deletion():
			if "is_dead" in enemy and enemy.is_dead:
				continue
			var mpos := Vector2(enemy.global_position.x * SCALE_X, enemy.global_position.y * SCALE_Y)
			if bg_rect.has_point(mpos):
				var is_giant: bool = ("goblin_type_name" in enemy and enemy.goblin_type_name == "giant")
				var is_king: bool = ("goblin_type_name" in enemy and enemy.goblin_type_name == "king")
				var is_mage: bool = ("goblin_type_name" in enemy and enemy.goblin_type_name == "mage")
				if is_king:
					draw_circle(mpos, 5.5, Color(1.0, 0.12, 0.12, 1.0))
					draw_arc(mpos, 7.5, 0, TAU, 14, Color(1.0, 0.85, 0.2, 0.9), 1.5)
				elif is_giant:
					draw_circle(mpos, 4.5, Color(1.0, 0.15, 0.15, 1.0))
					draw_arc(mpos, 6.0, 0, TAU, 12, Color(1.0, 0.6, 0.2, 0.8), 1.0)
				elif is_mage:
					draw_circle(mpos, 3.2, Color(1.0, 0.45, 0.15, 1.0))
					draw_arc(mpos, 4.5, 0, TAU, 8, Color(1.0, 0.2, 0.1, 0.6), 1.0)
				else:
					draw_circle(mpos, 2.6, Color(0.95, 0.22, 0.22, 0.95))

	# 4. Pontos Azuis: Peão Coletor de Ouro
	var pawns := get_tree().get_nodes_in_group("pawns")
	for pawn in pawns:
		if is_instance_valid(pawn) and pawn.is_inside_tree() and (pawn.is_in_group("helpers") or "carried_coins" in pawn):
			var mpos := Vector2(pawn.global_position.x * SCALE_X, pawn.global_position.y * SCALE_Y)
			if bg_rect.has_point(mpos):
				draw_circle(mpos, 2.8, Color(0.3, 0.75, 1.0, 1.0))

	# 5. Pontos Verdes: Tropas Aliadas Contratadas
	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and ally.is_inside_tree() and not ally.is_queued_for_deletion():
			if "is_dead" in ally and ally.is_dead:
				continue
			var mpos := Vector2(ally.global_position.x * SCALE_X, ally.global_position.y * SCALE_Y)
			if bg_rect.has_point(mpos):
				draw_circle(mpos, 2.8, Color(0.28, 0.85, 0.38, 1.0))

	# 6. Ponto Verde Maior com Coroa: O Rei (Jogador)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and player.is_inside_tree():
		var ppos := Vector2(player.global_position.x * SCALE_X, player.global_position.y * SCALE_Y)
		if bg_rect.has_point(ppos):
			draw_circle(ppos, 3.8, Color(0.2, 1.0, 0.35, 1.0))
			draw_arc(ppos, 5.5, 0, TAU, 12, Color(1.0, 0.9, 0.3, 0.9), 1.2)
