extends CharacterBody2D

## Ovelha pacífica que pasta pela grama, alternando entre mastigar e olhar em volta com Y-Sort.

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_timer: Timer = $Timer

var is_eating: bool = false
var wander_direction: Vector2 = Vector2.ZERO
var is_wandering: bool = false

func _ready() -> void:
	y_sort_enabled = true
	# Inicia em tempo dessincronizado para cada ovelha não mastigar junto
	if state_timer:
		state_timer.timeout.connect(_on_timer_timeout)
		state_timer.start(randf_range(1.5, 4.5))

	if animated_sprite:
		animated_sprite.play("idle")
		if randf() < 0.5:
			animated_sprite.flip_h = true

func _physics_process(delta: float) -> void:
	if is_wandering:
		velocity = wander_direction * 25.0
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _on_timer_timeout() -> void:
	is_wandering = false
	is_eating = !is_eating

	if not animated_sprite:
		return

	if is_eating:
		animated_sprite.play("grass")
		state_timer.start(randf_range(3.5, 7.0))
	else:
		animated_sprite.play("idle")
		if randf() < 0.5:
			animated_sprite.flip_h = !animated_sprite.flip_h
		
		# Ocasionalmente dá um passinho curto de 1 segundo
		if randf() < 0.35:
			is_wandering = true
			wander_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			if abs(wander_direction.x) > 0.1:
				animated_sprite.flip_h = wander_direction.x < 0.0

		state_timer.start(randf_range(2.0, 4.5))
