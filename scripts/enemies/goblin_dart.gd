extends Area2D

## Projétil de dardo disparado por Goblins (Dart Goblin e Giant Goblin)
## Atinge o Rei (Player) e as tropas aliadas (Allies).

@export var speed: float = 240.0
@export var damage: int = 8
@export var direction: Vector2 = Vector2.ZERO

var shooter: Node2D = null
var _lifetime: float = 0.0
const MAX_LIFETIME: float = 3.5
var _has_hit: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4 # Layer 1: Player/World, Layer 4: Allies
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	SoundManager.play_arrow()

func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= MAX_LIFETIME:
		queue_free()
		return

	if direction != Vector2.ZERO:
		position += direction * speed * delta
		rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return

	var valid_shooter: Node2D = shooter if is_instance_valid(shooter) else null

	# Atinge o jogador ou aliados do esquadrão
	if body.is_in_group("player") or body.is_in_group("allies"):
		_has_hit = true
		set_deferred("monitoring", false)
		if body.has_method("take_damage"):
			body.take_damage(damage, direction, valid_shooter)
		queue_free()
		return
	elif body.is_in_group("enemies"):
		# Não atinge outros goblins
		return

	# Colisão com obstáculos sólidos (paredes, construções)
	if body is StaticBody2D or body is TileMapLayer:
		_has_hit = true
		set_deferred("monitoring", false)
		queue_free()
