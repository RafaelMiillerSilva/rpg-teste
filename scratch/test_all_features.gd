extends SceneTree

const LevelManager = preload("res://scripts/level_manager.gd")

func _init() -> void:
	print("--- INICIANDO TESTES DO NOVO SISTEMA ---")
	var success := true

	# 1. Teste Main Menu
	print("1. Testando main_menu.tscn...")
	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	if not menu_scene:
		print("ERRO: Falha ao carregar main_menu.tscn")
		success = false
	else:
		var menu = menu_scene.instantiate()
		var init_btn = menu.get_node_or_null("InitialPlayContainer/InitialPlayButton")
		var menu_container = menu.get_node_or_null("MenuButtonsContainer")
		var story_btn = menu.get_node_or_null("MenuButtonsContainer/StoryModeButton")
		var endless_btn = menu.get_node_or_null("MenuButtonsContainer/EndlessModeButton")
		var quit_btn = menu.get_node_or_null("MenuButtonsContainer/QuitButton")
		var bg = menu.get_node_or_null("WallpaperBackground")
		if init_btn and menu_container and story_btn and endless_btn and quit_btn and bg:
			print("OK: main_menu.tscn possui InitialPlayButton, MenuButtonsContainer e Wallpaper!")
		else:
			print("ERRO: Nós do main_menu ausentes")
			success = false
		menu.free()

	# 2. Teste Level Select
	print("2. Testando level_select.tscn...")
	var select_scene := load("res://scenes/level_select.tscn") as PackedScene
	if not select_scene:
		print("ERRO: Falha ao carregar level_select.tscn")
		success = false
	else:
		var select = select_scene.instantiate()
		var card1 = select.get_node_or_null("MarginContainer/VBoxContainer/CardsContainer/Level1Card")
		var play_btn = select.get_node_or_null("MarginContainer/VBoxContainer/CardsContainer/Level1Card/CardMargin/VBoxContainer/PlayButton")
		var back_btn = select.get_node_or_null("MarginContainer/VBoxContainer/BottomBar/BackButton")
		if card1 and play_btn and back_btn:
			print("OK: level_select.tscn validado com sucesso!")
		else:
			print("ERRO: Nós do level_select ausentes")
			success = false
		select.free()

	# 3. Teste Endless Config
	print("3. Testando endless_config.tscn...")
	var endless_scene := load("res://scenes/endless_config.tscn") as PackedScene
	if not endless_scene:
		print("ERRO: Falha ao carregar endless_config.tscn")
		success = false
	else:
		var endless = endless_scene.instantiate()
		var start_btn = endless.get_node_or_null("MarginContainer/VBoxContainer/BottomContainer/ButtonsBox/StartButton")
		var back_btn = endless.get_node_or_null("MarginContainer/VBoxContainer/BottomContainer/ButtonsBox/BackButton")
		if start_btn and back_btn:
			print("OK: endless_config.tscn validado com sucesso!")
		else:
			print("ERRO: Nós do endless_config ausentes")
			success = false
		endless.free()

	# 4. Teste Goblin King
	print("4. Testando goblin_king.tscn e script...")
	var king_scene := load("res://scenes/enemies/goblin_king.tscn") as PackedScene
	if not king_scene:
		print("ERRO: Falha ao carregar goblin_king.tscn")
		success = false
	else:
		var king = king_scene.instantiate()
		if king.base_max_health == 1800 and king.base_armor == 5 and king.base_damage == 30:
			print("OK: Atributos base do Goblin King conferem (1800 HP, 5 Armadura, 30 Dano)!")
		else:
			print("ERRO: Atributos base incorretos: HP=", king.base_max_health, " Armor=", king.base_armor)
			success = false

		var sprite = king.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite and sprite.sprite_frames:
			var has_idle = sprite.sprite_frames.has_animation("idle")
			var has_walk = sprite.sprite_frames.has_animation("walk")
			var has_tornado = sprite.sprite_frames.has_animation("tornado")
			if has_idle and has_walk and has_tornado:
				print("OK: Goblin King possui animações idle, walk e tornado!")
			else:
				print("ERRO: Animações ausentes no Goblin King")
				success = false
			if abs(sprite.scale.x - 1.8) < 0.05:
				print("OK: Escala do Goblin King é 1.8x!")
			else:
				print("ERRO: Escala do Goblin King diferente de 1.8x: ", sprite.scale)
				success = false
		else:
			print("ERRO: AnimatedSprite2D ausente no Goblin King")
			success = false
		king.free()

	# 5. Teste Victory Screen
	print("5. Testando victory_screen.tscn...")
	var victory_scene := load("res://scenes/victory_screen.tscn") as PackedScene
	if not victory_scene:
		print("ERRO: Falha ao carregar victory_screen.tscn")
		success = false
	else:
		var victory = victory_scene.instantiate()
		var time_lbl = victory.get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/StatsBox/StatsVBox/TimeLabel")
		var record_lbl = victory.get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/StatsBox/StatsVBox/RecordBadge")
		var gold_lbl = victory.get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/StatsBox/StatsVBox/GoldLabel")
		var lvl_btn = victory.get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/ButtonsBox/LevelSelectButton")
		var replay_btn = victory.get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/ButtonsBox/PlayAgainButton")
		if time_lbl and record_lbl and gold_lbl and lvl_btn and replay_btn:
			print("OK: victory_screen.tscn validado com sucesso!")
		else:
			print("ERRO: Nós da victory_screen ausentes")
			success = false
		victory.free()

	# 6. Teste LevelManager Persistência
	print("6. Testando LevelManager e user://level_progress.json...")
	var is_rec = LevelManager.record_level_1_victory(450.0, 85)
	var comp = LevelManager.is_level_1_completed()
	var best_t = LevelManager.get_level_1_best_time()
	if comp and best_t > 0.0:
		print("OK: Progresso salvo e lido com sucesso! Concluído: ", comp, " Melhor tempo: ", LevelManager.format_time(best_t, true))
	else:
		print("ERRO: Falha na persistência do LevelManager")
		success = false
	LevelManager.reset_progress()

	# 7. Teste World HUD Nodes
	print("7. Testando nós da HUD no world.tscn...")
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	if not world_scene:
		print("ERRO: Falha ao carregar world.tscn")
		success = false
	else:
		var world = world_scene.instantiate()
		var stopwatch = world.get_node_or_null("CanvasLayer/StopwatchLabel")
		var boss_bar = world.get_node_or_null("CanvasLayer/BossBarContainer")
		var boss_progress = world.get_node_or_null("CanvasLayer/BossBarContainer/BossProgressBar")
		var boss_text = world.get_node_or_null("CanvasLayer/BossBarContainer/BossProgressBar/BossHealthText")
		if stopwatch and boss_bar and boss_progress and boss_text:
			print("OK: world.tscn possui StopwatchLabel e BossBarContainer!")
		else:
			print("ERRO: Nós de HUD no world.tscn ausentes")
			success = false
		world.free()

	var result_file := FileAccess.open("res://scratch/test_result.txt", FileAccess.WRITE)
	if result_file:
		result_file.store_string("TEST_PASSED: " + str(success))
		result_file.close()

	print("--- TESTES CONCLUÍDOS COM SUCESSO: ", success, " ---")
	quit(0 if success else 1)
