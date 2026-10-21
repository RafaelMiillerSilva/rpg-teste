class_name UpgradeManager
extends RefCounted

## Gerenciador Central de Melhorias Separadas por Construção.
## Permite evoluir atributos específicos no Campo de Tiro, Quartel, Castelo, Monastério e Casa dos Peões.

class _SignalHolder extends RefCounted:
	signal upgrades_changed()

static var _signal_holder: _SignalHolder = _SignalHolder.new()
static var upgrades_changed: Signal = _signal_holder.upgrades_changed

# Níveis das Melhorias por Construção
# 1. Archery (Campo de Tiro)
static var archer_damage_level: int = 0
static var archer_speed_level: int = 0

# 2. Barracks (Quartel)
static var warrior_damage_level: int = 0
static var warrior_health_level: int = 0
static var warrior_block_level: int = 0

# 3. Castle (Castelo)
static var lancer_damage_level: int = 0
static var king_armor_level: int = 0

# 4. Monastery (Monastério)
static var monk_heal_level: int = 0
static var monk_range_level: int = 0
static var monk_targets_level: int = 0

# 5. Pawn House (Casa dos Peões)
static var pawn_recruited: bool = false
static var pawn_speed_level: int = 0
static var pawn_capacity_level: int = 0

static func is_pawn_recruited() -> bool:
	return pawn_recruited

# Retrocompatibilidade de variáveis legadas
static var damage_level: int:
	get: return warrior_damage_level
	set(v): warrior_damage_level = v
static var attack_speed_level: int:
	get: return archer_speed_level
	set(v): archer_speed_level = v
static var max_health_level: int:
	get: return warrior_health_level
	set(v): warrior_health_level = v
static var armor_level: int:
	get: return king_armor_level
	set(v): king_armor_level = v

## Retorna o custo atual com valores acessíveis e reduzidos para todas as tropas:
## - pawn_recruit: 1 moeda (unidade única)
## - recruit_warrior: 30 moedas
## - recruit_archer: 35 moedas
## - recruit_lancer: 45 moedas
## - recruit_monk: 50 moedas
## - pawn_speed, pawn_capacity: 5 moedas base, +3 por nível (5, 8, 11, 14, 17...)
## - tropas (guerreiro, arqueiro, lanceiro, monge, armadura): 8 moedas base, +5 por nível (8, 13, 18, 23, 28...)
static func get_cost(type: String) -> int:
	match type:
		"pawn_recruit": return 1
		"recruit_warrior": return 30
		"recruit_archer": return 35
		"recruit_lancer": return 45
		"recruit_monk": return 50
		"pawn_speed", "pawn_capacity":
			var lvl := get_level(type)
			return 5 + (lvl * 3)
		_:
			var lvl := get_level(type)
			return 8 + (lvl * 5)

static func get_level(type: String) -> int:
	match type:
		"pawn_recruit": return 1 if pawn_recruited else 0
		"archer_damage": return archer_damage_level
		"archer_speed": return archer_speed_level
		"warrior_damage": return warrior_damage_level
		"warrior_health": return warrior_health_level
		"warrior_block": return warrior_block_level
		"lancer_damage": return lancer_damage_level
		"king_armor": return king_armor_level
		"monk_heal": return monk_heal_level
		"monk_range": return monk_range_level
		"monk_targets": return monk_targets_level
		"pawn_speed": return pawn_speed_level
		"pawn_capacity": return pawn_capacity_level
		# Retrocompatibilidade
		"damage": return warrior_damage_level
		"attack_speed": return archer_speed_level
		"max_health": return warrior_health_level
		"armor": return king_armor_level
		_: return 0

# --- Bônus Numéricos das Melhorias ---

# Archery
static func get_archer_bonus_damage() -> int:
	return archer_damage_level * 4

static func get_archer_cooldown_multiplier() -> float:
	return pow(0.88, archer_speed_level)

# Barracks
static func get_warrior_bonus_damage() -> int:
	return warrior_damage_level * 5

static func get_warrior_bonus_health() -> int:
	return warrior_health_level * 35

static func get_warrior_block_bonus() -> float:
	return float(warrior_block_level) * 0.10

# Castle
static func get_lancer_bonus_damage() -> int:
	return lancer_damage_level * 6

static func get_king_bonus_armor() -> int:
	return king_armor_level * 1

# Monastery
static func get_monk_bonus_heal() -> int:
	return monk_heal_level * 8

static func get_monk_bonus_range() -> float:
	return float(monk_range_level) * 40.0

## Retorna a quantidade de alvos extras curados por pulso do monge
static func get_monk_bonus_targets() -> int:
	return monk_targets_level

# Pawn House
static func get_pawn_speed_multiplier() -> float:
	return 1.0 + (float(pawn_speed_level) * 0.25)

static func get_pawn_max_capacity() -> int:
	return 25 + (pawn_capacity_level * 25)

# Bônus genéricos para retrocompatibilidade
static func get_bonus_damage() -> int:
	return get_warrior_bonus_damage()

static func get_attack_cooldown_multiplier() -> float:
	return get_archer_cooldown_multiplier()

static func get_bonus_health() -> int:
	return get_warrior_bonus_health()

static func get_bonus_armor() -> int:
	return get_king_bonus_armor()

## Efetua a compra de uma melhoria descontando o ouro do jogador
static func buy_upgrade(type: String, player: Node) -> bool:
	if not is_instance_valid(player):
		return false

	var cost := get_cost(type)
	var player_coins: int = player.coins if "coins" in player else 0

	if player_coins < cost:
		return false

	player.coins -= cost
	if player.has_signal("coins_changed"):
		player.coins_changed.emit(player.coins)

	match type:
		"recruit_warrior":
			_spawn_unit(player, "res://scenes/ally_warrior.tscn")
		"recruit_archer":
			_spawn_unit(player, "res://scenes/ally_archer.tscn")
		"recruit_lancer":
			_spawn_unit(player, "res://scenes/ally_lancer.tscn")
		"recruit_monk":
			_spawn_unit(player, "res://scenes/ally_monk.tscn")
		"pawn_recruit":
			pawn_recruited = true
			_spawn_unit(player, "res://scenes/pawn_gold.tscn")
		"archer_damage": archer_damage_level += 1
		"archer_speed": archer_speed_level += 1
		"warrior_damage": warrior_damage_level += 1
		"warrior_health": warrior_health_level += 1
		"warrior_block": warrior_block_level += 1
		"lancer_damage": lancer_damage_level += 1
		"king_armor":
			king_armor_level += 1
			if player.has_signal("armor_changed"):
				player.armor_changed.emit(player.get_total_armor())
		"monk_heal": monk_heal_level += 1
		"monk_range": monk_range_level += 1
		"monk_targets": monk_targets_level += 1
		"pawn_speed": pawn_speed_level += 1
		"pawn_capacity": pawn_capacity_level += 1
		# Retrocompatibilidade
		"damage": warrior_damage_level += 1
		"attack_speed": archer_speed_level += 1
		"max_health": warrior_health_level += 1
		"armor":
			king_armor_level += 1
			if player.has_signal("armor_changed"):
				player.armor_changed.emit(player.get_total_armor())

	# Reproduz SFX temático de buff de acordo com a categoria da melhoria
	match type:
		"archer_damage", "warrior_damage", "lancer_damage", "damage":
			SoundManager.play_atk_buff()
		"king_armor", "armor", "warrior_health", "warrior_block", "max_health":
			SoundManager.play_def_buff()
		"archer_speed", "pawn_speed", "attack_speed":
			SoundManager.play_speed_buff()
		"monk_heal", "monk_range", "monk_targets":
			SoundManager.play_heal()
		"recruit_warrior", "recruit_archer", "recruit_lancer", "recruit_monk", "pawn_recruit":
			SoundManager.play_equip()
		_:
			SoundManager.play_equip()

	SoundManager.play_coin()
	upgrades_changed.emit()
	return true

static func _spawn_unit(player: Node, scene_path: String) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	var scene := load(scene_path) as PackedScene
	if not scene:
		return
	var ally := scene.instantiate() as CharacterBody2D
	var spawn_pos: Vector2 = player.global_position + Vector2(randf_range(-45.0, 45.0), randf_range(35.0, 65.0))
	ally.global_position = spawn_pos
	var world_scene := player.get_tree().current_scene
	var allies := world_scene.get_node_or_null("Allies") if world_scene else null
	if allies:
		allies.add_child(ally)
	elif world_scene:
		world_scene.add_child(ally)

	# Efeito visual de fumaça (Dust_02) ao surgir
	var dust_scene := load("res://scenes/dust_effect.tscn") as PackedScene
	if dust_scene:
		var dust := dust_scene.instantiate() as Node2D
		dust.global_position = spawn_pos
		if allies:
			allies.add_child(dust)
		elif world_scene:
			world_scene.add_child(dust)

static func reset_upgrades() -> void:
	pawn_recruited = false
	archer_damage_level = 0
	archer_speed_level = 0
	warrior_damage_level = 0
	warrior_health_level = 0
	warrior_block_level = 0
	lancer_damage_level = 0
	king_armor_level = 0
	monk_heal_level = 0
	monk_range_level = 0
	monk_targets_level = 0
	pawn_speed_level = 0
	pawn_capacity_level = 0
	upgrades_changed.emit()
