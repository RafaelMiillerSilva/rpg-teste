class_name PawnGold
extends CharacterBody2D

const UpgradeManager = preload("res://scripts/upgrade_manager.gd")
const STUN_EFFECT_SCENE: PackedScene = preload("res://scenes/stun_effect.tscn")

## Ajudante Móvel Autônomo: Peão Coletor de Ouro Real.
## É imortal (ignora danos e ataques). Rastreia moedas pelo mapa, recolhe até a capacidade da bolsa
## e entrega todo o ouro diretamente ao Rei com efeitos sonoros e visuais.

enum State {
	SEEKING_COINS,
	RETURNING_TO_KING,
	FOLLOWING_KING
}

@export var base_speed: float = 190.0

var current_state: State = State.SEEKING_COINS
var carried_coins: int = 0
var target_coin: Node2D = null
var is_stunned: bool = false
var _stun_timer: float = 0.0
var _stun_effect_instance: Node2D = null

## Sistema Anti-Bugs / Anti-Travamento (Detecção de 5s travado andando sem sair da posição)
var _stuck_timer: float = 0.0
var _stuck_check_pos: Vector2 = Vector2.ZERO
var _stuck_interval_timer: float = 0.0
var _is_reversing: bool = false
var _reverse_timer: float = 0.0
var _reverse_direction: Vector2 = Vector2.ZERO
var _bypass_direction: Vector2 = Vector2.ZERO
var _bypass_timer: float = 0.0
var _is_trying_to_move: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var capacity_label: Label = $CapacityLabel if has_node("CapacityLabel") else null
@onready var gold_bar: ProgressBar = $GoldBar if has_node("GoldBar") else null

func _ready() -> void:
	add_to_group("pawns")
	add_to_group("helpers")
	collision_layer = 0 # Sem colisão
	collision_mask = 0  # Não colide nem bloqueia nada
	y_sort_enabled = true
	_stuck_check_pos = global_position
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	_setup_gold_bar()

	if animated_sprite:
		animated_sprite.play("idle")
	_update_gold_bar()

func _setup_gold_bar() -> void:
	if gold_bar:
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.12, 0.12, 0.12, 0.85)
		bg_style.set_corner_radius_all(2)
		gold_bar.add_theme_stylebox_override("background", bg_style)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.96, 0.82, 0.15, 1.0)
		fill_style.set_corner_radius_all(2)
		gold_bar.add_theme_stylebox_override("fill", fill_style)

		var max_cap: int = UpgradeManager.get_pawn_max_capacity()
		gold_bar.max_value = max_cap
		gold_bar.value = carried_coins
		gold_bar.show_percentage = false

func take_damage(_amount: int = 0, _knockback: Vector2 = Vector2.ZERO, _attacker = null) -> void:
	# O Peão Coletor é imortal e ignora qualquer dano
	pass

## Aplica atordoamento (Stun) de 1.0s: bloqueia ações e exibe estrelas sobre a cabeça
func apply_stun(duration: float = 1.0) -> void:
	is_stunned = true
	_stun_timer = maxf(_stun_timer, duration)
	_update_animation("idle", Vector2.ZERO)

	if is_instance_valid(_stun_effect_instance):
		_stun_effect_instance.refresh_duration(_stun_timer)
	elif STUN_EFFECT_SCENE and is_inside_tree():
		_stun_effect_instance = STUN_EFFECT_SCENE.instantiate() as Node2D
		_stun_effect_instance.setup(self, duration, Vector2(0, -42))
		var parent_node := get_parent()
		if parent_node:
			parent_node.call_deferred("add_child", _stun_effect_instance)

func _physics_process(delta: float) -> void:
	if is_stunned:
		_stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		_update_animation("idle", Vector2.ZERO)
		if _stun_timer <= 0.0:
			is_stunned = false
		return

	var king := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var move_speed: float = base_speed * UpgradeManager.get_pawn_speed_multiplier()
	var max_cap: int = UpgradeManager.get_pawn_max_capacity()

	# Se estiver executando recuo anti-stuck (andando para trás)
	if _is_reversing:
		_reverse_timer -= delta
		velocity = _reverse_direction * (move_speed * 0.85)
		move_and_slide()
		_update_animation("run", _reverse_direction)
		if _reverse_timer <= 0.0:
			_is_reversing = false
			_apply_route_recalculation()
		_update_stuck_detector(delta, false)
		return

	if _bypass_timer > 0.0:
		_bypass_timer -= delta

	_is_trying_to_move = false

	match current_state:
		State.SEEKING_COINS:
			# Se a bolsa estiver cheia, corre imediatamente para entregar ao Rei
			if carried_coins >= max_cap:
				current_state = State.RETURNING_TO_KING
				_update_stuck_detector(delta, false)
				return

			target_coin = _find_closest_coin()
			if is_instance_valid(target_coin):
				var dist := global_position.distance_to(target_coin.global_position)
				var dir := (target_coin.global_position - global_position).normalized()
				if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
					dir = (dir * 0.4 + _bypass_direction * 0.75).normalized()

				if dist > 22.0:
					velocity = velocity.move_toward(dir * move_speed, 700.0 * delta)
					move_and_slide()
					_update_animation("run", dir)
					_is_trying_to_move = true
				else:
					# Coleta a moeda
					_collect_coin(target_coin)
			else:
				# Sem moedas no chão
				if carried_coins > 0:
					current_state = State.RETURNING_TO_KING
				elif is_instance_valid(king):
					current_state = State.FOLLOWING_KING
				else:
					velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
					move_and_slide()
					_update_animation("idle", Vector2.ZERO)

		State.RETURNING_TO_KING:
			if not is_instance_valid(king):
				current_state = State.SEEKING_COINS
				_update_stuck_detector(delta, false)
				return

			var dist_to_king := global_position.distance_to(king.global_position)
			var dir_king := (king.global_position - global_position).normalized()
			if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
				dir_king = (dir_king * 0.4 + _bypass_direction * 0.75).normalized()

			if dist_to_king > 40.0:
				velocity = velocity.move_toward(dir_king * move_speed, 750.0 * delta)
				move_and_slide()
				_update_animation("run", dir_king)
				_is_trying_to_move = true
			else:
				# Chegou ao Rei: entrega o ouro
				_deliver_gold_to_king(king)
				current_state = State.SEEKING_COINS

		State.FOLLOWING_KING:
			# Se surgirem novas moedas, volta a caçar imediatamente
			if _find_closest_coin() != null:
				current_state = State.SEEKING_COINS
				_update_stuck_detector(delta, false)
				return

			if not is_instance_valid(king):
				_update_stuck_detector(delta, false)
				return

			var dist_k := global_position.distance_to(king.global_position)
			var dir_k := (king.global_position - global_position).normalized()
			if _bypass_timer > 0.0 and _bypass_direction != Vector2.ZERO:
				dir_k = (dir_k * 0.4 + _bypass_direction * 0.75).normalized()

			if dist_k > 85.0:
				velocity = velocity.move_toward(dir_k * move_speed, 600.0 * delta)
				move_and_slide()
				_update_animation("run", dir_k)
				_is_trying_to_move = true
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
				move_and_slide()
				_update_animation("idle", Vector2.ZERO)

	_update_stuck_detector(delta, _is_trying_to_move)

## Sistema Anti-Bugs: Detecta se a tropa ficou 5 segundos travada andando sem sair da posição
func _update_stuck_detector(delta: float, is_trying: bool) -> void:
	if not is_trying or is_stunned or _is_reversing:
		_stuck_timer = 0.0
		_stuck_check_pos = global_position
		_stuck_interval_timer = 0.0
		return

	_stuck_interval_timer += delta
	if _stuck_interval_timer >= 0.5:
		var dist_moved: float = global_position.distance_to(_stuck_check_pos)
		if dist_moved < 15.0:
			_stuck_timer += _stuck_interval_timer
		else:
			_stuck_timer = 0.0
			_stuck_check_pos = global_position
		_stuck_interval_timer = 0.0

	if _stuck_timer >= 5.0:
		_trigger_anti_stuck()

## Sistema Anti-Bugs: Ativa o recuo para trás
func _trigger_anti_stuck() -> void:
	_stuck_timer = 0.0
	_stuck_interval_timer = 0.0
	_is_reversing = true
	_reverse_timer = 1.0 # Anda para trás durante 1 segundo

	var backward_dir := -velocity.normalized()
	if backward_dir == Vector2.ZERO:
		var king := get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(king):
			backward_dir = (global_position - king.global_position).normalized()
		else:
			backward_dir = Vector2.DOWN

	var angle_offset: float = randf_range(0.35, 0.75) * (-1.0 if randf() < 0.5 else 1.0)
	_reverse_direction = backward_dir.rotated(angle_offset).normalized()

## Sistema Anti-Bugs: Recalcula a rota contornando lateralmente o obstáculo
func _apply_route_recalculation() -> void:
	var perp := Vector2(-_reverse_direction.y, _reverse_direction.x)
	if randf() < 0.5:
		perp = -perp
	_bypass_direction = perp
	_bypass_timer = 2.0

	target_coin = null
	_stuck_check_pos = global_position

func _update_animation(anim_name: String, dir: Vector2) -> void:
	if not animated_sprite:
		return
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
	if anim_name == "run":
		animated_sprite.speed_scale = UpgradeManager.get_pawn_speed_multiplier()
	else:
		animated_sprite.speed_scale = 1.0
	if abs(dir.x) > 0.05:
		animated_sprite.flip_h = dir.x < 0.0

func _collect_coin(coin: Node2D) -> void:
	if not is_instance_valid(coin):
		return
	carried_coins += 1
	_update_gold_bar()
	_show_pickup_popup(1)
	SoundManager.play_coin()
	coin.queue_free()

func _deliver_gold_to_king(king: CharacterBody2D) -> void:
	if carried_coins <= 0:
		return

	if king.has_method("add_coins"):
		king.add_coins(carried_coins)
	elif "coins" in king:
		king.coins += carried_coins
		if king.has_signal("coins_changed"):
			king.coins_changed.emit(king.coins)

	SoundManager.play_coin()

	# Efeito visual de entrega com número puro (sem emoji)
	_show_delivery_popup(carried_coins)
	carried_coins = 0
	_update_gold_bar()

func _show_pickup_popup(amount: int = 1) -> void:
	var popup := Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	popup.global_position = global_position + Vector2(-8, -32)
	var parent_node := get_parent()
	if parent_node:
		parent_node.add_child(popup)
		var tween := popup.create_tween()
		tween.tween_property(popup, "position:y", popup.position.y - 20.0, 0.6)
		tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.6)
		tween.tween_callback(popup.queue_free)

func _show_delivery_popup(amount: int) -> void:
	var popup := Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	popup.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	popup.global_position = global_position + Vector2(-12, -32)
	var parent_node := get_parent()
	if parent_node:
		parent_node.add_child(popup)
		var tween := popup.create_tween()
		tween.tween_property(popup, "position:y", popup.position.y - 25.0, 0.8)
		tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.8)
		tween.tween_callback(popup.queue_free)

func _update_gold_bar() -> void:
	var max_cap: int = UpgradeManager.get_pawn_max_capacity()
	if gold_bar:
		gold_bar.max_value = max_cap
		gold_bar.value = carried_coins
	if capacity_label:
		capacity_label.text = "%d/%d" % [carried_coins, max_cap]
		capacity_label.visible = (carried_coins > 0)

func _find_closest_coin() -> Node2D:
	var coins := get_tree().get_nodes_in_group("coins")
	var closest: Node2D = null
	var min_d: float = 999999.0

	for c in coins:
		if not is_instance_valid(c) or not c.is_inside_tree() or c.is_queued_for_deletion():
			continue
		var d := global_position.distance_to(c.global_position)
		if d < min_d:
			min_d = d
			closest = c
	return closest
