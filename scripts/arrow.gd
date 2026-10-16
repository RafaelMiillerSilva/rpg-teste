extends Area2D

## Velocidade de deslocamento da flecha em pixels por segundo.
@export var speed: float = 450.0

## Quantidade de dano infligido ao atingir o alvo.
@export var damage: int = 15

## Direção normalizada do projétil.
@export var direction: Vector2 = Vector2.ZERO

## Define se a flecha foi disparada por um aliado (atinge inimigos) ou por um inimigo (atinge o jogador).
@export var is_player_ally: bool = false

var _lifetime: float = 0.0
const MAX_LIFETIME: float = 3.0
var _has_hit: bool = false

func _ready() -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	body_entered.connect(_on_body_entered)

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

	if is_player_ally:
		# Flecha aliada: atinge apenas nós do grupo 'enemies'
		if body.is_in_group("enemies"):
			_has_hit = true
			set_deferred("monitoring", false)
			if body.has_method("take_damage"):
				body.take_damage(damage, direction)
			SoundManager.play_hit()
			queue_free()
			return
		# Ignora jogador e outros aliados/NPCs
		elif body.is_in_group("player") or body.is_in_group("npcs") or body.is_in_group("allies"):
			return
	else:
		# Flecha de monstro: atinge apenas o jogador
		if body.is_in_group("player"):
			_has_hit = true
			set_deferred("monitoring", false)
			if body.has_method("take_damage"):
				body.take_damage(damage, direction)
			queue_free()
			return
		# Ignora outros inimigos
		elif body.is_in_group("enemies"):
			return

	# Colisão com obstáculos sólidos do cenário (construções, paredes)
	if body is StaticBody2D or body is TileMapLayer:
		_has_hit = true
		set_deferred("monitoring", false)
		queue_free()

