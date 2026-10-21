extends Area2D

## Projétil Bola de Fogo disparado pelo Goblin Mage.
## Usa o primeiro frame do Explosion_02 durante o voo, e os frames restantes ao explodir.
## Causa 35 de dano ignorando armadura, empurra unidades e incendeia por 5s (5 dano/seg).

const FIRE_EFFECT_SCENE: PackedScene = preload("res://scenes/fire_effect.tscn")

@export var speed: float = 270.0
@export var damage: int = 35
@export var direction: Vector2 = Vector2.ZERO
@export var explosion_radius: float = 95.0
@export var knockback_force: float = 340.0

var shooter: Node2D = null
var _lifetime: float = 0.0
const MAX_LIFETIME: float = 3.5
var _has_exploded: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4 # Layer 1: Player/World, Layer 4: Allies
	if animated_sprite:
		animated_sprite.play("flight")
		animated_sprite.scale = Vector2(0.5, 0.5)
	if direction != Vector2.ZERO:
		rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	SoundManager.play_slash()

func _process(delta: float) -> void:
	if _has_exploded:
		return

	_lifetime += delta
	if _lifetime >= MAX_LIFETIME:
		_trigger_explosion()
		return

	if direction != Vector2.ZERO:
		position += direction * speed * delta
		rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if _has_exploded:
		return

	# Não atinge outros monstros
	if body.is_in_group("enemies"):
		return

	# Atinge heróis (Rei ou Aliados) ou colide com obstáculos sólidos do mapa
	if body.is_in_group("player") or body.is_in_group("allies") or body is StaticBody2D or body is TileMapLayer:
		_trigger_explosion()

func _trigger_explosion() -> void:
	if _has_exploded:
		return
	_has_exploded = true

	set_deferred("monitoring", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Toca som de explosão de fogo
	SoundManager.play_fire_explosion()

	# Configura animação de explosão com escala maior (0.9x)
	if animated_sprite:
		rotation = 0.0 # Explosão sem inclinação
		animated_sprite.scale = Vector2(0.9, 0.9)
		animated_sprite.play("explode")
		animated_sprite.animation_finished.connect(queue_free)

	# Aplica dano em área, empurrão e queimadura por 5s
	_apply_explosion_effects()

	# Failsafe caso animação falhe em emitir finished
	get_tree().create_timer(0.7, false).timeout.connect(func():
		if is_instance_valid(self):
			queue_free()
	)

func _apply_explosion_effects() -> void:
	var victims: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
		if global_position.distance_to(player.global_position) <= explosion_radius:
			victims.append(player)

	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			if global_position.distance_to(ally.global_position) <= explosion_radius:
				victims.append(ally as Node2D)

	var valid_shooter: Node2D = shooter if is_instance_valid(shooter) else null
	var parent_node := get_parent()

	for victim in victims:
		var knock_dir := (victim.global_position - global_position).normalized()
		if knock_dir == Vector2.ZERO:
			knock_dir = direction if direction != Vector2.ZERO else Vector2.DOWN

		# Empurrão para longe do centro da explosão
		if "velocity" in victim:
			victim.velocity += knock_dir * knockback_force

		# Dano que ignora armadura: passa dano + armadura da vítima para anular a subtração
		var target_armor: int = 0
		if victim.has_method("get_total_armor"):
			target_armor = victim.get_total_armor()
		elif "armor" in victim:
			target_armor = victim.armor

		if victim.has_method("take_damage"):
			victim.take_damage(damage + target_armor, knock_dir * 1.5, valid_shooter)

		# Aplica o efeito de fogo (Fire_03) por 5 segundos causando 5 de dano por segundo
		_attach_fire_effect(victim, parent_node, valid_shooter)

func _attach_fire_effect(victim: Node2D, parent_node: Node, valid_shooter: Node2D) -> void:
	if not FIRE_EFFECT_SCENE:
		return

	# Checa se o alvo já possui um efeito de fogo ativo para renovar a duração
	var existing_fire: Node = null
	if parent_node:
		for child in parent_node.get_children():
			if child.is_in_group("fire_dot_effects") and child.get("_target") == victim:
				existing_fire = child
				break

	if is_instance_valid(existing_fire) and existing_fire.has_method("refresh_duration"):
		existing_fire.refresh_duration(5.0)
	elif parent_node:
		var fire_node = FIRE_EFFECT_SCENE.instantiate()
		fire_node.add_to_group("fire_dot_effects")
		fire_node.setup(victim, 5.0, 5, valid_shooter)
		parent_node.call_deferred("add_child", fire_node)
