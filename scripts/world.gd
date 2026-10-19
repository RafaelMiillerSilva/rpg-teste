extends Node2D

static var auto_load_save_on_start: bool = false

const WaveManager = preload("res://scripts/wave_manager.gd")

## Controle do sistema de turnos e hordas de inimigos via WaveManager
var current_turn: int:
	get: return wave_manager.current_turn if wave_manager else 0
	set(val):
		if wave_manager: wave_manager.current_turn = val

var enemies_alive: int:
	get: return wave_manager.enemies_alive if wave_manager else 0
	set(val):
		if wave_manager: wave_manager.enemies_alive = val

var wave_manager: Node = null

@onready var player: CharacterBody2D = $Player
@onready var enemies_container: Node2D = $Enemies
@onready var tilemap_layer: TileMapLayer = $TileMapLayer if has_node("TileMapLayer") else null
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar
@onready var health_text: Label = $CanvasLayer/HealthBar.get_node_or_null("HealthText")
@onready var coins_label: Label = $CanvasLayer/CoinsLabel
@onready var potions_label: Label = $CanvasLayer/PotionsLabel
@onready var armor_label: Label = $CanvasLayer.get_node_or_null("ArmorLabel")
@onready var save_label: Label = $CanvasLayer/SaveNotificationLabel
@onready var turn_label: Label = $CanvasLayer/TurnLabel
@onready var enemies_count_label: Label = $CanvasLayer/EnemiesCountLabel
@onready var turn_banner_label: Label = $CanvasLayer/TurnBannerLabel
@onready var pause_button: Button = $CanvasLayer.get_node_or_null("PauseButton")
@onready var pause_menu: CanvasLayer = $PauseMenu if has_node("PauseMenu") else null
@onready var upgrade_menu: CanvasLayer = $UpgradeMenu if has_node("UpgradeMenu") else null
@onready var allies_container: Node2D = $Allies if has_node("Allies") else null
@onready var gate_north: Marker2D = $GateNorth if has_node("GateNorth") else null
@onready var gate_south: Marker2D = $GateSouth if has_node("GateSouth") else null
@onready var gate_west: Marker2D = $GateWest if has_node("GateWest") else null
@onready var gate_east: Marker2D = $GateEast if has_node("GateEast") else null

var _save_tween: Tween
var _banner_tween: Tween

func _ready() -> void:
	_setup_tilemap_floor()

	# Configura o WaveManager
	if has_node("WaveManager"):
		wave_manager = $WaveManager
	else:
		wave_manager = WaveManager.new()
		wave_manager.name = "WaveManager"
		add_child(wave_manager)

	wave_manager.enemies_container = enemies_container
	wave_manager.player = player
	wave_manager.turn_started.connect(_on_wave_turn_started)
	wave_manager.enemies_count_changed.connect(_on_wave_enemies_count_changed)
	wave_manager.turn_completed.connect(_on_wave_turn_completed)

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

		if armor_label and player.has_signal("armor_changed"):
			player.armor_changed.connect(_on_player_armor_changed)
			_on_player_armor_changed(player.get_total_armor())

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

func _load_initial_save() -> void:
	if player and player.has_method("load_game"):
		player.load_game()

func _on_wave_turn_started(turn: int, total_enemies: int) -> void:
	_update_turn_hud()
	_show_banner("TURNO %d\n%d Goblins Invasores!" % [turn, total_enemies], Color(1.0, 0.85, 0.2, 1.0))

func _on_wave_enemies_count_changed(_count: int) -> void:
	_update_turn_hud()

func _on_wave_turn_completed(_turn: int) -> void:
	_regenerate_all_troops()

## Inicia o próximo turno através do WaveManager
func start_next_turn() -> void:
	if wave_manager:
		wave_manager.start_next_turn()

## Retrocompatibilidade
func get_enemies_for_turn(turn: int) -> int:
	return WaveManager.get_total_enemies_for_turn(turn)

func _setup_tilemap_floor() -> void:
	if not tilemap_layer:
		return
	for x in range(-6, 132):
		for y in range(-6, 100):
			tilemap_layer.set_cell(Vector2i(x, y), 0, Vector2i(1, 1))

## Regenera a vida de todas as tropas aliadas contratadas ao final do turno (o jogador não se regenera)
func _regenerate_all_troops() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return

	var tree := get_tree()
	if not tree:
		return

	SoundManager.play_heal()

	# Regenera apenas as tropas aliadas contratadas
	var allies := tree.get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			var max_hp: int = ally.max_health if "max_health" in ally else 200
			if ally.has_method("heal"):
				ally.heal(max_hp)
			elif "current_health" in ally:
				ally.current_health = max_hp
				if ally.has_method("_update_health_bar"):
					ally._update_health_bar()

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

func _on_player_armor_changed(total_armor: int) -> void:
	if armor_label:
		armor_label.text = "🛡️ %d" % total_armor

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
