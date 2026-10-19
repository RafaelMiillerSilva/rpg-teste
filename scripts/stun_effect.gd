extends AnimatedSprite2D

var _timer: float = 1.0
var _target: Node2D = null
var _offset: Vector2 = Vector2(0, -48)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 25
	play("stun")

func setup(target: Node2D, duration: float = 1.0, offset_pos: Vector2 = Vector2(0, -48)) -> void:
	_target = target
	_timer = duration
	_offset = offset_pos
	if is_instance_valid(_target):
		global_position = _target.global_position + _offset

func refresh_duration(duration: float = 1.0) -> void:
	_timer = maxf(_timer, duration)

func _process(delta: float) -> void:
	if not is_instance_valid(_target) or ("is_dead" in _target and _target.is_dead):
		queue_free()
		return

	global_position = _target.global_position + _offset

	_timer -= delta
	if _timer <= 0.0:
		queue_free()
