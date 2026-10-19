extends SceneTree

func _init() -> void:
	print("--- TESTE DE VALIDAÇÃO: GOBLIN GIANT, STUN E DUST ---")

	# 1. Validar cena do dust_effect
	var dust_scene := load("res://scenes/dust_effect.tscn") as PackedScene
	assert(dust_scene != null, "Falha ao carregar dust_effect.tscn")
	var dust := dust_scene.instantiate() as AnimatedSprite2D
	assert(dust.sprite_frames.has_animation("dust_1"), "Dust deve conter anim dust_1")
	assert(dust.sprite_frames.has_animation("dust_2"), "Dust deve conter anim dust_2")
	dust.queue_free()
	print("✔ scenes/dust_effect.tscn e SpriteFrames validados com sucesso!")

	# 2. Validar cena do stun_effect
	var stun_scene := load("res://scenes/stun_effect.tscn") as PackedScene
	assert(stun_scene != null, "Falha ao carregar stun_effect.tscn")
	var stun := stun_scene.instantiate() as AnimatedSprite2D
	assert(stun.sprite_frames.has_animation("stun"), "Stun deve conter anim stun")
	assert(stun.sprite_frames.get_frame_count("stun") == 8, "Stun deve conter 8 frames")
	stun.queue_free()
	print("✔ scenes/stun_effect.tscn e 8 frames de estrelas validados com sucesso!")

	# 3. Validar goblin_giant.tscn e script
	var giant_scene := load("res://scenes/enemies/goblin_giant.tscn") as PackedScene
	assert(giant_scene != null, "Falha ao carregar goblin_giant.tscn")
	var giant := giant_scene.instantiate()
	var giant_sprite := giant.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert(giant_sprite != null, "Giant deve ter AnimatedSprite2D")
	assert(giant_sprite.scale.x >= 1.30, "Escala do sprite deve ter aumentado 10% (1.32)")
	assert(giant.base_damage == 39, "Dano base deve ser 39 (35 + 10%)")
	assert(giant.SMASH_RANGE >= 120.0, "SMASH_RANGE deve ter aumentado 10%")
	assert(giant.SMASH_AREA_RADIUS >= 155.0, "SMASH_AREA_RADIUS deve ter aumentado 10%")
	var col_shape := giant.get_node("CollisionShape2D") as CollisionShape2D
	assert(col_shape.shape.size.x >= 105.0, "Colisão deve ter aumentado 10%")
	giant.queue_free()
	print("✔ Goblin Giant (+10% tamanho e +10% dano) validado com sucesso!")

	# 4. Validar método apply_stun no Player e nos Aliados
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	assert(player_scene != null, "Falha ao carregar player.tscn")
	var player := player_scene.instantiate()
	assert(player.has_method("apply_stun"), "Player deve possuir método apply_stun")
	assert("is_stunned" in player, "Player deve possuir flag is_stunned")
	player.apply_stun(1.0)
	assert(player.is_stunned == true, "Player deve estar em stun após apply_stun")
	player.queue_free()
	print("✔ Player stun validado com sucesso!")

	var ally_warrior_scene := load("res://scenes/ally_warrior.tscn") as PackedScene
	var warrior := ally_warrior_scene.instantiate()
	assert(warrior.has_method("apply_stun"), "Ally Warrior deve ter apply_stun")
	warrior.apply_stun(1.0)
	assert(warrior.is_stunned == true, "Warrior deve estar stunned")
	warrior.queue_free()
	print("✔ Ally Warrior stun validado com sucesso!")

	var ally_lancer_scene := load("res://scenes/ally_lancer.tscn") as PackedScene
	var lancer := ally_lancer_scene.instantiate()
	assert(lancer.has_method("apply_stun"), "Ally Lancer deve ter apply_stun")
	lancer.apply_stun(1.0)
	assert(lancer.is_stunned == true, "Lancer deve estar stunned")
	lancer.queue_free()
	print("✔ Ally Lancer stun validado com sucesso!")

	var ally_archer_scene := load("res://scenes/ally_archer.tscn") as PackedScene
	var archer := ally_archer_scene.instantiate()
	assert(archer.has_method("apply_stun"), "Ally Archer deve ter apply_stun")
	archer.apply_stun(1.0)
	assert(archer.is_stunned == true, "Archer deve estar stunned")
	archer.queue_free()
	print("✔ Ally Archer stun validado com sucesso!")

	var ally_monk_scene := load("res://scenes/ally_monk.tscn") as PackedScene
	var monk := ally_monk_scene.instantiate()
	assert(monk.has_method("apply_stun"), "Ally Monk deve ter apply_stun")
	monk.apply_stun(1.0)
	assert(monk.is_stunned == true, "Monk deve estar stunned")
	monk.queue_free()
	print("✔ Ally Monk stun validado com sucesso!")

	var pawn_scene := load("res://scenes/pawn_gold.tscn") as PackedScene
	var pawn := pawn_scene.instantiate()
	assert(pawn.has_method("apply_stun"), "Pawn Gold deve ter apply_stun")
	pawn.apply_stun(1.0)
	assert(pawn.is_stunned == true, "Pawn deve estar stunned")
	pawn.queue_free()
	print("✔ Pawn Gold stun validado com sucesso!")

	# 5. Validar carregamento do world.tscn sem conflitos
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	assert(world_scene != null, "Falha ao carregar world.tscn")
	print("✔ scenes/world.tscn carregada perfeitamente com todas as alterações!")

	print("--- TODOS OS TESTES PASSARAM COM SUCESSO! ---")
	quit(0)
