extends SceneTree

var player: CharacterBody2D
var test_step: int = 0

func _init() -> void:
	print("\n=== TESTANDO CORREÇÃO DO TRAVAMENTO DO REI E DANO NA LOJA ===")
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	if not player_scene:
		push_error("ERRO: Falha ao carregar player.tscn")
		quit(1)
		return

	player = player_scene.instantiate() as CharacterBody2D
	root.add_child(player)

func _process(_delta: float) -> bool:
	test_step += 1
	if test_step == 1:
		_run_tests()
	return false

func _run_tests() -> void:
	# --- 1. Testar se freeze_player cancela ataque em andamento sem travar animação ---
	print("\n--- 1. Testando cancelamento de ataque via freeze_player() ---")
	player.attack()
	assert(player.is_attacking == true, "O ataque deveria ter iniciado")
	assert(player.animated_sprite.animation == "attack", "Deveria estar na anim attack")

	# Congela o jogador (como a loja ou NPC faz)
	player.freeze_player()
	assert(player.is_attacking == false, "freeze_player deve resetar is_attacking para false")
	assert(player.animated_sprite.animation == "idle", "freeze_player deve colocar animação em idle")
	assert(player.is_invulnerable == true, "freeze_player deve manter jogador invulnerável")

	# Descongela o jogador
	player.unfreeze_player()
	assert(player.can_move == true, "unfreeze_player deve restaurar can_move")
	assert(player.is_attacking == false, "is_attacking deve continuar false")

	# Deve ser capaz de atacar novamente imediatamente sem travar
	player.attack()
	assert(player.is_attacking == true, "O jogador deve conseguir atacar novamente normalmente")
	print("OK: freeze_player() e unfreeze_player() limpam o estado do ataque sem travar o Rei!")

	# --- 2. Testar failsafe do ataque com delta ---
	print("\n--- 2. Testando failsafe de tempo do ataque ---")
	assert(player._attack_duration_timer > 0.0, "Timer de failsafe deve ter sido iniciado")
	# Simula frames de física sem emitir animation_finished
	for i in range(40):
		player._physics_process(0.016)
	assert(player.is_attacking == false, "Failsafe deve ter finalizado o ataque automaticamente")
	assert(player.animated_sprite.animation == "idle", "Sprite deve voltar para idle")
	print("OK: Failsafe garante que is_attacking nunca fica travado!")

	# --- 3. Testar proteção de dano na loja e diálogos ---
	print("\n--- 3. Testando imunidade a dano na loja / diálogos / pausa ---")
	var initial_hp: int = player.current_health

	# Simula loja aberta (upgrade_menu real no grupo)
	var real_upgrade_menu_scene := load("res://scenes/upgrade_menu.tscn") as PackedScene
	var test_upgrade_menu := real_upgrade_menu_scene.instantiate() as CanvasLayer
	root.add_child(test_upgrade_menu)
	test_upgrade_menu.open_menu("castle")

	player.is_invulnerable = false
	player.take_damage(25, Vector2.RIGHT)
	assert(player.current_health == initial_hp, "Jogador NÃO deve sofrer dano enquanto a loja estiver aberta")
	assert(player.velocity == Vector2.ZERO, "Jogador NÃO deve sofrer knockback na loja")
	test_upgrade_menu.close_menu()
	test_upgrade_menu.queue_free()
	print("OK: Jogador imune a dano com loja aberta!")

	# Simula diálogo aberto (dialogue_box real no grupo)
	var real_dialogue_scene := load("res://scenes/dialogue_box.tscn") as PackedScene
	var test_dialogue := real_dialogue_scene.instantiate() as CanvasLayer
	root.add_child(test_dialogue)
	test_dialogue.start_dialogue(["Teste de diálogo"], "NPC")

	player.is_invulnerable = false
	player.take_damage(25, Vector2.RIGHT)
	assert(player.current_health == initial_hp, "Jogador NÃO deve sofrer dano durante diálogo")
	test_dialogue.end_dialogue()
	test_dialogue.queue_free()
	print("OK: Jogador imune a dano com diálogo ativo!")

	# --- 4. Testar dano no meio do ataque durante o jogo normal ---
	print("\n--- 4. Testando take_damage durante ataque em combate normal ---")
	player.is_invulnerable = false
	player.attack()
	assert(player.is_attacking == true, "Ataque iniciado")
	player.take_damage(10, Vector2.LEFT)
	assert(player.is_attacking == false, "take_damage deve cancelar ataque com segurança")
	assert(player.sword_collision.disabled == true, "Hitbox da espada deve ser desativada no dano")
	print("OK: Tomar dano no ataque cancela o golpe sem travar a animação!")

	# --- 5. Testar UpgradeMenu open_menu e close_menu com Player ---
	print("\n--- 5. Testando UpgradeMenu open_menu() e close_menu() ---")
	var upgrade_menu_scene := load("res://scenes/upgrade_menu.tscn") as PackedScene
	var upgrade_menu := upgrade_menu_scene.instantiate() as CanvasLayer
	root.add_child(upgrade_menu)

	upgrade_menu.open_menu("castle")
	assert(upgrade_menu.is_open == true, "UpgradeMenu deve estar aberto")
	assert(player.can_move == false, "open_menu deve congelar o player")
	assert(player.is_invulnerable == true, "open_menu deve tornar o player invulnerável")

	upgrade_menu.close_menu()
	assert(upgrade_menu.is_open == false, "UpgradeMenu deve estar fechado")
	assert(player.can_move == true, "close_menu deve descongelar o player")
	assert(player.is_invulnerable == true, "close_menu deve conceder carência de invulnerabilidade")
	print("OK: UpgradeMenu congela e descongela o Rei com segurança e carência de invulnerabilidade!")

	print("\n=== TODOS OS TESTES PASSARAM COM SUCESSO! ===")
	quit(0)
