extends CharacterBody2D

signal health_changed(current: int, max_hp: int)

## Velocidade máxima do personagem em pixels por segundo.
@export var speed: float = 250.0

## Taxa de aceleração até atingir a velocidade máxima.
@export var acceleration: float = 2000.0

## Taxa de desaceleração (fricção) até parar completamente.
@export var friction: float = 1800.0

## Vida máxima do jogador.
@export var max_health: int = 100

## Dano do golpe do jogador.
@export var attack_damage: int = 15

## Controla se o jogador pode se mover e atacar (congelado durante diálogos).
var can_move: bool = true

## Vida atual do jogador.
var current_health: int = 100

## Guarda a última direção para a qual o jogador andou (padrão para baixo).
var last_direction: Vector2 = Vector2.DOWN

## Flag para evitar sobreposição de ataques.
var is_attacking: bool = false

## Tempo de invulnerabilidade breve para evitar dano por múltiplos frames.
var is_invulnerable: bool = false

@onready var color_rect: ColorRect = $ColorRect
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var sword_collision: CollisionShape2D = $SwordHitbox/CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	_setup_default_inputs()

	current_health = max_health

	if sword_hitbox:
		sword_hitbox.visible = false
		if not sword_hitbox.body_entered.is_connected(_on_sword_hitbox_body_entered):
			sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)

	if sword_collision:
		sword_collision.disabled = true

	# Notifica a interface inicial
	health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	# Se a movimentação estiver desabilitada, zera a velocidade e não processa entrada
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Captura o vetor de movimentação em 8 direções
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		last_direction = direction.normalized()
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# Acionamento do ataque por Espaço (ui_select / attack)
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_select"):
		attack()

func _unhandled_input(event: InputEvent) -> void:
	if not can_move:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attack()

## Congela movimentação e ações do jogador (chamado por diálogos/cutscenes)
func freeze() -> void:
	can_move = false
	velocity = Vector2.ZERO

## Descongela movimentação e ações do jogador
func unfreeze() -> void:
	can_move = true

## Recupera pontos de vida e emite atualização
func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

## Executa o ataque corpo a corpo
func attack() -> void:
	if is_attacking or not can_move:
		return

	is_attacking = true

	if sword_hitbox and sword_collision:
		# Posiciona na frente do jogador de acordo com a última direção
		sword_hitbox.position = last_direction * 28.0
		sword_hitbox.rotation = last_direction.angle()
		sword_hitbox.visible = true
		sword_collision.disabled = false

		if is_inside_tree():
			var timer := get_tree().create_timer(0.15)
			timer.timeout.connect(_on_attack_hit_window_finished)
		else:
			_on_attack_hit_window_finished()
	else:
		is_attacking = false

func _on_attack_hit_window_finished() -> void:
	if is_instance_valid(sword_collision):
		sword_collision.disabled = true
	if is_instance_valid(sword_hitbox):
		sword_hitbox.visible = false

	if is_inside_tree():
		var cooldown_timer := get_tree().create_timer(0.1)
		cooldown_timer.timeout.connect(func(): is_attacking = false)
	else:
		is_attacking = false

func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		var knockback_dir: Vector2 = (body.global_position - global_position).normalized()
		if knockback_dir == Vector2.ZERO:
			knockback_dir = last_direction
		body.take_damage(attack_damage, knockback_dir)

## Recebe dano, aplica empurrão e reinicia se morrer
func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or current_health <= 0:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	# Empurrão para trás
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 350.0

	# Feedback visual (pisca vermelho)
	if color_rect:
		color_rect.color = Color(1.0, 0.25, 0.25, 1.0)
		var tween := create_tween()
		if tween:
			tween.tween_property(color_rect, "color", Color(0.2, 0.45, 0.95, 1.0), 0.15)

	# Se a vida zerar, reinicia a fase
	if current_health <= 0:
		if is_inside_tree():
			get_tree().reload_current_scene()
		return

	# Breve invulnerabilidade (0.35s) para o jogador não tomar vários hits imediatos
	is_invulnerable = true
	if is_inside_tree():
		var invul_timer := get_tree().create_timer(0.35)
		invul_timer.timeout.connect(func(): is_invulnerable = false)
	else:
		is_invulnerable = false

## Garante mapeamentos padrões para WASD, Setas, Ataque e Interação
func _setup_default_inputs() -> void:
	_register_action("move_left", [KEY_A, KEY_LEFT])
	_register_action("move_right", [KEY_D, KEY_RIGHT])
	_register_action("move_up", [KEY_W, KEY_UP])
	_register_action("move_down", [KEY_S, KEY_DOWN])
	_register_action("attack", [KEY_SPACE])
	_register_action("interact", [KEY_E])

func _register_action(action_name: String, keycodes: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var current_events := InputMap.action_get_events(action_name)
	for keycode in keycodes:
		var already_mapped := false
		for event in current_events:
			if event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode):
				already_mapped = true
				break
		if not already_mapped:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action_name, key_event)
