extends CharacterBody2D

const UpgradeManager = preload("res://scripts/upgrade_manager.gd")
const STUN_EFFECT_SCENE: PackedScene = preload("res://scenes/stun_effect.tscn")

signal health_changed(current: int, max_hp: int)
signal coins_changed(new_amount: int)
signal potions_changed(new_amount: int)
signal armor_changed(total_armor: int)
signal game_saved()

const SAVE_FILE_PATH: String = "user://savegame.json"

## Velocidade máxima do personagem em pixels por segundo.
@export var speed: float = 250.0

## Taxa de aceleração até atingir a velocidade máxima.
@export var acceleration: float = 2000.0

## Taxa de desaceleração (fricção) até parar completamente.
@export var friction: float = 1800.0

## Vida máxima base do jogador.
@export var max_health: int = 100

## Dano do golpe base do jogador.
@export var attack_damage: int = 25

## Armadura base do jogador (absorção direta de dano).
@export var armor: int = 2

## Quantidade de moedas coletadas pelo jogador.
@export var coins: int = 0

## Quantidade de poções de cura no inventário.
@export var potions: int = 0

## Controla se o jogador pode se mover e atacar (congelado durante diálogos).
var can_move: bool = true

## Vida atual do jogador.
var current_health: int = 100

## Guarda a última direção para a qual o jogador andou (padrão para baixo).
var last_direction: Vector2 = Vector2.DOWN

## Flag para evitar sobreposição de ataques.
var is_attacking: bool = false

## Flag de atordoamento (Stun)
var is_stunned: bool = false
var _stun_timer: float = 0.0
var _stun_effect_instance: Node2D = null

## Tempo de invulnerabilidade breve para evitar dano por múltiplos frames.
var is_invulnerable: bool = false

## Controle de tremor de tela (screen shake)
var _shake_tween: Tween
var _current_attack_hit_bodies: Array[Node2D] = []

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sprite = $AnimatedSprite2D # Retrocompatibilidade
@onready var color_rect = $AnimatedSprite2D # Retrocompatibilidade
@onready var camera: Camera2D = $Camera2D
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var sword_collision: CollisionShape2D = $SwordHitbox/CollisionShape2D
@onready var sword_sprite = $SwordHitbox.get_node_or_null("Sprite2D")
@onready var heal_particles: CPUParticles2D = $HealParticles if has_node("HealParticles") else null

func _ready() -> void:
	add_to_group("player")
	_setup_default_inputs()

	max_health = 100 + UpgradeManager.get_bonus_health()
	current_health = max_health

	if not UpgradeManager.upgrades_changed.is_connected(_on_upgrades_changed):
		UpgradeManager.upgrades_changed.connect(_on_upgrades_changed)

	if animated_sprite:
		animated_sprite.play("idle")
		_update_sprite_offset()
		if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
			animated_sprite.animation_finished.connect(_on_animation_finished)
		if not animated_sprite.frame_changed.is_connected(_on_sprite_frame_changed):
			animated_sprite.frame_changed.connect(_on_sprite_frame_changed)

	if sword_hitbox:
		sword_hitbox.visible = false
		if not sword_hitbox.body_entered.is_connected(_on_sword_hitbox_body_entered):
			sword_hitbox.body_entered.connect(_on_sword_hitbox_body_entered)

	if sword_collision:
		sword_collision.disabled = true

	if sword_sprite:
		sword_sprite.visible = false

	# Notifica a interface inicial
	health_changed.emit(current_health, max_health)
	coins_changed.emit(coins)
	potions_changed.emit(potions)
	armor_changed.emit(get_total_armor())

func _physics_process(delta: float) -> void:
	# Atalhos de save/load e poção via Input actions
	if Input.is_action_just_pressed("save_game"):
		save_game()
	elif Input.is_action_just_pressed("load_game"):
		load_game()
	elif Input.is_action_just_pressed("use_potion"):
		use_potion()

	# Se estiver atordoado, desacelera até parar e não aceita comandos de movimento ou ataque
	if is_stunned:
		_stun_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
			_update_sprite_offset()
		if _stun_timer <= 0.0:
			is_stunned = false
		return

	# Se a movimentação estiver desabilitada, zera a velocidade e não processa entrada
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
			_update_sprite_offset()
		return

	# Captura o vetor de movimentação em 8 direções
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		last_direction = direction.normalized()
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
		# Vira o sprite para a direção horizontal de movimento
		if animated_sprite and not is_attacking and abs(direction.x) > 0.1:
			animated_sprite.flip_h = direction.x < 0.0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# Atualiza a animação de acordo com a movimentação
	var is_moving: bool = velocity.length() > 20.0
	if animated_sprite and not is_attacking:
		if is_moving:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
				_update_sprite_offset()
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
				_update_sprite_offset()

	# Acionamento do ataque por Espaço (ui_select / attack)
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("ui_select"):
		attack()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6:
			save_game()
		elif event.keycode == KEY_F7:
			load_game()
		elif event.keycode == KEY_Q:
			use_potion()

	if not can_move or is_stunned:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
		if mouse_dir != Vector2.ZERO:
			last_direction = mouse_dir
		attack()

## Retrocompatibilidade com lógica antiga de animação
func _process_walk_animation(_is_moving: bool) -> void:
	pass

## Tremor de tela de 0.2 segundos com amortecimento gradual
func screen_shake(duration: float = 0.2, strength: float = 7.0) -> void:
	if not camera:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween()
	var steps: int = 5
	var step_time: float = duration / float(steps)
	for i in range(steps):
		var decay: float = 1.0 - (float(i) / float(steps))
		var offset_rand := Vector2(
			randf_range(-strength, strength) * decay,
			randf_range(-strength, strength) * decay
		)
		_shake_tween.tween_property(camera, "offset", offset_rand, step_time)
	_shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)

## Congela movimentação e ações do jogador (chamado por diálogos/cutscenes)
func freeze() -> void:
	can_move = false
	velocity = Vector2.ZERO
	if animated_sprite:
		animated_sprite.play("idle")
		_update_sprite_offset()

## Descongela movimentação e ações do jogador
func unfreeze() -> void:
	can_move = true

## Aplica efeito de atordoamento (Stun): impede ações e exibe estrelas sobre a cabeça
func apply_stun(duration: float = 1.0) -> void:
	if current_health <= 0:
		return
	is_stunned = true
	_stun_timer = maxf(_stun_timer, duration)
	is_attacking = false
	_deactivate_staff_hitbox()
	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")
		_update_sprite_offset()

	if is_instance_valid(_stun_effect_instance):
		_stun_effect_instance.refresh_duration(_stun_timer)
	elif STUN_EFFECT_SCENE and is_inside_tree():
		_stun_effect_instance = STUN_EFFECT_SCENE.instantiate() as Node2D
		_stun_effect_instance.setup(self, duration, Vector2(0, -55))
		var parent_node := get_parent()
		if parent_node:
			parent_node.call_deferred("add_child", _stun_effect_instance)

## Adiciona moedas ao inventário e emite atualização
func add_coins(amount: int = 1) -> void:
	coins += amount
	coins_changed.emit(coins)

## Adiciona poções ao inventário e emite atualização
func add_potions(amount: int = 1) -> void:
	potions += amount
	potions_changed.emit(potions)

## Dispara as partículas de cura (faíscas verdes/douradas)
func trigger_heal_particles() -> void:
	if heal_particles:
		heal_particles.restart()
		heal_particles.emitting = true

## Usa uma poção de cura: restaura 35 de vida se tiver poção e não estiver com vida cheia
func use_potion() -> void:
	if potions > 0 and current_health < max_health:
		potions -= 1
		potions_changed.emit(potions)
		SoundManager.play_potion()
		heal(35)

## Recupera pontos de vida e emite atualização
func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	trigger_heal_particles()

## Salva a posição, vida, moedas e poções em user://savegame.json
func save_game() -> void:
	var save_data: Dictionary = {
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"position_x": global_position.x,
		"position_y": global_position.y,
		"current_health": current_health,
		"health": current_health,
		"coins": coins,
		"potions": potions
	}
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string := JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		game_saved.emit()
		print("Jogo salvo com sucesso em ", SAVE_FILE_PATH)
	else:
		push_error("Falha ao salvar jogo em " + SAVE_FILE_PATH)

## Carrega o progresso salvo a partir de user://savegame.json
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("Arquivo de save não encontrado em ", SAVE_FILE_PATH)
		return

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Falha ao abrir arquivo de save: " + str(FileAccess.get_open_error()))
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Erro ao analisar arquivo de save JSON.")
		return

	var data = json.data
	if typeof(data) == TYPE_DICTIONARY:
		var px = data.get("position_x", data.get("pos_x", null))
		var py = data.get("position_y", data.get("pos_y", null))
		if px != null and py != null:
			global_position = Vector2(float(px), float(py))

		var hp = data.get("current_health", data.get("health", null))
		if hp != null:
			current_health = clamp(int(hp), 0, max_health)
			health_changed.emit(current_health, max_health)

		if data.has("coins"):
			coins = int(data["coins"])
			coins_changed.emit(coins)

		if data.has("potions"):
			potions = int(data["potions"])
			potions_changed.emit(potions)

		print("Jogo carregado com sucesso!")

## Executa o ataque mágico com o cajado do Rei Azul
func attack() -> void:
	if is_attacking or not can_move or is_stunned:
		return

	is_attacking = true
	_current_attack_hit_bodies.clear()

	# Vira o sprite para a direção do golpe
	if animated_sprite:
		if abs(last_direction.x) > 0.01:
			animated_sprite.flip_h = last_direction.x < 0.0
		var cd_mult: float = UpgradeManager.get_attack_cooldown_multiplier()
		var anim_speed_scale: float = clampf(1.0 / maxf(0.1, cd_mult), 1.0, 3.0)
		animated_sprite.speed_scale = anim_speed_scale
		animated_sprite.play("attack")
		_update_sprite_offset()

	# Prepara a posição e ângulo da hitbox mágica do cajado
	if sword_hitbox and sword_collision:
		sword_hitbox.position = last_direction * 35.0 + Vector2(0, 15.0)
		sword_hitbox.rotation = last_direction.angle()
		sword_collision.disabled = true
		sword_hitbox.visible = false

## Sincronização visual: ativa o dano no momento exato do arco de energia mágica (Frame 2)
func _on_sprite_frame_changed() -> void:
	if is_attacking and animated_sprite and animated_sprite.animation == "attack":
		if animated_sprite.frame == 2:
			SoundManager.play_slash()
			if is_instance_valid(sword_collision):
				sword_collision.disabled = false
			if is_instance_valid(sword_hitbox):
				sword_hitbox.visible = true
				for b in sword_hitbox.get_overlapping_bodies():
					_on_sword_hitbox_body_entered(b)
		elif animated_sprite.frame == 3:
			_deactivate_staff_hitbox()

func _deactivate_staff_hitbox() -> void:
	if is_instance_valid(sword_collision):
		sword_collision.disabled = true
	if is_instance_valid(sword_hitbox):
		sword_hitbox.visible = false

func _on_attack_hit_window_finished() -> void:
	_deactivate_staff_hitbox()

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "attack":
		_deactivate_staff_hitbox()
		is_attacking = false
		animated_sprite.speed_scale = 1.0
		_current_attack_hit_bodies.clear()
		if can_move and velocity.length() > 20.0:
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")
		_update_sprite_offset()

## Mantém o offset zero já que todos os frames estão padronizados em 192x192 com pés alinhados
func _update_sprite_offset() -> void:
	if not animated_sprite:
		return
	animated_sprite.offset = Vector2.ZERO

func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	if not is_attacking or body in _current_attack_hit_bodies:
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		_current_attack_hit_bodies.append(body)
		var knockback_dir: Vector2 = (body.global_position - global_position).normalized()
		if knockback_dir == Vector2.ZERO:
			knockback_dir = last_direction
		body.take_damage(get_total_attack_damage(), knockback_dir, self)

func get_total_armor() -> int:
	return armor + UpgradeManager.get_bonus_armor()

func get_total_attack_damage() -> int:
	return attack_damage + UpgradeManager.get_bonus_damage()

func _on_upgrades_changed() -> void:
	var old_max := max_health
	max_health = 100 + UpgradeManager.get_bonus_health()
	var diff := max_health - old_max
	if diff > 0:
		current_health = mini(max_health, current_health + diff)
		health_changed.emit(current_health, max_health)
	armor_changed.emit(get_total_armor())

## Recebe dano com redução de armadura, aplica empurrão, toca som, treme a câmera e abre Game Over se a vida zerar
func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, _attacker = null) -> void:
	if is_invulnerable or current_health <= 0:
		return

	var final_damage := maxi(1, amount - get_total_armor())
	current_health = max(0, current_health - final_damage)
	health_changed.emit(current_health, max_health)

	# Efeitos visuais e sonoros de impacto
	SoundManager.play_hit()
	screen_shake(0.2, 7.0)

	# Empurrão para trás
	if knockback_dir != Vector2.ZERO:
		velocity = knockback_dir * 350.0

	# Feedback visual no sprite (pisca vermelho)
	if animated_sprite:
		animated_sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		var tween := create_tween()
		if tween:
			tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)

	# Se a vida zerar, transiciona para a tela de Game Over
	if current_health <= 0:
		if is_inside_tree():
			get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")
		return


	# Breve invulnerabilidade (0.35s) para o jogador não tomar vários hits imediatos
	is_invulnerable = true
	if is_inside_tree():
		var invul_timer := get_tree().create_timer(0.35)
		invul_timer.timeout.connect(func(): is_invulnerable = false)
	else:
		is_invulnerable = false

## Garante mapeamentos padrões para WASD, Setas, Ataque, Interação, Poção e Save/Load
func _setup_default_inputs() -> void:
	_register_action("move_left", [KEY_A, KEY_LEFT])
	_register_action("move_right", [KEY_D, KEY_RIGHT])
	_register_action("move_up", [KEY_W, KEY_UP])
	_register_action("move_down", [KEY_S, KEY_DOWN])
	_register_action("attack", [KEY_SPACE])
	_register_action("interact", [KEY_E])
	_register_action("use_potion", [KEY_Q])
	_register_action("save_game", [KEY_F6])
	_register_action("load_game", [KEY_F7])
	_register_action("pause", [KEY_ESCAPE])

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
