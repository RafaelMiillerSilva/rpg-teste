extends AnimatedSprite2D

## Efeito de Queimadura (DoT - Dano por Segundo de Fogo)
## Causado pela explosão do Goblin Mage.
## Permanece ativo por 5 segundos causando 5 de dano puro a cada segundo (ignora armadura).

var _timer: float = 5.0
var _tick_timer: float = 1.0
var _damage_per_sec: int = 5
var _target: Node2D = null
var _offset: Vector2 = Vector2(0, -12)
var _attacker: Node2D = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 22
	play("fire")

func setup(target: Node2D, duration: float = 5.0, dps: int = 5, attacker: Node2D = null) -> void:
	_target = target
	_timer = duration
	_tick_timer = 1.0
	_damage_per_sec = dps
	_attacker = attacker
	if is_instance_valid(_target):
		global_position = _target.global_position + _offset

func refresh_duration(duration: float = 5.0) -> void:
	_timer = maxf(_timer, duration)

func _process(delta: float) -> void:
	if not is_instance_valid(_target) or ("is_dead" in _target and _target.is_dead):
		queue_free()
		return

	global_position = _target.global_position + _offset

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 1.0
		_apply_burn_tick()

	_timer -= delta
	if _timer <= 0.0:
		var tw := create_tween()
		if tw:
			tw.tween_property(self, "modulate:a", 0.0, 0.25)
			tw.tween_callback(queue_free)
		else:
			queue_free()

func _apply_burn_tick() -> void:
	if not is_instance_valid(_target) or ("is_dead" in _target and _target.is_dead):
		return

	# Calcula armadura para garantir que o dano de fogo ignore armadura
	var target_armor: int = 0
	if _target.has_method("get_total_armor"):
		target_armor = _target.get_total_armor()
	elif "armor" in _target:
		target_armor = _target.armor

	# Feedback visual: pisca em cor de brasa ardente
	var target_sprite: Node = _target.get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(target_sprite) and target_sprite is CanvasItem:
		target_sprite.modulate = Color(2.4, 1.3, 0.4, 1.0)
		var tw := create_tween()
		if tw:
			tw.tween_property(target_sprite, "modulate", Color.WHITE, 0.2)

	if _target.has_method("take_damage"):
		_target.take_damage(_damage_per_sec + target_armor, Vector2.ZERO, _attacker)
