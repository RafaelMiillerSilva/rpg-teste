extends Node2D

static var auto_load_save_on_start: bool = false

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const ENEMY_ARCHER_SCENE: PackedScene = preload("res://scenes/enemy_archer.tscn")
const BASE_ENEMIES_TURN_1: int = 3
const TURN_MULTIPLIER: float = 1.4
const ENEMY_SPAWN_DISTANCE: float = 650.0

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
@onready var pause_button: Button = $CanvasLayer.get_node_or_null("PauseButton")
@onready var pause_menu: CanvasLayer = $PauseMenu if has_node("PauseMenu") else null
@onready var gate_north: Marker2D = $GateNorth if has_node("GateNorth") else null
@onready var gate_south: Marker2D = $GateSouth if has_node("GateSouth") else null
@onready var gate_west: Marker2D = $GateWest if has_node("GateWest") else null
@onready var gate_east: Marker2D = $GateEast if has_node("GateEast") else null

var _save_tween: Tween
var _banner_tween: Tween

func _ready() -> void:
	_setup_tilemap_floor()

	if pause_button and pause_menu:
		pause_button.pressed.connect(func():
			if pause_menu.has_method("toggle_pause"):
				pause_menu.toggle_pause()
		)

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
	for x in range(-6, 132):
		for y in range(-6, 100):
			tilemap_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))

## Retorna a posição do Marker2D do portão indicado
func _get_gate_position(side: int) -> Vector2:
	match side:
		0:
			return gate_north.global_position if gate_north else Vector2(4000.0, 250.0)
		1:
			return gate_south.global_position if gate_south else Vector2(4000.0, 5750.0)
		2:
			return gate_west.global_position if gate_west else Vector2(250.0, 3000.0)
		3:
			return gate_east.global_position if gate_east else Vector2(7750.0, 3000.0)
		_:
			return Vector2(4000.0, 250.0)

## Retorna o ponto inicial fora do mapa alinhado exatamente ao centro do portão
func _get_spawn_position_for_gate(side: int) -> Vector2:
	var gate_pos := _get_gate_position(side)
	match side:
		0: # Norte: acima do portão no mesmo eixo X exato
			return Vector2(gate_pos.x, -100.0)
		1: # Sul: abaixo do portão no mesmo eixo X exato
			return Vector2(gate_pos.x, 6100.0)
		2: # Oeste: à esquerda do portão no mesmo eixo Y exato
			return Vector2(-100.0, gate_pos.y)
		3: # Leste: à direita do portão no mesmo eixo Y exato
			return Vector2(8100.0, gate_pos.y)
		_:
			return Vector2(gate_pos.x, -100.0)

## Retorna uma posição de spawn a uma distância fixa do jogador em ângulo distribuído
func _get_enemy_spawn_position() -> Vector2:
	var center := player.global_position if is_instance_valid(player) else Vector2(4000.0, 2900.0)
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * ENEMY_SPAWN_DISTANCE
	var pos := center + offset
	# Garante que não spawne dentro das barreiras de floresta
	pos.x = clampf(pos.x, 350.0, 7650.0)
	pos.y = clampf(pos.y, 350.0, 5650.0)
	return pos

## Retrocompatibilidade para chamadas genéricas
func _get_spawn_and_gate() -> Dictionary:
	var p := _get_enemy_spawn_position()
	return { "spawn_pos": p, "gate_pos": p }

func _get_random_border_position() -> Vector2:
	return _get_enemy_spawn_position()

## Inicia o próximo turno com os inimigos spawnando a uma distância fixa do jogador
func start_next_turn() -> void:
	current_turn += 1
	is_turn_active = true
	var total_enemies: int = get_enemies_for_turn(current_turn)
	enemies_alive = total_enemies

	_update_turn_hud()
	_show_banner("TURNO %d\n%d Inimigos Invasores!" % [current_turn, total_enemies], Color(1.0, 0.85, 0.2, 1.0))
	SoundManager.play_hit()

	# Despacha os inimigos a uma distância fixa do jogador com intervalo suave
	for i in range(total_enemies):
		var spawn_delay: float = float(i) * 0.6
		if spawn_delay > 0.0:
			var timer := get_tree().create_timer(spawn_delay)
			timer.timeout.connect(func():
				if is_inside_tree() and is_turn_active:
					_spawn_enemy()
			)
		else:
			_spawn_enemy()

## Instancia um inimigo (guerreiro ou arqueiro) a uma distância fixa do jogador
func _spawn_enemy() -> void:
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

	var spawn_pos := _get_enemy_spawn_position()
	enemy.global_position = spawn_pos
	if "current_state" in enemy:
		enemy.current_state = 1 # State.CHASING_PLAYER
	if "gate_position" in enemy:
		enemy.gate_position = spawn_pos

	enemies_container.add_child(enemy)

	# Monitora a eliminação do inimigo quando sair da árvore
	enemy.tree_exited.connect(_on_enemy_defeated)

## Retrocompatibilidade
func _spawn_enemy_in_line(_gate_id: int = 0) -> void:
	_spawn_enemy()



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
