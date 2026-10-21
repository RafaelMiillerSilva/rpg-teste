extends SceneTree

func _init() -> void:
	print("--- INICIANDO TESTES DE SISTEMA DE SOM, PLAYLISTS E POÇÕES ---")
	var success := true

	# 1. Teste de SoundManager e Playlists
	var sound_mgr_script = load("res://scripts/sound_manager.gd")
	if not sound_mgr_script:
		push_error("FALHA: Não foi possível carregar sound_manager.gd")
		quit(1)
		return

	var sm = sound_mgr_script.new()
	root.add_child(sm)
	sm._ready()

	print("[TESTE 1] Validando carregamento de faixas musicais nas playlists...")
	var playlists: Dictionary = sound_mgr_script.PLAYLISTS
	for cat in playlists.keys():
		var tracks: Array = playlists[cat]
		print("  Categoria '%s': %d faixa(s)" % [cat, tracks.size()])
		for track_path in tracks:
			var stream = sm._load_audio_file(track_path)
			if stream == null or not (stream is AudioStream):
				push_error("  FALHA: Faixa musical não encontrada ou inválida: %s" % track_path)
				success = false
			else:
				print("    ✓ Carregada: %s" % track_path.get_file())

	print("[TESTE 2] Validando carregamento de novos efeitos sonoros (SFX)...")
	var sfx_list = [
		["Passos na Grama", sm.stream_step_grass],
		["Explosão de Fogo", sm.stream_fire_explosion],
		["Hover UI", sm.stream_hover],
		["Confirm UI", sm.stream_confirm],
		["Denied UI", sm.stream_denied],
		["Equip/Upgrade", sm.stream_equip],
		["Pausa", sm.stream_pause],
		["Despausa", sm.stream_unpause],
		["Buff Ataque", sm.stream_atk_buff],
		["Buff Defesa", sm.stream_def_buff],
		["Buff Velocidade", sm.stream_speed_buff],
		["Bloqueio/Escudo", sm.stream_block],
		["Alerta de Boss", sm.stream_boss_alert]
	]
	for item in sfx_list:
		var sfx_name: String = item[0]
		var stream: AudioStream = item[1]
		if stream == null:
			push_error("  FALHA: SFX '%s' não carregado!" % sfx_name)
			success = false
		else:
			print("    ✓ SFX '%s' OK" % sfx_name)

	print("[TESTE 3] Validando reprodução de playlist e loop...")
	sm._start_playlist("menu", 0.0)
	if sm._current_music_category != "menu":
		push_error("  FALHA: Categoria musical incorreta!")
		success = false
	else:
		print("    ✓ Playlist 'menu' iniciada com sucesso.")

	# Simula término da música para testar avanço em loop circular
	var initial_track_idx = sm._current_track_index
	sm._on_music_finished()
	var expected_idx = (initial_track_idx + 1) % sm._current_playlist.size()
	if sm._current_track_index != expected_idx:
		push_error("  FALHA: Avanço de faixa circular falhou!")
		success = false
	else:
		print("    ✓ Avanço de faixa circular verificado: faixa %d -> %d" % [initial_track_idx, sm._current_track_index])

	print("[TESTE 4] Validando Player e uso de 1 poção por clique (com debounce)...")
	var player_script = load("res://scripts/player.gd")
	var player = CharacterBody2D.new()
	player.set_script(player_script)
	root.add_child(player)
	player.max_health = 100
	player.current_health = 40 # Perdeu 60 de vida (cabem quase 2 poções)
	player.potions = 3

	# Primeiro uso da poção
	player.use_potion()
	if player.potions != 2:
		push_error("  FALHA: Quantidade de poções após primeiro uso incorreta: %d (esperado 2)" % player.potions)
		success = false
	elif player.current_health != 75:
		push_error("  FALHA: Vida após poção incorreta: %d (esperado 75)" % player.current_health)
		success = false
	else:
		print("    ✓ Primeiro uso: 1 poção consumida (restam 2), vida 40 -> 75.")

	# Tentativa imediata no mesmo frame (simulando duplo evento da tecla Q)
	player.use_potion()
	if player.potions != 2:
		push_error("  FALHA: Debounce falhou! Poção consumida em duplicidade: %d" % player.potions)
		success = false
	else:
		print("    ✓ Debounce funcionou! Segundo chamado imediato foi ignorado (poções continuam 2).")

	# Simula passagem de tempo do cooldown (0.3s)
	player._physics_process(0.3)
	player.use_potion()
	if player.potions != 1:
		push_error("  FALHA: Uso após cooldown falhou: %d (esperado 1)" % player.potions)
		success = false
	elif player.current_health != 100:
		push_error("  FALHA: Vida após segunda poção incorreta: %d (esperado 100)" % player.current_health)
		success = false
	else:
		print("    ✓ Uso após cooldown: 1 poção consumida (resta 1), vida 75 -> 100.")

	# Vida cheia -> não deve consumir
	player._physics_process(0.3)
	player.use_potion()
	if player.potions != 1:
		push_error("  FALHA: Consumiu poção com vida cheia!")
		success = false
	else:
		print("    ✓ Com vida cheia: nenhuma poção consumida.")

	print("[TESTE 5] Validando drop rate da poção de cura para 5%...")
	var scripts_to_check = [
		"res://scripts/enemies/goblin_base.gd",
		"res://scripts/enemy.gd",
		"res://scripts/enemy_archer.gd"
	]
	for spath in scripts_to_check:
		var f := FileAccess.open(spath, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			f.close()
			if "randf() <= 0.05" in txt:
				print("    ✓ %s tem drop rate de 5%% (randf() <= 0.05)" % spath.get_file())
			else:
				push_error("    FALHA: %s não possui randf() <= 0.05!" % spath.get_file())
				success = false

	if success:
		print("\nTODOS OS TESTES PASSARAM COM 100% DE SUCESSO! 🎉")
		quit(0)
	else:
		push_error("\nALGUNS TESTES FALHARAM!")
		quit(1)
