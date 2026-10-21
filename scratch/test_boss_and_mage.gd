extends SceneTree

func _init() -> void:
	print("--- TESTE UNITÁRIO: BOSS GOBLIN KING & GOBLIN MAGE ---")

	# 1. Teste do Boss Goblin King
	var king_scene := load("res://scenes/enemies/goblin_king.tscn") as PackedScene
	assert(king_scene != null, "Falha ao carregar goblin_king.tscn")
	var king := king_scene.instantiate() as GoblinKing
	assert(king != null, "Falha ao instanciar GoblinKing")

	print("[1/5] Goblin King instanciado com sucesso!")
	print("  - Vida Máxima:", king.max_health, " (Esperado: 5400)")
	print("  - Dano:", king.damage, " (Esperado: 90)")
	print("  - Armadura:", king.armor, " (Esperado: 15)")
	print("  - Alcance Normal (+30%):", king.NORMAL_ATTACK_RANGE, " (Esperado: 156.0)")
	print("  - Raio Tornado (+30%):", king.TORNADO_RADIUS, " (Esperado: 364.0)")
	print("  - Cooldown Tornado:", king.TORNADO_COOLDOWN, " (Esperado: 5.0)")
	print("  - Dano Tick Tornado (3x):", king.TORNADO_TICK_DAMAGE, " (Esperado: 45)")

	assert(king.max_health == 5400, "Vida incorreta")
	assert(king.damage == 90, "Dano incorreto")
	assert(king.armor == 15, "Armadura incorreta")
	assert(king.NORMAL_ATTACK_RANGE >= 155.0, "Alcance de ataque normal incorreto")
	assert(king.TORNADO_RADIUS >= 360.0, "Raio do tornado incorreto")
	assert(king.TORNADO_COOLDOWN == 5.0, "Cooldown do tornado incorreto")
	assert(king.TORNADO_TICK_DAMAGE == 45, "Dano do tornado incorreto")

	var sprite: AnimatedSprite2D = king.get_node("AnimatedSprite2D")
	print("  - Escala do Sprite (+30%):", sprite.scale, " (Esperado: ~2.34)")
	assert(abs(sprite.scale.x - 2.34) < 0.05, "Escala do sprite incorreta")
	king.queue_free()

	# 2. Teste do Goblin Mage
	var mage_scene := load("res://scenes/enemies/goblin_mage.tscn") as PackedScene
	assert(mage_scene != null, "Falha ao carregar goblin_mage.tscn")
	var mage := mage_scene.instantiate() as GoblinMage
	assert(mage != null, "Falha ao instanciar GoblinMage")
	print("[2/5] Goblin Mage instanciado com sucesso!")
	print("  - Dano Base:", mage.base_damage, " (Esperado: 35)")
	print("  - Cooldown de Disparo:", mage.SHOOT_COOLDOWN, " (Esperado: 2.0s)")
	print("  - Alcance Máximo:", mage.MAX_ATTACK_RANGE, " (Esperado: ~430.0)")
	assert(mage.base_damage == 35, "Dano base do mago incorreto")
	assert(mage.SHOOT_COOLDOWN == 2.0, "Cooldown de tiro do mago incorreto")
	mage.queue_free()

	# 3. Teste da Bola de Fogo
	var fb_scene := load("res://scenes/enemies/goblin_fireball.tscn") as PackedScene
	assert(fb_scene != null, "Falha ao carregar goblin_fireball.tscn")
	var fb = fb_scene.instantiate()
	print("[3/5] Bola de Fogo instanciada com sucesso!")
	print("  - Dano de impacto:", fb.damage, " (Esperado: 35)")
	print("  - Raio de explosão:", fb.explosion_radius, " (Esperado: 95.0)")
	assert(fb.damage == 35, "Dano da bola de fogo incorreto")
	fb.queue_free()

	# 4. Teste do Efeito de Fogo (Fire DoT)
	var fire_scene := load("res://scenes/fire_effect.tscn") as PackedScene
	assert(fire_scene != null, "Falha ao carregar fire_effect.tscn")
	var fire_eff = fire_scene.instantiate()
	print("[4/5] Efeito de Fogo (Fire_03) instanciado com sucesso!")
	fire_eff.queue_free()

	# 5. Teste da Composição de Ondas (WaveManager)
	var wm := WaveManager.new()
	var wave24 := wm.generate_wave_composition(24)
	var wave25 := wm.generate_wave_composition(25)
	var wave30_story := wm.generate_wave_composition(30)

	var has_mage_24: bool = false
	for sc in wave24:
		if sc == mage_scene:
			has_mage_24 = true

	var mages_25: int = 0
	for sc in wave25:
		if sc == mage_scene:
			mages_25 += 1

	var mages_30: int = 0
	for sc in wave30_story:
		if sc == mage_scene:
			mages_30 += 1

	print("[5/5] Teste de Ondas (WaveManager):")
	print("  - Turno 24 contém mages?", has_mage_24, " (Esperado: false)")
	print("  - Turno 25 mages spawnados:", mages_25, " (Esperado: >= 1)")
	print("  - Turno 30 História mages spawnados:", mages_30, " (Esperado: 2)")

	assert(not has_mage_24, "Turno 24 não deve conter mages")
	assert(mages_25 >= 1, "Turno 25 deve conter pelo menos 1 mage (2.5%)")
	assert(mages_30 == 2, "Turno 30 deve conter 2 mages na comitiva do Boss")
	wm.queue_free()

	print("\n>>> TODOS OS TESTES PASSARAM COM 100% DE SUCESSO! <<<")
	quit(0)
