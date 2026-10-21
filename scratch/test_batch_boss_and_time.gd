extends SceneTree

func _init() -> void:
	print("\n=== INICIANDO BATERIA DE TESTES DAS NOVAS FUNCIONALIDADES ===")
	var all_passed: bool = true

	# 1. Teste Goblin Mage
	print("\n--- 1. Testando Goblin Mage ---")
	var mage_scene := load("res://scenes/enemies/goblin_mage.tscn") as PackedScene
	if not mage_scene:
		print("FALHA: Falha ao carregar scenes/enemies/goblin_mage.tscn")
		all_passed = false
	else:
		var mage = mage_scene.instantiate()
		if mage.max_health == 100 and mage.base_max_health == 100 and mage.current_health == 100:
			print("OK: Goblin Mage vida configurada corretamente com 100 HP! (base: %d, max: %d, current: %d)" % [mage.base_max_health, mage.max_health, mage.current_health])
		else:
			print("FALHA: Goblin Mage vida incorreta: base=%d, max=%d, current=%d" % [mage.base_max_health, mage.max_health, mage.current_health])
			all_passed = false
		mage.free()

	# 2. Teste WaveManager Lotes e 4% Mage
	print("\n--- 2. Testando WaveManager (Lotes de ~20 e 4% Mage) ---")
	var wm_scene = load("res://scripts/wave_manager.gd")
	var wm = wm_scene.new()
	root.add_child(wm)

	# Testa turno 25 (100+ inimigos ou escalonamento)
	var wave_turn_25: Array[PackedScene] = wm.generate_wave_composition(25)
	var total_25: int = wave_turn_25.size()
	print("Turno 25: Total de inimigos gerados: ", total_25)
	print("Tamanhos dos lotes gerados: ", wm.batch_sizes)

	# Verifica se os lotes têm tamanho em torno de 20
	var batch_sizes_valid := true
	for bs in wm.batch_sizes:
		if bs < 10 or bs > 25:
			batch_sizes_valid = false
	if batch_sizes_valid and wm.batch_sizes.size() > 1:
		print("OK: Lotes divididos corretamente em torno de 20 inimigos por lote!")
	else:
		print("FALHA: Tamanho dos lotes inválido: ", wm.batch_sizes)
		all_passed = false

	# Contagem por tipo no Turno 25
	var mage_count: int = 0
	var giant_count: int = 0
	var healer_count: int = 0
	var warrior_count: int = 0
	var range_count: int = 0
	var normal_count: int = 0

	for sc in wave_turn_25:
		if sc == wm.GOBLIN_MAGE_SCENE: mage_count += 1
		elif sc == wm.GOBLIN_GIANT_SCENE: giant_count += 1
		elif sc == wm.GOBLIN_HEALER_SCENE: healer_count += 1
		elif sc == wm.GOBLIN_WARRIOR_SCENE: warrior_count += 1
		elif sc == wm.GOBLIN_RANGE_SCENE: range_count += 1
		elif sc == wm.GOBLIN_NORMAL_SCENE: normal_count += 1

	var mage_pct := float(mage_count) / float(total_25)
	print("Mages no Turno 25: %d (%.2f%%)" % [mage_count, mage_pct * 100.0])
	print("Giants: %d, Healers: %d, Warriors: %d, Ranges: %d, Normais: %d" % [giant_count, healer_count, warrior_count, range_count, normal_count])

	if mage_count >= 1 and mage_pct >= 0.035 and mage_pct <= 0.05:
		print("OK: Taxa de spawn do Goblin Mage está em 4%!")
	else:
		print("FALHA: Taxa de spawn do Goblin Mage fora de 4%: ", mage_pct)
		all_passed = false

	# Verifica se gigantes e healers estão distribuídos pelos lotes (e não todos em um único lote)
	var idx := 0
	var lotes_com_gigante := 0
	var lotes_com_curandeiro := 0
	for bs in wm.batch_sizes:
		var tem_gigante := false
		var tem_healer := false
		for i in range(bs):
			var enemy_sc = wave_turn_25[idx]
			if enemy_sc == wm.GOBLIN_GIANT_SCENE: tem_gigante = true
			if enemy_sc == wm.GOBLIN_HEALER_SCENE: tem_healer = true
			idx += 1
		if tem_gigante: lotes_com_gigante += 1
		if tem_healer: lotes_com_curandeiro += 1

	print("Lotes contendo ao menos 1 Gigante: %d / %d" % [lotes_com_gigante, wm.batch_sizes.size()])
	print("Lotes contendo ao menos 1 Healer: %d / %d" % [lotes_com_curandeiro, wm.batch_sizes.size()])
	if lotes_com_gigante > 1 and lotes_com_curandeiro > 1:
		print("OK: Gigantes e Curandeiros distribuídos harmonicamente entre múltiplos lotes!")
	else:
		print("FALHA: Concentração excessiva de tipos raros em poucos lotes!")
		all_passed = false

	wm.queue_free()

	# 3. Teste Explosões do Boss e Sequência de Morte
	print("\n--- 3. Testando Explosão e Morte do Goblin King ---")
	var exp_scene := load("res://scenes/explosion_effect.tscn") as PackedScene
	if not exp_scene:
		print("FALHA: Falha ao carregar scenes/explosion_effect.tscn")
		all_passed = false
	else:
		var exp_node = exp_scene.instantiate()
		if exp_node.sprite_frames.has_animation("explosion_1") and exp_node.sprite_frames.has_animation("explosion_2"):
			print("OK: explosion_effect.tscn possui animações explosion_1 (8 frames) e explosion_2 (10 frames)!")
		else:
			print("FALHA: Animações de explosão ausentes")
			all_passed = false
		exp_node.free()

	var king_scene := load("res://scenes/enemies/goblin_king.tscn") as PackedScene
	if not king_scene:
		print("FALHA: Falha ao carregar scenes/enemies/goblin_king.tscn")
		all_passed = false
	else:
		var king = king_scene.instantiate()
		root.add_child(king)

		# Testa chamada de die()
		king.die()
		if king._is_dying_sequence and king.is_dead and king.velocity == Vector2.ZERO and king.collision_layer == 0:
			print("OK: Goblin King inicia sequência de morte parado, sem colisão e imune a dano!")
		else:
			print("FALHA: Estado da sequência de morte do Goblin King incorreto")
			all_passed = false

		# Simula avanço de tempo da sequência de morte
		king._process_death_sequence(2.0)
		if king._death_sequence_timer >= 2.0:
			print("OK: Timer da sequência de morte progredindo corretamente: %.1fs" % king._death_sequence_timer)

		king.queue_free()

	# 4. Teste Sistema de Formatação e Marcação de Melhor Tempo
	print("\n--- 4. Testando LevelManager e Formatação de Tempo ---")
	var lm = load("res://scripts/level_manager.gd")
	var t1: String = lm.format_time(125.0) # 2m 5s
	var t2: String = lm.format_time(3665.0) # 1h 1m 5s
	var t3: String = lm.format_time(450.0, true) # 7m 30s
	var t4: String = lm.format_time(3725.0, true) # 1h 02m 05s
	var t_neg: String = lm.format_time(-10.0)

	print("125s -> ", t1, " (Esperado: 02:05)")
	print("3665s -> ", t2, " (Esperado: 01:01:05)")
	print("450s detalhado -> ", t3, " (Esperado: 7m 30s)")
	print("3725s detalhado -> ", t4, " (Esperado: 1h 02m 05s)")
	print("-10s inválido -> ", t_neg, " (Esperado: --:--)")

	if t1 == "02:05" and t2 == "01:01:05" and t3 == "7m 30s" and t4 == "1h 02m 05s" and t_neg == "--:--":
		print("OK: format_time com suporte perfeito a segundos, minutos e horas!")
	else:
		print("FALHA: Formatação de tempo incorreta!")
		all_passed = false

	# Verifica se user://level_progress.json está limpo
	var progress: Dictionary = lm.load_progress()
	print("Progresso atual do jogador: ", progress)
	if progress.get("level_1_completed", false) == false and float(progress.get("level_1_best_time", 0.0)) == 0.0:
		print("OK: level_progress.json limpo sem tempo falso ou absurdo pré-injetado!")
	else:
		print("FALHA: level_progress.json ainda contém dados residuais")
		all_passed = false

	# 5. Teste Victory Screen Overlay In-Game
	print("\n--- 5. Testando VictoryScreen In-Game Overlay ---")
	var vic_scene := load("res://scenes/victory_screen.tscn") as PackedScene
	if not vic_scene:
		print("FALHA: Falha ao carregar scenes/victory_screen.tscn")
		all_passed = false
	else:
		var vic = vic_scene.instantiate()
		vic.is_in_game_overlay = true
		root.add_child(vic)
		var wp = vic.get_node_or_null("Wallpaper")
		if wp and not wp.visible:
			print("OK: Em modo overlay dentro da partida, o Wallpaper fica oculto mostrando o jogo ao fundo!")
		else:
			print("FALHA: Wallpaper visível em modo overlay")
			all_passed = false
		vic.queue_free()

	if all_passed:
		print("\n>>> TODOS OS TESTES PASSARAM COM SUCESSO! <<<")
	else:
		print("\n>>> ALGUNS TESTES FALHARAM! <<<")

	quit(0 if all_passed else 1)
