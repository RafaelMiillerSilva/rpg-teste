extends Node2D

static var auto_load_save_on_start: bool = false

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const ENEMY_ARCHER_SCENE: PackedScene = preload("res://scenes/enemy_archer.tscn")
const BASE_ENEMIES_TURN_1: int = 3
const TURN_MULTIPLIER: float = 1.4

## Controle do sistema de turnos (ondas de inimigos)
var current_turn: int = 0
var is_turn_active: bool = false
var enemies_alive: int = 0


@onready var player: CharacterBody2D = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var tilemap_layer: TileMapLayer = $TileMapLayer if has_node("TileMapLayer") else null
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar
@onready var health_text: Label = $CanvasLayer/HealthBar.get_node_or_null("HealthText")
@onready var coins_label: Label = $CanvasLayer/CoinsLabel
@onready var potions_label: Label = $CanvasLayer/PotionsLabel
@onready var save_label: Label = $CanvasLayer/SaveNotificationLabel
@onready var turn_label: Label = $CanvasLayer/TurnLabel
@onready var enemies_count_label: Label = $CanvasLayer/EnemiesCountLabel
@onready var turn_banner_label: Label = $CanvasLayer/TurnBannerLabel
@onready var gate_north: Marker2D = $GateNorth if has_node("GateNorth") else null
@onready var gate_south: Marker2D = $GateSouth if has_node("GateSouth") else null
@onready var gate_west: Marker2D = $GateWest if has_node("GateWest") else null
@onready var gate_east: Marker2D = $GateEast if has_node("GateEast") else null

var _save_tween: Tween
var _banner_tween: Tween

func _ready() -> void:
	_setup_tilemap_floor()

	if save_label:
		save_label.visible = false
	if turn_banner_label:
		turn_banner_label.visible = false

	if player:
		if health_bar:
			player.health_changed.connect(_on_player_health_changed)
			health_bar.max_value = player.max_health
			health_bar.value = player.current_health
			_update_health_display(player.current_health, player.max_health)

		if coins_label:
			player.coins_changed.connect(_on_player_coins_changed)
			_on_player_coins_changed(player.coins)

		if potions_label:
			player.potions_changed.connect(_on_player_potions_changed)
			_on_player_potions_changed(player.potions)

		if player.has_signal("game_saved") and save_label:
			player.game_saved.connect(_on_player_game_saved)

	if auto_load_save_on_start:
		auto_load_save_on_start = false
		call_deferred("_load_initial_save")

	# Inicia o primeiro turno de inimigos após um breve respiro de 1 segundo
	if is_inside_tree():
		var timer := get_tree().create_timer(1.0)
		timer.timeout.connect(func():
			if is_inside_tree():
				start_next_turn()
		)
	else:
		start_next_turn()

func _load_initial_save() -> void:
	if player and player.has_method("load_game"):
		player.load_game()

# ==============================================================================
# SISTEMA DE TURNOS (ONDAS DE INIMIGOS)
# ==============================================================================

## Calcula a quantidade de inimigos para um determinado turno com taxa 1.4x
func get_enemies_for_turn(turn: int) -> int:
	return maxi(1, int(round(float(BASE_ENEMIES_TURN_1) * pow(TURN_MULTIPLIER, turn - 1))))

func _setup_tilemap_floor() -> void:
	if not tilemap_layer:
		return
	for x in range(-5, 37):
		for y in range(-5, 29):
			tilemap_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))

## Retorna a posição do Marker2D do portão indicado
func _get_gate_position(side: int) -> Vector2:
	match side:
		0:
			return gate_north.global_position if gate_north else Vector2(1000.0, 140.0)
		1:
			return gate_south.global_position if gate_south else Vector2(1000.0, 1360.0)
		2:
			return gate_west.global_position if gate_west else Vector2(140.0, 750.0)
		3:
			return gate_east.global_position if gate_east else Vector2(1860.0, 750.0)
		_:
			return Vector2(1000.0, 140.0)

## Retorna o ponto inicial fora do mapa alinhado exatamente ao centro do portão
func _get_spawn_position_for_gate(side: int) -> Vector2:
	var gate_pos := _get_gate_position(side)
	match side:
		0: # Norte: acima do portão no mesmo eixo X exato
			return Vector2(gate_pos.x, -60.0)
		1: # Sul: abaixo do portão no mesmo eixo X exato
			return Vector2(gate_pos.x, 1560.0)
		2: # Oeste: à esquerda do portão no mesmo eixo Y exato
			return Vector2(-60.0, gate_pos.y)
		3: # Leste: à direita do portão no mesmo eixo Y exato
			return Vector2(2060.0, gate_pos.y)
		_:
			return Vector2(gate_pos.x, -60.0)

## Retrocompatibilidade para chamadas genéricas
func _get_spawn_and_gate() -> Dictionary:
	var side: int = randi() % 4
	return { "spawn_pos": _get_spawn_position_for_gate(side), "gate_pos": _get_gate_position(side) }

func _get_random_border_position() -> Vector2:
	return _get_spawn_and_gate()["spawn_pos"]

## Inicia o próximo turno com os inimigos marchando em filas retas pelos portões
func start_next_turn() -> void:
	current_turn += 1
	is_turn_active = true
	var total_enemies: int = get_enemies_for_turn(current_turn)
	enemies_alive = total_enemies

	_update_turn_hud()
	_show_banner("TURNO %d\n%d Inimigos Invasores!" % [current_turn, total_enemies], Color(1.0, 0.85, 0.2, 1.0))
	SoundManager.play_hit()

	# Determina os portões ativos para a invasão
	var num_active_gates: int = clampi(1 + int((current_turn - 1) / 2), 1, 4)
	var all_gates: Array[int] = [0, 1, 2, 3] # 0: Norte, 1: Sul, 2: Oeste, 3: Leste
	all_gates.shuffle()
	var active_gates: Array[int] = all_gates.slice(0, num_active_gates)

	# Distribui e despacha os inimigos em filas retas ritmadas
	for i in range(total_enemies):
		var gate_id: int = active_gates[i % active_gates.size()]
		var queue_index: int = int(i / active_gates.size())
		var spawn_delay: float = float(queue_index) * 0.7

		if spawn_delay > 0.0:
			var timer := get_tree().create_timer(spawn_delay)
			timer.timeout.connect(func():
				if is_inside_tree() and is_turn_active:
					_spawn_enemy_in_line(gate_id)
			)
		else:
			_spawn_enemy_in_line(gate_id)

func _spawn_enemy() -> void:
	_spawn_enemy_in_line(randi() % 4)

## Instancia um inimigo (guerreiro ou arqueiro) alinhado na fila do portão especificado
func _spawn_enemy_in_line(gate_id: int) -> void:
	if not enemies_container or not is_turn_active:
		return

	# Sorteia entre guerreiro vermelho (espada) e arqueiro vermelho (arco)
	var enemy_scene: PackedScene = ENEMY_SCENE
	if ENEMY_ARCHER_SCENE and randf() < 0.4:
		enemy_scene = ENEMY_ARCHER_SCENE

	if not enemy_scene:
		return

	var enemy := enemy_scene.instantiate() as CharacterBody2D
	if "turn" in enemy:
		enemy.turn = current_turn

	var gate_pos := _get_gate_position(gate_id)
	var spawn_pos := _get_spawn_position_for_gate(gate_id)

	enemy.global_position = spawn_pos
	if "gate_position" in enemy:
		enemy.gate_position = gate_pos

	enemies_container.add_child(enemy)

	# Monitora a eliminação do inimigo quando sair da árvore
	enemy.tree_exited.connect(_on_enemy_defeated)



func _on_enemy_defeated() -> void:
	if not is_turn_active:
		return

	enemies_alive = maxi(0, enemies_alive - 1)
	_update_turn_hud()

	# Se todos os inimigos do turno forem eliminados
	if enemies_alive == 0:
		_on_turn_completed()

func _on_turn_completed() -> void:
	is_turn_active = false
	SoundManager.play_coin()
	_show_banner("TURNO %d VENCIDO!\nPróximo turno se aproximando..." % current_turn, Color(0.35, 1.0, 0.5, 1.0))

	# Breve intervalo de 3.5 segundos para o jogador coletar itens antes do próximo turno
	if is_inside_tree():
		var cooldown_timer := get_tree().create_timer(3.5)
		cooldown_timer.timeout.connect(func():
			if is_inside_tree():
				start_next_turn()
		)

func _update_turn_hud() -> void:
	if turn_label:
		turn_label.text = "Turno: %d" % current_turn
	if enemies_count_label:
		enemies_count_label.text = "Inimigos: %d" % enemies_alive

func _show_banner(message: String, color: Color = Color.WHITE) -> void:
	if not turn_banner_label:
		return
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()

	turn_banner_label.text = message
	turn_banner_label.modulate = color
	turn_banner_label.modulate.a = 1.0
	turn_banner_label.visible = true

	_banner_tween = create_tween()
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(turn_banner_label, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(func(): turn_banner_label.visible = false)

# ==============================================================================
# CALLBACKS DO JOGADOR E HUD
# ==============================================================================

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current
	_update_health_display(current, max_hp)

func _update_health_display(current: int, max_hp: int) -> void:
	if health_text:
		health_text.text = "%d / %d" % [current, max_hp]

func _on_player_coins_changed(new_amount: int) -> void:
	if coins_label:
		coins_label.text = "Moedas: %d" % new_amount

func _on_player_potions_changed(new_amount: int) -> void:
	if potions_label:
		potions_label.text = "Poções [Q]: %d" % new_amount

func _on_player_game_saved() -> void:
	if not save_label:
		return
	if _save_tween and _save_tween.is_valid():
		_save_tween.kill()

	save_label.visible = true
	save_label.modulate.a = 1.0

	_save_tween = create_tween()
	_save_tween.tween_interval(1.2)
	_save_tween.tween_property(save_label, "modulate:a", 0.0, 0.3)
	_save_tween.tween_callback(func(): save_label.visible = false)
