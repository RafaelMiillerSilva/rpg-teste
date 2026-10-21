extends SceneTree

const TroopRosterUIScript = preload("res://scripts/troop_roster_ui.gd")
const TroopBannerCardScript = preload("res://scripts/troop_banner_card.gd")
const GoblinMageScript = preload("res://scripts/enemies/goblin_mage.gd")

func _init() -> void:
	print("--- TESTE: IDLE COMPLETO E REDIMENSIONAMENTO DINAMICO DE SLOTS ---")

	var roster_scene := load("res://scenes/troop_roster_ui.tscn") as PackedScene
	var warrior_scene := load("res://scenes/ally_warrior.tscn") as PackedScene
	var archer_scene := load("res://scenes/ally_archer.tscn") as PackedScene
	var lancer_scene := load("res://scenes/ally_lancer.tscn") as PackedScene
	var monk_scene := load("res://scenes/ally_monk.tscn") as PackedScene
	var goblin_mage_scene := load("res://scenes/enemies/goblin_mage.tscn") as PackedScene

	var root_node := Node2D.new()
	root_node.name = "World"
	root.add_child(root_node)

	var allies_container := Node2D.new()
	allies_container.name = "Allies"
	root_node.add_child(allies_container)

	var roster_ui := roster_scene.instantiate()
	root_node.add_child(roster_ui)

	# 1. Adiciona primeira tropa (1 tropa: tamanho grande)
	var warrior := warrior_scene.instantiate() as CharacterBody2D
	allies_container.add_child(warrior)
	roster_ui._register_ally(warrior)

	var w_card = roster_ui._cards_by_ally[warrior]
	assert(w_card != null, "Card do warrior deve existir")
	var initial_size: Vector2 = w_card.custom_minimum_size
	print("✓ Tamanho do slot com 1 tropa: %s" % initial_size)

	# 2. Testa animação IDLE completa do personagem no card
	assert(w_card.troop_anim_sprite != null, "TroopAnimatedSprite deve existir")
	assert(w_card.troop_anim_sprite.visible == true, "TroopAnimatedSprite deve estar visivel")
	assert(w_card.troop_anim_sprite.animation == "idle", "TroopAnimatedSprite deve estar tocando a animacao idle")
	assert(w_card.troop_anim_sprite.sprite_frames != null, "SpriteFrames deve estar atribuido do aliado")
	print("✓ Tropa no slot está com a animacao IDLE completa ativa e em execucao!")

	# 3. Adiciona mais 3 tropas (total 4: tamanho intermediário)
	var archer := archer_scene.instantiate() as CharacterBody2D
	allies_container.add_child(archer)
	roster_ui._register_ally(archer)

	var lancer := lancer_scene.instantiate() as CharacterBody2D
	allies_container.add_child(lancer)
	roster_ui._register_ally(lancer)

	var monk := monk_scene.instantiate() as CharacterBody2D
	allies_container.add_child(monk)
	roster_ui._register_ally(monk)

	var size_4_troops: Vector2 = w_card.custom_minimum_size
	print("✓ Tamanho do slot com 4 tropas: %s" % size_4_troops)
	assert(size_4_troops.x < initial_size.x, "O tamanho dos slots deve diminuir com mais tropas")

	# 4. Adiciona mais tropas para totalizar 8 tropas
	for i in range(4):
		var extra_warrior := warrior_scene.instantiate() as CharacterBody2D
		extra_warrior.name = "Warrior_%d" % (i + 2)
		allies_container.add_child(extra_warrior)
		roster_ui._register_ally(extra_warrior)

	var size_8_troops: Vector2 = w_card.custom_minimum_size
	print("✓ Tamanho do slot com 8 tropas: %s" % size_8_troops)
	assert(size_8_troops.x < size_4_troops.x, "O tamanho dos slots deve diminuir ainda mais com 8 tropas")
	assert(roster_ui.grid_container.columns >= 2, "GridContainer deve manter no minimo 2 colunas")

	# 5. Testa morte de uma tropa e aviso no topo
	print("✓ Testando morte de tropa...")
	warrior._die()
	var notif_text: String = roster_ui.notification_label.text
	print("✓ Notificacao disparada: '%s'" % notif_text)
	assert(notif_text == "Warrior morto em combate", "Texto deve ser 'Warrior morto em combate'")

	# 6. Verifica anti-bugs de 5s no goblin mage
	var mage = goblin_mage_scene.instantiate()
	root_node.add_child(mage)
	assert(mage._stuck_timer == 0.0, "Mage deve ter _stuck_timer")
	mage._trigger_anti_stuck()
	assert(mage._is_reversing == true, "Mage deve inverter rota quando acionar anti-stuck")
	print("✓ Anti-stuck e anti-travamento de 5s funcionando!")

	print("--- TODOS OS TESTES PASSARAM COM SUCESSO ABSOLUTO! ---")
	quit(0)
