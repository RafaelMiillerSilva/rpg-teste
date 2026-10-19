extends SceneTree

func _init() -> void:
	print("--- INICIANDO TESTE DE VALIDAÇÃO ---")
	
	# 1. Carrega scenes principais
	var world_scene := load("res://scenes/world.tscn") as PackedScene
	assert(world_scene != null, "Falha ao carregar world.tscn")
	print("✔ scenes/world.tscn carregada com sucesso!")

	var bush_scene := load("res://scenes/bush.tscn") as PackedScene
	assert(bush_scene != null, "Falha ao carregar bush.tscn")
	var bush := bush_scene.instantiate()
	assert(bush.has_node("CollisionShape2D"), "Bush deve ter CollisionShape2D")
	assert(bush.has_node("FoliageArea"), "Bush deve ter FoliageArea")
	bush.queue_free()
	print("✔ scenes/bush.tscn e scripts/bush.gd validados!")

	var lancer_scene := load("res://scenes/ally_lancer.tscn") as PackedScene
	assert(lancer_scene != null, "Falha ao carregar ally_lancer.tscn")
	var lancer := lancer_scene.instantiate()
	var sprite := lancer.get_node("AnimatedSprite2D") as AnimatedSprite2D
	assert(sprite != null, "Lancer deve ter AnimatedSprite2D")
	var sf := sprite.sprite_frames
	assert(sf.has_animation("attack"), "Lancer deve ter anim attack")
	assert(sf.has_animation("attack_right"), "Lancer deve ter anim attack_right")
	assert(sf.has_animation("attack_down"), "Lancer deve ter anim attack_down")
	assert(sf.has_animation("attack_down_right"), "Lancer deve ter anim attack_down_right")
	assert(sf.has_animation("attack_up"), "Lancer deve ter anim attack_up")
	assert(sf.has_animation("attack_up_right"), "Lancer deve ter anim attack_up_right")
	lancer.queue_free()
	print("✔ Ângulos de ataque do Lancer validados com sucesso no SpriteFrames!")

	var healer_scene := load("res://scenes/enemies/goblin_healer.tscn") as PackedScene
	assert(healer_scene != null, "Falha ao carregar goblin_healer.tscn")
	var healer := healer_scene.instantiate()
	assert("HEAL_RANGE" in healer, "Goblin healer deve ter constante HEAL_RANGE")
	assert(healer.HEAL_RANGE <= 250.0, "Área de cura deve ser restrita")
	healer.queue_free()
	print("✔ Goblin Healer e área de alcance validados!")

	print("--- TODOS OS TESTES PASSARAM COM SUCESSO! ---")
	quit(0)
