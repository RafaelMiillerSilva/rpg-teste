extends SceneTree

const PlayerClass = preload("res://scripts/player.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("\n=== TESTANDO AUTO-ATAQUE E ALCANCE DO REI (+15%) ===")
	var all_passed: bool = true

	# 1. Teste alcance do Rei
	print("\n--- 1. Testando Alcance da Espada/Hitbox (+15%) ---")
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if not player_scene:
		print("FALHA: player.tscn não carregado")
		all_passed = false
	else:
		var player = player_scene.instantiate()
		root.add_child(player)

		var sword_shape: CollisionShape2D = player.get_node_or_null("SwordHitbox/CollisionShape2D")
		if sword_shape and sword_shape.shape is RectangleShape2D:
			var sz: Vector2 = sword_shape.shape.size
			print("Dimensões do SwordHitbox: ", sz, " (Esperado: 92x80.5)")
			if abs(sz.x - 92.0) < 0.1 and abs(sz.y - 80.5) < 0.1:
				print("OK: Hitbox da espada aumentada em 15%!")
			else:
				print("FALHA: Tamanho da hitbox da espada incorreto: ", sz)
				all_passed = false

		if player.get("ATTACK_RANGE") == 115.0:
			print("OK: ATTACK_RANGE configurado para 115.0px (+15%)!")
		else:
			print("FALHA: ATTACK_RANGE incorreto: ", player.get("ATTACK_RANGE"))
			all_passed = false

		# 2. Teste da lógica de Auto Ataque
		print("\n--- 2. Testando Lógica de Auto-Ataque ---")
		var dummy_enemy := CharacterBody2D.new()
		dummy_enemy.add_to_group("enemies")
		root.add_child(dummy_enemy)
		dummy_enemy.global_position = player.global_position + Vector2(80, 0)

		# Com auto-ataque desligado:
		PlayerClass.auto_attack_enabled = false
		player.auto_attack_enabled = false
		player._check_auto_attack()
		if not player.is_attacking:
			print("OK: Com auto-ataque desativado, o rei NÃO ataca sozinho!")
		else:
			print("FALHA: O rei atacou com auto-ataque desativado")
			all_passed = false

		# Com auto-ataque ligado:
		PlayerClass.auto_attack_enabled = true
		player.auto_attack_enabled = true
		player._check_auto_attack()
		if player.is_attacking:
			print("OK: Com auto-ataque ativado, o rei detectou o inimigo no alcance e atacou sozinho!")
		else:
			print("FALHA: O rei NÃO atacou mesmo com inimigo dentro do alcance")
			all_passed = false

		# Testa inimigo fora de alcance (200px)
		player.is_attacking = false
		dummy_enemy.global_position = player.global_position + Vector2(200, 0)
		player._check_auto_attack()
		if not player.is_attacking:
			print("OK: Inimigo a 200px fora de alcance (alcance 115px) não dispara auto-ataque!")
		else:
			print("FALHA: O rei atacou inimigo fora de alcance")
			all_passed = false

		dummy_enemy.queue_free()
		player.queue_free()

	# 3. Teste CheckBox no Menu de Pause
	print("\n--- 3. Testando CheckBox no Menu de Pause ---")
	var pause_scene := load("res://scenes/pause_menu.tscn") as PackedScene
	if not pause_scene:
		print("FALHA: pause_menu.tscn não carregado")
		all_passed = false
	else:
		var pause_menu = pause_scene.instantiate()
		root.add_child(pause_menu)

		var cb: CheckBox = pause_menu.get_node_or_null("CenterContainer/PanelContainer/VBoxContainer/AutoAttackContainer/AutoAttackCheckBox")
		if cb != null:
			print("OK: AutoAttackCheckBox encontrado no PauseMenu!")
			print("Texto da opção: '", cb.text, "'")
			# Simula alternância
			cb.button_pressed = true
			cb.toggled.emit(true)
			if PlayerClass.auto_attack_enabled == true:
				print("OK: CheckBox marcado atualizou PlayerClass.auto_attack_enabled para true!")
			else:
				print("FALHA: Checkbox não sincronizou com PlayerClass.auto_attack_enabled")
				all_passed = false
		else:
			print("FALHA: AutoAttackCheckBox não encontrado na árvore de nós")
			all_passed = false

		pause_menu.queue_free()

	if all_passed:
		print("\n>>> TODOS OS TESTES PASSARAM COM SUCESSO! <<<")
	else:
		print("\n>>> ALGUNS TESTES FALHARAM! <<<")

	quit(0 if all_passed else 1)
