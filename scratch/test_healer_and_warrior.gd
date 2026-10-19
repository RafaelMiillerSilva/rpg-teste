extends SceneTree

func _init() -> void:
	print("--- TESTE DE VALIDAÇÃO: HEALER E WARRIOR VS GIANT ---")

	# 1. Validar Healer sprite +20% e velocidade -20%
	var healer_scene := load("res://scenes/enemies/goblin_healer.tscn") as PackedScene
	assert(healer_scene != null, "Falha ao carregar goblin_healer.tscn")
	var healer := healer_scene.instantiate()
	var healer_sprite := healer.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert(healer_sprite != null, "Healer deve ter AnimatedSprite2D")
	assert(is_equal_approx(healer_sprite.scale.x, 1.62), "Sprite do Healer deve ter aumentado 20% (1.62)")
	assert(is_equal_approx(healer.base_speed, 76.0), "Velocidade base do Healer deve ser 76.0 (20% mais lento)")
	assert("is_healing" in healer, "Healer deve ter flag is_healing")
	
	# Simula cura e trava de movimentação
	healer.is_healing = true
	healer.velocity = Vector2(100, 100)
	healer._physics_process(0.016)
	assert(healer.velocity == Vector2.ZERO, "Healer deve zerar velocidade imediatamente enquanto is_healing é true")
	healer.queue_free()
	print("✔ Goblin Healer (+20% sprite, -20% velocidade, parado na cura) validado com sucesso!")

	# 2. Validar Warrior vs Giant (alcance efetivo e colisão)
	var warrior_scene := load("res://scenes/ally_warrior.tscn") as PackedScene
	assert(warrior_scene != null, "Falha ao carregar ally_warrior.tscn")
	var warrior := warrior_scene.instantiate()

	var giant_scene := load("res://scenes/enemies/goblin_giant.tscn") as PackedScene
	assert(giant_scene != null, "Falha ao carregar goblin_giant.tscn")
	var giant := giant_scene.instantiate()

	var eff_range_giant: float = warrior.get_effective_attack_range(giant)
	assert(eff_range_giant >= 115.0, "Alcance efetivo contra o Giant deve ser >= 115.0px para superar a colisão (69px)")
	print("✔ Warrior get_effective_attack_range para Giant: ", eff_range_giant, "px (supera colisão de 69px)!")

	# Teste contra goblin normal
	var normal_goblin_scene := load("res://scenes/enemy.tscn") as PackedScene
	if normal_goblin_scene:
		var normal_goblin = normal_goblin_scene.instantiate()
		var eff_range_normal: float = warrior.get_effective_attack_range(normal_goblin)
		assert(eff_range_normal >= 65.0, "Alcance contra normal deve ser normal")
		normal_goblin.queue_free()
		print("✔ Warrior reach contra inimigo comum validado: ", eff_range_normal, "px")

	warrior.queue_free()
	giant.queue_free()

	# 3. Validar world.tscn
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	assert(world_scene != null, "Falha ao carregar world.tscn")
	print("✔ scenes/world.tscn carregada com sucesso!")

	print("--- TODOS OS TESTES PASSARAM COM SUCESSO! ---")
	quit(0)
