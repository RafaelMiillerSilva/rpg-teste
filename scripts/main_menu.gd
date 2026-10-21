extends Control

@onready var initial_play_container: Control = $InitialPlayContainer
@onready var initial_play_button: Button = $InitialPlayContainer/InitialPlayButton
@onready var menu_buttons_container: VBoxContainer = $MenuButtonsContainer
@onready var story_mode_button: Button = $MenuButtonsContainer/StoryModeButton
@onready var endless_mode_button: Button = $MenuButtonsContainer/EndlessModeButton
@onready var quit_button: Button = $MenuButtonsContainer/QuitButton

const LEVEL_SELECT_PATH: String = "res://scenes/level_select.tscn"
const ENDLESS_CONFIG_PATH: String = "res://scenes/endless_config.tscn"
const SoundManager = preload("res://scripts/sound_manager.gd")

func _ready() -> void:
	# Garante que o jogo abra em tela cheia/maximizada sem modo janela (exclusive fullscreen)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# Ao abrir o jogo, exibe somente o botão Jogar no meio da tela um pouco para baixo
	if initial_play_container:
		initial_play_container.visible = true
		initial_play_container.modulate.a = 1.0
	if menu_buttons_container:
		menu_buttons_container.visible = false
		menu_buttons_container.modulate.a = 0.0

	# Inicia a playlist musical do menu em loop contínuo
	SoundManager.play_music_playlist("menu")

	var buttons: Array[Button] = [initial_play_button, story_mode_button, endless_mode_button, quit_button]
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(SoundManager.play_hover)

	if initial_play_button:
		initial_play_button.pressed.connect(_on_initial_play_pressed)
	if story_mode_button:
		story_mode_button.pressed.connect(_on_story_mode_pressed)
	if endless_mode_button:
		endless_mode_button.pressed.connect(_on_endless_mode_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	_load_audio_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.alt_pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)):
			var current_mode := DisplayServer.window_get_mode()
			if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if menu_buttons_container and menu_buttons_container.visible:
			_show_initial_play()

func _show_initial_play() -> void:
	SoundManager.play_confirm()
	if not menu_buttons_container:
		menu_buttons_container = get_node_or_null("MenuButtonsContainer")
	if not initial_play_container:
		initial_play_container = get_node_or_null("InitialPlayContainer")
	if not initial_play_button and initial_play_container:
		initial_play_button = initial_play_container.get_node_or_null("InitialPlayButton")

	if menu_buttons_container:
		menu_buttons_container.visible = false
	if initial_play_container:
		initial_play_container.visible = true
		initial_play_container.modulate.a = 0.0
		var t := create_tween()
		if t:
			t.tween_property(initial_play_container, "modulate:a", 1.0, 0.2)
		else:
			initial_play_container.modulate.a = 1.0
		if initial_play_button and is_inside_tree():
			initial_play_button.grab_focus()

func _on_initial_play_pressed() -> void:
	SoundManager.play_confirm()
	if not initial_play_container:
		initial_play_container = get_node_or_null("InitialPlayContainer")
	if not menu_buttons_container:
		menu_buttons_container = get_node_or_null("MenuButtonsContainer")
	if not story_mode_button and menu_buttons_container:
		story_mode_button = menu_buttons_container.get_node_or_null("StoryModeButton")

	if initial_play_container:
		initial_play_container.visible = false
	if menu_buttons_container:
		menu_buttons_container.visible = true
		menu_buttons_container.modulate.a = 0.0
		var t := create_tween()
		if t:
			t.tween_property(menu_buttons_container, "modulate:a", 1.0, 0.2)
		else:
			menu_buttons_container.modulate.a = 1.0
		if story_mode_button and is_inside_tree():
			story_mode_button.grab_focus()

func _on_story_mode_pressed() -> void:
	SoundManager.play_confirm()
	UpgradeManager.reset_upgrades()
	get_tree().change_scene_to_file(LEVEL_SELECT_PATH)

func _on_endless_mode_pressed() -> void:
	SoundManager.play_confirm()
	UpgradeManager.reset_upgrades()
	get_tree().change_scene_to_file(ENDLESS_CONFIG_PATH)

func _on_quit_pressed() -> void:
	SoundManager.play_confirm()
	get_tree().quit()

func _load_audio_settings() -> void:
	const SETTINGS_FILE_PATH: String = "user://audio_settings.json"
	if FileAccess.file_exists(SETTINGS_FILE_PATH):
		var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK and typeof(json.data) == TYPE_DICTIONARY:
				if json.data.has("master_volume"):
					var val: float = float(json.data["master_volume"])
					var bus_idx := AudioServer.get_bus_index("Master")
					if bus_idx < 0:
						bus_idx = 0
					if val <= 0.01:
						AudioServer.set_bus_mute(bus_idx, true)
					else:
						AudioServer.set_bus_mute(bus_idx, false)
						var t: float = clampf(val / 100.0, 0.00001, 1.0)
						var linear: float = pow(t, 2.5)
						AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
