extends CharacterBody2D

## Vida inicial do inimigo.
@export var health: int = 30

## Velocidade de movimentação do inimigo.
@export var speed: float = 80.0

## Raio de detecção do jogador em pixels.
@export var detection_radius: float = 300.0

## Dano causado ao jogador por colisão.
@export var attack_damage: int = 10

## Cooldown entre ataques para evitar dano por múltiplos frames.
@export var attack_cooldown: float = 0.8

var can_attack: bool = true
var target_player: CharacterBody2D = null

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	# Localiza o jogador pelo grupo "player"
	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	var desired_velocity := Vector2.ZERO

	if is_instance_valid(target_player):
		var distance := global_position.distance_to(target_player.global_position)
		# Persegue o jogador se estiver dentro do raio de 300 pixels
		if distance <= detection_radius:
			var direction := (target_player.global_position - global_position).normalized()
			desired_velocity = direction * speed

	# Move gradualmente até a velocidade desejada (preservando knockbacks)
	velocity = velocity.move_toward(desired_velocity, 600.0 * delta)
	move_and_slide()

	# Verifica se colidiu com o jogador
	_check_player_collisions()

func _check_player_collisions() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
			_deal_damage_to_player(collider as Node2D)
			break

func _deal_damage_to_player(player_node: Node2D) -> void:
	if not can_attack or not is_instance_valid(player_node):
		return

	can_attack = false
	var knockback_dir: Vector2 = (player_node.global_position - global_position).normalized()
	if knockback_dir == Vector2.ZERO:
		knockback_dir = Vector2.DOWN

	player_node.take_damage(attack_damage, knockback_dir)

	# Inicia temporizador de recarga de ataque
	if is_inside_tree():
		var timer := get_tree().create_timer(attack_cooldown)
		timer.timeout.connect(func(): can_attack = true)
	else:
		can_attack = true

## Aplica dano, pisca em branco e elimina o inimigo se health <= 0
func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	health -= amount

	# Empurrão resultante do golpe
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 250.0

	# Efeito visual de piscar em branco rapidamente
	if color_rect:
		color_rect.color = Color.WHITE
		var tween := create_tween()
		if tween:
			tween.tween_property(color_rect, "color", Color(0.85, 0.2, 0.2, 1.0), 0.12)

	if health <= 0:
		queue_free()
