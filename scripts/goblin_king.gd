class_name GoblinKing
extends GoblinBase

## Chefe Final: Goblin King (Rei Goblin)
## Atributos: 1800 HP, Armadura 5, escala 1.8x.
## Ataque normal pesado a cada 2.5s (30 dano + empurrão).
## Especial Tornado (Vórtice de sucção 280px) a cada 10s por 4.5s (15 de dano a cada 0.8s + som de vento contínuo).

signal boss_health_changed(current_hp: int, max_hp: int)
signal boss_defeated(boss: GoblinKing)

const NORMAL_ATTACK_COOLDOWN: float = 2.5
const NORMAL_ATTACK_DAMAGE: int = 90
const NORMAL_ATTACK_RANGE: float = 156.0

const TORNADO_COOLDOWN: float = 5.0
const TORNADO_DURATION: float = 4.5
const TORNADO_RADIUS: float = 364.0
const TORNADO_PULL_FORCE: float = 420.0
const TORNADO_TICK_INTERVAL: float = 0.8
const TORNADO_TICK_DAMAGE: int = 45

const DUST_SCENE: PackedScene = preload("res://scenes/dust_effect.tscn")
const WIND_SOUND: AudioStream = preload("res://assets/sounds/8_Atk_Magic_SFX/25_Wind_01.wav")

var is_tornado_active: bool = false
var _normal_attack_timer: float = 1.0
var _tornado_cooldown_timer: float = 5.0
var _tornado_duration_timer: float = 0.0
var _tornado_damage_tick_timer: float = 0.0

@onready var wind_audio_player: AudioStreamPlayer2D = $WindAudioPlayer if has_node("WindAudioPlayer") else null

func _init() -> void:
	base_max_health = 5400
	base_damage = 90
	base_speed = 95.0
	base_armor = 15
	max_health = 5400
	current_health = 5400
	damage = 90
	speed = 95.0
	armor = 15
	goblin_type_name = "king"

func _ready() -> void:
	super._ready()
	# Garante os valores oficiais do chefe final com escala 3x
	max_health = 5400
	current_health = 5400
	armor = 15
	damage = 90
	speed = 95.0
	_update_health_bar()
	boss_health_changed.emit(current_health, max_health)

	if not wind_audio_player and is_inside_tree():
		var audio := AudioStreamPlayer2D.new()
		audio.name = "WindAudioPlayer"
		audio.stream = WIND_SOUND
		audio.bus = &"Master"
		audio.volume_db = 2.0
		add_child(audio)
		wind_audio_player = audio

func _apply_turn_scaling() -> void:
	# Mantém a vida e armadura do Chefe Final exatamente como solicitado
	max_health = 5400
	current_health = 5400
	armor = 15
	damage = 90
	speed = 95.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Sistema Anti-Bugs / Anti-Travamento de 5s: executa recuo se estiver em reversão
	if _is_reversing:
		apply_smart_movement(Vector2.ZERO, delta, speed)
		return

	update_avoidance_timer(delta)

	# Atualiza timers de cooldown
	if not is_tornado_active:
		_normal_attack_timer -= delta
		_tornado_cooldown_timer -= delta
	else:
		_process_tornado(delta)
		return

	if not is_instance_valid(current_target) or ("is_dead" in current_target and current_target.is_dead):
		current_target = _find_target()

	if not is_instance_valid(current_target):
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		if animated_sprite and not is_attacking and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		return

	# Checa ativação do tornado especial
	if _tornado_cooldown_timer <= 0.0 and not is_attacking:
		_start_tornado_attack()
		return

	var dist := global_position.distance_to(current_target.global_position)
	var smart_dir := calculate_smart_direction(current_target.global_position)

	if animated_sprite and abs(smart_dir.x) > 0.05:
		animated_sprite.flip_h = smart_dir.x < 0.0

	# Movimento e Ataque Normal Pesado
	if dist > NORMAL_ATTACK_RANGE:
		if not is_attacking:
			apply_smart_movement(smart_dir, delta, speed)
			if animated_sprite and animated_sprite.animation != "walk":
				animated_sprite.play("walk")
			check_player_collisions(func(_target):
				if _normal_attack_timer <= 0.0 and not is_attacking:
					_perform_normal_attack()
			)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		if _normal_attack_timer <= 0.0 and not is_attacking:
			_perform_normal_attack()
		elif not is_attacking and animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")

# ==============================================================================
# ATAQUE NORMAL PESADO (30 dano + empurrão a cada 2.5s)
# ==============================================================================
func _perform_normal_attack() -> void:
	is_attacking = true
	_normal_attack_timer = NORMAL_ATTACK_COOLDOWN

	SoundManager.play_slash()
	_apply_screen_shake(4.0, 0.2)

	# Efeito visual de golpe e avanço frontal
	if animated_sprite:
		animated_sprite.play("walk")
		animated_sprite.speed_scale = 1.8

	if is_instance_valid(current_target):
		var rush_dir := (current_target.global_position - global_position).normalized()
		velocity = rush_dir * 220.0

	if is_inside_tree():
		var timer := get_tree().create_timer(0.3, false)
		timer.timeout.connect(func():
			if is_dead or is_tornado_active:
				return
			_execute_normal_attack_impact()
		)

		var finish_timer := get_tree().create_timer(0.6, false)
		finish_timer.timeout.connect(func():
			if is_attacking and not is_tornado_active and not is_dead:
				is_attacking = false
				if animated_sprite:
					animated_sprite.speed_scale = 1.0
					animated_sprite.play("idle")
		)

func _execute_normal_attack_impact() -> void:
	SoundManager.play_hit()
	_spawn_impact_dust()

	var victims: Array[Node2D] = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
		if global_position.distance_to(player.global_position) <= NORMAL_ATTACK_RANGE * 1.3:
			victims.append(player)

	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			if global_position.distance_to(ally.global_position) <= NORMAL_ATTACK_RANGE * 1.3:
				victims.append(ally as Node2D)

	for victim in victims:
		var knock_dir := (victim.global_position - global_position).normalized()
		if knock_dir == Vector2.ZERO:
			knock_dir = Vector2.DOWN
		if victim.has_method("take_damage"):
			victim.take_damage(NORMAL_ATTACK_DAMAGE, knock_dir * 2.2, self)

# ==============================================================================
# ATAQUE ESPECIAL: TORNADO (Vórtice de Sucção 280px)
# Cooldown 10s, Duração 4.5s, 15 dano a cada 0.8s, som de vento contínuo
# ==============================================================================
func _start_tornado_attack() -> void:
	is_tornado_active = true
	is_attacking = true
	_tornado_duration_timer = TORNADO_DURATION
	_tornado_damage_tick_timer = 0.0
	_tornado_cooldown_timer = TORNADO_COOLDOWN

	if animated_sprite:
		animated_sprite.speed_scale = 1.5
		animated_sprite.play("tornado")

	if wind_audio_player:
		wind_audio_player.play()

	_apply_screen_shake(3.0, 0.4)

func _process_tornado(delta: float) -> void:
	_tornado_duration_timer -= delta
	_tornado_damage_tick_timer -= delta

	# Garante que o som de vento continue em loop durante o tornado
	if wind_audio_player and not wind_audio_player.playing:
		wind_audio_player.play()

	# Movimento suave do boss em direção ao alvo mais próximo enquanto gira
	if is_instance_valid(current_target):
		var dir := (current_target.global_position - global_position).normalized()
		velocity = velocity.move_toward(dir * (speed * 0.7), 200.0 * delta)
		move_and_slide()

	# Vórtice de sucção: puxa o jogador e aliados em direção ao centro do boss (área de 280px)
	_apply_suction_vortex(delta)

	# Causa 15 de dano a cada 0.8s
	if _tornado_damage_tick_timer <= 0.0:
		_tornado_damage_tick_timer = TORNADO_TICK_INTERVAL
		_tick_tornado_damage()

	# Fim da duração do Tornado (4.5s)
	if _tornado_duration_timer <= 0.0:
		_end_tornado_attack()

func _apply_suction_vortex(delta: float, override_heroes: Array[Node2D] = []) -> void:
	var heroes := override_heroes if not override_heroes.is_empty() else _get_all_heroes()
	for hero in heroes:
		var dist := global_position.distance_to(hero.global_position)
		if dist <= TORNADO_RADIUS:
			var pull_dir := (global_position - hero.global_position).normalized()
			var dist_factor: float = 1.0 - (dist / TORNADO_RADIUS)
			var pull_amount: float = TORNADO_PULL_FORCE * (0.4 + dist_factor * 0.6)

			if "velocity" in hero:
				hero.velocity += pull_dir * (pull_amount * delta * 6.0)
			hero.global_position += pull_dir * (pull_amount * delta * 0.7)

func _tick_tornado_damage() -> void:
	SoundManager.play_slash()
	_apply_screen_shake(3.5, 0.25)
	_spawn_tornado_dust()

	var heroes := _get_all_heroes()
	for hero in heroes:
		if global_position.distance_to(hero.global_position) <= TORNADO_RADIUS:
			if hero.has_method("take_damage"):
				hero.take_damage(TORNADO_TICK_DAMAGE, Vector2.ZERO, self)

func _end_tornado_attack() -> void:
	is_tornado_active = false
	is_attacking = false
	_tornado_cooldown_timer = TORNADO_COOLDOWN
	_normal_attack_timer = 1.5

	if wind_audio_player:
		wind_audio_player.stop()

	if animated_sprite:
		animated_sprite.speed_scale = 1.0
		animated_sprite.play("idle")

func _get_all_heroes() -> Array[Node2D]:
	var list: Array[Node2D] = []
	if not is_inside_tree() or not get_tree():
		return list
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and not ("is_dead" in player and player.is_dead):
		list.append(player)
	var allies := get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if is_instance_valid(ally) and not ("is_dead" in ally and ally.is_dead):
			list.append(ally as Node2D)
	return list

# ==============================================================================
# DANO, VIDA E MORTE
# ==============================================================================
func take_damage(amount: int, knockback_dir: Vector2 = Vector2.ZERO, attacker: Node = null) -> void:
	if is_dead:
		return

	# O Rei Goblin tem armadura pesada (5) e quase imune a knockback
	var final_damage := maxi(1, amount - armor)
	current_health -= final_damage
	_update_health_bar()
	boss_health_changed.emit(current_health, max_health)
	SoundManager.play_hit()

	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	modulate = Color(2.0, 0.4, 0.4, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(self, "modulate", Color.WHITE, 0.25)

	# Quase imune a empurrões comuns
	if knockback_dir != Vector2.ZERO:
		velocity += knockback_dir * 18.0

	if is_instance_valid(attacker) and attacker is Node2D:
		current_target = attacker as Node2D

	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	can_attack = false
	is_attacking = false
	is_tornado_active = false

	if wind_audio_player:
		wind_audio_player.stop()

	boss_health_changed.emit(0, max_health)
	boss_defeated.emit(self)

	SoundManager.play_enemy_death()

	# Drop épico de moedas e poções
	for i in range(12):
		_drop_loot()

	super.die()

func _spawn_impact_dust() -> void:
	if not is_inside_tree() or not DUST_SCENE:
		return
	var parent_node := get_parent()
	if not parent_node:
		return
	for i in range(6):
		var dust := DUST_SCENE.instantiate() as Node2D
		dust.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(0, 40))
		dust.scale = Vector2.ONE * randf_range(1.1, 1.6)
		parent_node.call_deferred("add_child", dust)

func _spawn_tornado_dust() -> void:
	if not is_inside_tree() or not DUST_SCENE:
		return
	var parent_node := get_parent()
	if not parent_node:
		return
	for i in range(4):
		var angle := randf() * TAU
		var dust := DUST_SCENE.instantiate() as Node2D
		dust.global_position = global_position + Vector2(cos(angle), sin(angle)) * randf_range(60, 220)
		dust.scale = Vector2.ONE * randf_range(0.9, 1.4)
		parent_node.call_deferred("add_child", dust)

func _apply_screen_shake(intensity: float, duration: float) -> void:
	if not is_inside_tree() or not get_tree():
		return
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if not is_instance_valid(camera):
		return
	var tween := camera.create_tween()
	var shake_offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	tween.tween_property(camera, "offset", shake_offset, duration * 0.5)
	tween.tween_property(camera, "offset", Vector2.ZERO, duration * 0.5)
