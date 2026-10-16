extends Node2D

static var auto_load_save_on_start: bool = false

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const BASE_ENEMIES_TURN_1: int = 3
const TURN_MULTIPLIER: float = 1.4

## Controle do sistema de turnos (ondas de inimigos)
var current_turn: int = 0
var is_turn_active: bool = false
var enemies_alive: int = 0

@onready var player: CharacterBody2D = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar
@onready var coins_label: Label = $CanvasLayer/CoinsLabel
@onready var potions_label: Label = $CanvasLayer/PotionsLabel
@onready var save_label: Label = $CanvasLayer/SaveNotificationLabel
@onready var turn_label: Label = $CanvasLayer/TurnLabel
@onready var enemies_count_label: Label = $CanvasLayer/EnemiesCountLabel
@onready var turn_banner_label: Label = $CanvasLayer/TurnBannerLabel

var _save_tween: Tween
var _banner_tween: Tween

func _ready() -> void:
	if save_label:
		save_label.visible = false
	if turn_banner_label:
		turn_banner_label.visible = false

	if player:
		if health_bar:
			player.health_changed.connect(_on_player_health_changed)
			health_bar.max_value = player.max_health
			health_bar.value = player.current_health

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

## Retorna uma coordenada aleatória próxima a uma das 4 bordas do mapa (1600x1200)
func _get_random_border_position() -> Vector2:
	var side: int = randi() % 4
	match side:
		0: # Borda Superior
			return Vector2(randf_range(80.0, 1520.0), randf_range(60.0, 110.0))
		1: # Borda Inferior
			return Vector2(randf_range(80.0, 1520.0), randf_range(1090.0, 1130.0))
		2: # Borda Esquerda
			return Vector2(randf_range(60.0, 110.0), randf_range(80.0, 1120.0))
		3: # Borda Direita
			return Vector2(randf_range(1490.0, 1540.0), randf_range(80.0, 1120.0))
	return Vector2(800.0, 100.0)

## Inicia o próximo turno, gerando 1.4x mais inimigos nas bordas
func start_next_turn() -> void:
	current_turn += 1
	is_turn_active = true
	var total_enemies: int = get_enemies_for_turn(current_turn)
	enemies_alive = total_enemies

	_update_turn_hud()
	_show_banner("TURNO %d\n%d Inimigos Invasores!" % [current_turn, total_enemies], Color(1.0, 0.85, 0.2, 1.0))
	SoundManager.play_hit()

	# Spawna os inimigos nas bordas do mapa
	for i in range(total_enemies):
		_spawn_enemy()

func _spawn_enemy() -> void:
	if not ENEMY_SCENE or not enemies_container:
		return

	var enemy := ENEMY_SCENE.instantiate() as CharacterBody2D
	enemy.global_position = _get_random_border_position()
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
