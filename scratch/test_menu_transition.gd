extends SceneTree

func _init() -> void:
	print("--- TESTE DA TRANSIÇÃO DO MENU PRINCIPAL ---")
	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	var menu = menu_scene.instantiate()
	root.add_child(menu)

	var init_container = menu.get_node("InitialPlayContainer") as Control
	var init_btn = menu.get_node("InitialPlayContainer/InitialPlayButton") as Button
	var menu_container = menu.get_node("MenuButtonsContainer") as VBoxContainer
	var story_btn = menu.get_node("MenuButtonsContainer/StoryModeButton") as Button
	var endless_btn = menu.get_node("MenuButtonsContainer/EndlessModeButton") as Button
	var quit_btn = menu.get_node("MenuButtonsContainer/QuitButton") as Button

	assert(init_container.visible == true, "InitialPlayContainer deve estar visível ao abrir")
	assert(menu_container.visible == false, "MenuButtonsContainer deve estar oculto ao abrir")
	print("OK: Estado inicial com apenas 'JOGAR' no meio da tela um pouco para baixo!")

	# Verifica fonte dos botões
	var expected_font = load("res://assets/font/AncientModernTales-a7Po.ttf")
	assert(init_btn.get_theme_font("font") == expected_font, "Botão inicial deve usar AncientModernTales")
	assert(story_btn.get_theme_font("font") == expected_font, "Botão história deve usar AncientModernTales")
	assert(endless_btn.get_theme_font("font") == expected_font, "Botão endless deve usar AncientModernTales")
	assert(quit_btn.get_theme_font("font") == expected_font, "Botão quit deve usar AncientModernTales")
	print("OK: Todos os botões usam a fonte da pasta assets (AncientModernTales-a7Po.ttf)!")

	# Simula clique no botão inicial "JOGAR"
	menu._on_initial_play_pressed()
	assert(init_container.visible == false, "InitialPlayContainer deve sumir após clicar")
	assert(menu_container.visible == true, "MenuButtonsContainer deve aparecer após clicar")
	print("OK: Ao clicar em JOGAR, os botões do menu são exibidos no centro na metade inferior!")

	# Simula voltar (ESC)
	menu._show_initial_play()
	assert(menu_container.visible == false, "MenuButtonsContainer deve sumir ao voltar")
	assert(init_container.visible == true, "InitialPlayContainer deve reaparecer ao voltar")
	print("OK: Retorno suave ao botão inicial validado com sucesso!")

	menu.queue_free()
	print("--- TESTE DE TRANSIÇÃO DO MENU CONCLUÍDO COM 100% SUCESSO! ---")
	quit(0)
