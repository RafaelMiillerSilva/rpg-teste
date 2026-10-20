extends SceneTree

const LevelManager = preload("res://scripts/level_manager.gd")
const GoblinKingClass = preload("res://scripts/goblin_king.gd")

func _init() -> void:
	print("--- TESTE AVANÇADO DE COMBATE E MODOS ---")
	var success := true

	# 1. Testar instanciar e mecânicas do Rei Goblin
	var king_scene := load("res://scenes/enemies/goblin_king.tscn") as PackedScene
	var king = king_scene.instantiate() as GoblinKingClass
	root.add_child(king)

	var initial_hp: int = king.current_health
	if initial_hp != 1800:
		print("ERRO: Vida inicial diferente de 1800: ", initial_hp)
		success = false

	# Teste de dano e armadura (Dano 20 - 5 armadura = 15 sofrido)
	king.take_damage(20)
	if king.current_health == 1785:
		print("OK: Armadura absorveu 5 de dano corretamente (1800 -> 1785)!")
	else:
		print("ERRO: Cálculo de dano/armadura incorreto: ", king.current_health)
		success = false

	# Teste do Tornado
	king._start_tornado_attack()
	if king.is_tornado_active:
		print("OK: Tornado ativado com sucesso!")
	else:
		print("ERRO: Tornado não ativou")
		success = false

	# Simula herói próximo para testar sucção
	var dummy_hero := CharacterBody2D.new()
	dummy_hero.name = "DummyHero"
	dummy_hero.add_to_group("allies")
	dummy_hero.global_position = king.global_position + Vector2(150, 0)
	root.add_child(dummy_hero)

	king._apply_suction_vortex(0.016, [dummy_hero])
	print("Debug dummy_hero vel: ", dummy_hero.velocity, " pos: ", dummy_hero.global_position)
	if dummy_hero.velocity.x < 0.0 or dummy_hero.global_position.x < 150.0:
		print("OK: Vórtice de sucção puxou o aliado em direção ao boss com sucesso!")
	else:
		print("ERRO: Vórtice de sucção não alterou a velocidade do herói")
		success = false

	dummy_hero.queue_free()
	king._end_tornado_attack()
	king.queue_free()

	# 2. Testar composição de ondas nos modos Story vs Endless
	var wm_class := load("res://scripts/wave_manager.gd")
	var wm = wm_class.new()

	# Modo Story no Turno 30
	LevelManager.current_game_mode = "story"
	var story_w30 = wm.generate_wave_composition(30)
	var has_king := false
	for scene in story_w30:
		if "goblin_king" in scene.resource_path:
			has_king = true
			break
	if has_king:
		print("OK: Modo História gera o Rei Goblin no Turno 30!")
	else:
		print("ERRO: Rei Goblin não encontrado na composição do Turno 30 da história")
		success = false

	# Modo Endless no Turno 30 e 35
	LevelManager.current_game_mode = "endless"
	var endless_w30 = wm.generate_wave_composition(30)
	var endless_w35 = wm.generate_wave_composition(35)
	if endless_w30.size() > 0 and endless_w35.size() > 0:
		print("OK: Modo Endless gera ondas contínuas no Turno 30 e Turno 35!")
	else:
		print("ERRO: Modo Endless falhou ao gerar ondas 30+")
		success = false

	wm.free()

	print("--- TESTE AVANÇADO CONCLUÍDO COM SUCESSO: ", success, " ---")
	quit(0 if success else 1)
