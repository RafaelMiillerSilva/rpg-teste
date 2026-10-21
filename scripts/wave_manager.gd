class_name WaveManager
extends Node

## Gerenciador Central de Turnos e Ondas de Inimigos Goblins.
## Controla o escalonamento matemático das hordas, composição tática, spawn do Chefe Final (Goblin King)
## e suporte ao Modo História e Modo Endless.

signal turn_started(turn: int, total_enemies: int)
signal enemies_count_changed(alive_count: int)
signal turn_completed(turn: int)
signal boss_spawned(boss_node: Node2D)
signal level_victory_triggered()

const GOBLIN_NORMAL_SCENE: PackedScene = preload("res://scenes/enemies/goblin_normal.tscn")
const GOBLIN_RANGE_SCENE: PackedScene = preload("res://scenes/enemies/goblin_range.tscn")
const GOBLIN_WARRIOR_SCENE: PackedScene = preload("res://scenes/enemies/goblin_warrior.tscn")
const GOBLIN_HEALER_SCENE: PackedScene = preload("res://scenes/enemies/goblin_healer.tscn")
const GOBLIN_GIANT_SCENE: PackedScene = preload("res://scenes/enemies/goblin_giant.tscn")
const GOBLIN_MAGE_SCENE: PackedScene = preload("res://scenes/enemies/goblin_mage.tscn")
const GOBLIN_KING_SCENE: PackedScene = preload("res://scenes/enemies/goblin_king.tscn")
const GoblinKingClass = preload("res://scripts/goblin_king.gd")
const LevelManager = preload("res://scripts/level_manager.gd")

const BASE_ENEMIES: float = 10.0
const ENEMY_GROWTH_RATE: float = 1.2
const MAX_ENEMIES_CAP: int = 120
const TARGET_BATCH_SIZE: int = 20
const SPAWN_INTERVAL: float = 0.2
const BATCH_COOLDOWN: float = 3.5
const TURN_COOLDOWN: float = 3.5
const ENEMY_SPAWN_DISTANCE: float = 650.0

var current_turn: int = 0
var is_turn_active: bool = false
var enemies_alive: int = 0
var spawn_queue: Array[PackedScene] = []
var spawn_cooldown_timer: float = 0.0
var turn_cooldown_timer: float = 0.0
var is_waiting_next_turn: bool = false
var is_waiting_initial_start: bool = true
var initial_start_timer: float = 1.0

## Sistema de controle de lotes (batches) de spawn
var batch_sizes: Array[int] = []
var current_batch_index: int = 0
var enemies_in_current_batch: int = 0
var spawned_in_current_batch: int = 0

var enemies_container: Node2D = null
var player: CharacterBody2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT

## Retorna a quantidade total de goblins para um determinado turno
static func get_total_enemies_for_turn(turn_num: int) -> int:
	var t: int = maxi(1, turn_num)
	var count: int = int(round(BASE_ENEMIES * pow(ENEMY_GROWTH_RATE, t - 1)))
	return clampi(count, 10, MAX_ENEMIES_CAP)

## Retorna a fila de PackedScenes baseada na composição tática do turno,
## dividindo os inimigos em lotes iguais de ~20 com composição balanceada.
func generate_wave_composition(turn_num: int) -> Array[PackedScene]:
	var queue: Array[PackedScene] = []
	batch_sizes.clear()

	# Turno 30 no Modo História: Chefe Final Rei Goblin e sua guarda de honra
	if turn_num == 30 and LevelManager.current_game_mode == "story":
		queue.append(GOBLIN_KING_SCENE)
		for i in range(2):
			queue.append(GOBLIN_HEALER_SCENE)
		for i in range(4):
			queue.append(GOBLIN_WARRIOR_SCENE)
		for i in range(2):
			queue.append(GOBLIN_GIANT_SCENE)
		for i in range(2):
			queue.append(GOBLIN_MAGE_SCENE)
		batch_sizes.append(queue.size())
		return queue

	var total: int = get_total_enemies_for_turn(turn_num)

	# Distribuição percentual oficial por turno:
	# Turnos 1 a 4: 100% Normais
	# Turnos 5 a 9: 70% Normais, 30% Range
	# Turnos 10 a 14: 50% Normais, 30% Range, 20% Warriors
	# Turnos 15 a 19: 20% Normais, 30% Range, 40% Warriors, 10% Healers
	# Turnos 20 a 24: 15% Normais, 30% Range, 40% Warriors, 10% Healers, 5% Giants
	# Turnos 25+: 4% Mages, 5% Giants, 10% Healers, 40% Warriors, 30% Range, 11% Normais

	var pct_normal: float = 1.0
	var pct_range: float = 0.0
	var pct_warrior: float = 0.0
	var pct_healer: float = 0.0
	var pct_giant: float = 0.0
	var pct_mage: float = 0.0

	if turn_num >= 25:
		pct_normal = 0.11
		pct_range = 0.30
		pct_warrior = 0.40
		pct_healer = 0.10
		pct_giant = 0.05
		pct_mage = 0.04 # Aumentado para 4%
	elif turn_num >= 20:
		pct_normal = 0.15
		pct_range = 0.30
		pct_warrior = 0.40
		pct_healer = 0.10
		pct_giant = 0.05
	elif turn_num >= 15:
		pct_normal = 0.20
		pct_range = 0.30
		pct_warrior = 0.40
		pct_healer = 0.10
	elif turn_num >= 10:
		pct_normal = 0.50
		pct_range = 0.30
		pct_warrior = 0.20
	elif turn_num >= 5:
		pct_normal = 0.70
		pct_range = 0.30

	var count_mage: int = maxi(1 if pct_mage > 0.0 else 0, int(round(total * pct_mage))) if pct_mage > 0.0 else 0
	var count_giant: int = maxi(1 if pct_giant > 0.0 else 0, int(round(total * pct_giant))) if pct_giant > 0.0 else 0
	var count_healer: int = int(round(total * pct_healer))
	var count_warrior: int = int(round(total * pct_warrior))
	var count_range: int = int(round(total * pct_range))
	var count_normal: int = maxi(0, total - (count_giant + count_healer + count_warrior + count_range + count_mage))

	# Divisão em lotes iguais de ~20 inimigos
	var num_batches: int = maxi(1, int(ceil(float(total) / float(TARGET_BATCH_SIZE))))
	var batches: Array = []
	for b in range(num_batches):
		batches.append([])

	# Estrutura de distribuição proporcional e intercalada entre os lotes
	# Evita agrupar todos os gigantes e curandeiros em uma única fase da onda
	var type_pools: Array = [
		{"scene": GOBLIN_GIANT_SCENE, "count": count_giant},
		{"scene": GOBLIN_MAGE_SCENE, "count": count_mage},
		{"scene": GOBLIN_HEALER_SCENE, "count": count_healer},
		{"scene": GOBLIN_WARRIOR_SCENE, "count": count_warrior},
		{"scene": GOBLIN_RANGE_SCENE, "count": count_range},
		{"scene": GOBLIN_NORMAL_SCENE, "count": count_normal},
	]

	for pool in type_pools:
		var sc: PackedScene = pool["scene"]
		var cnt: int = pool["count"]
		for i in range(cnt):
			var batch_idx: int = i % num_batches
			batches[batch_idx].append(sc)

	# No modo endless a cada 10 turnos (30, 40, etc), adiciona o Rei Goblin como líder do primeiro lote
	if LevelManager.current_game_mode == "endless" and turn_num >= 30 and (turn_num % 10 == 0):
		batches[0].insert(0, GOBLIN_KING_SCENE)

	# Embaralha os inimigos dentro de cada lote individualmente para variação orgânica
	for b in batches:
		b.shuffle()
		batch_sizes.append(b.size())
		for sc in b:
			queue.append(sc)

	return queue

func start_next_turn() -> void:
	if not is_inside_tree():
		return

	current_turn += 1
	is_turn_active = true
	is_waiting_next_turn = false

	spawn_queue = generate_wave_composition(current_turn)
	enemies_alive = spawn_queue.size()
	spawn_cooldown_timer = 0.0

	current_batch_index = 0
	spawned_in_current_batch = 0
	enemies_in_current_batch = batch_sizes[0] if not batch_sizes.is_empty() else spawn_queue.size()

	turn_started.emit(current_turn, enemies_alive)
	enemies_count_changed.emit(enemies_alive)
	SoundManager.play_hit()

func _process(delta: float) -> void:
	if is_waiting_initial_start:
		initial_start_timer -= delta
		if initial_start_timer <= 0.0:
			is_waiting_initial_start = false
			start_next_turn()
		return

	if is_waiting_next_turn:
		turn_cooldown_timer -= delta
		if turn_cooldown_timer <= 0.0:
			is_waiting_next_turn = false
			start_next_turn()
		return

	if is_turn_active and not spawn_queue.is_empty():
		spawn_cooldown_timer -= delta
		if spawn_cooldown_timer <= 0.0:
			var scene := spawn_queue.pop_front() as PackedScene
			if scene:
				_spawn_enemy(scene)
				spawned_in_current_batch += 1

			# Verifica se completou o lote de ~20
			if spawned_in_current_batch >= enemies_in_current_batch:
				spawn_cooldown_timer = BATCH_COOLDOWN
				spawned_in_current_batch = 0
				current_batch_index += 1
				if current_batch_index < batch_sizes.size():
					enemies_in_current_batch = batch_sizes[current_batch_index]
				else:
					enemies_in_current_batch = 0
			else:
				spawn_cooldown_timer = SPAWN_INTERVAL

func _get_enemy_spawn_position() -> Vector2:
	var center := player.global_position if is_instance_valid(player) else Vector2(4000.0, 2900.0)
	var angle := randf() * TAU
	var offset := Vector2(cos(angle), sin(angle)) * ENEMY_SPAWN_DISTANCE
	var pos := center + offset
	pos.x = clampf(pos.x, 350.0, 7650.0)
	pos.y = clampf(pos.y, 350.0, 5650.0)
	return pos

func _spawn_enemy(enemy_scene: PackedScene) -> void:
	if not enemies_container or not enemy_scene:
		return

	var enemy = enemy_scene.instantiate() as CharacterBody2D
	if "turn" in enemy:
		enemy.turn = current_turn

	enemy.global_position = _get_enemy_spawn_position()
	enemies_container.add_child(enemy)

	if enemy is GoblinKingClass:
		boss_spawned.emit(enemy)
		enemy.boss_defeated.connect(_on_boss_defeated)

	enemy.tree_exited.connect(_on_enemy_defeated)

func _on_boss_defeated(_boss: Node2D) -> void:
	if LevelManager.current_game_mode == "story" and current_turn >= 30:
		level_victory_triggered.emit()

func _on_enemy_defeated() -> void:
	if not is_inside_tree() or not is_turn_active:
		return

	enemies_alive = maxi(0, enemies_alive - 1)
	enemies_count_changed.emit(enemies_alive)

	if enemies_alive == 0:
		_on_turn_completed()

func _on_turn_completed() -> void:
	if not is_inside_tree():
		return

	is_turn_active = false
	spawn_queue.clear()
	SoundManager.play_coin()

	turn_completed.emit(current_turn)

	# Se for modo história no turno 30, o encerramento acontece com a derrota do Goblin King
	if LevelManager.current_game_mode == "story" and current_turn >= 30:
		return

	# Inicia o intervalo compassado entre turnos (3.5s)
	is_waiting_next_turn = true
	turn_cooldown_timer = TURN_COOLDOWN
