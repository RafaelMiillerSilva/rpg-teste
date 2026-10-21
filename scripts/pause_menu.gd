extends CanvasLayer

## Menu de Pausa [ESC] com controle de volume triplo (Geral, SFX, Música), auto ataque, reiniciar e sair.
## ProcessMode ALWAYS permite funcionamento com o jogo pausado.

const SETTINGS_FILE_PATH: String = "user://audio_settings.json"
const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"
const SoundManager = preload("res://scripts/sound_manager.gd")

@onready var overlay: ColorRect = $Overlay
@onready var center_container: CenterContainer = $CenterContainer
@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer

# 3 Barras de Volume (Geral, Efeitos Sonoros, Música)
@onready var master_slider: HSlider = find_child("MasterVolumeSlider", true, false) as HSlider
@onready var master_label: Label = find_child("MasterVolumeValueLabel", true, false) as Label

@onready var sfx_slider: HSlider = find_child("SfxVolumeSlider", true, false) as HSlider
@onready var sfx_label: Label = find_child("SfxVolumeValueLabel", true, false) as Label

@onready var music_slider: HSlider = find_child("MusicVolumeSlider", true, false) as HSlider
@onready var music_label: Label = find_child("MusicVolumeValueLabel", true, false) as Label

# Retrocompatibilidade
var volume_slider: HSlider:
	get: return master_slider
var volume_value_label: Label:
	get: return master_label

@onready var auto_attack_checkbox: CheckBox = find_child("AutoAttackCheckBox", true, false) as CheckBox
@onready var resume_button: Button = find_child("ResumeButton", true, false) as Button
@onready var restart_button: Button = find_child("RestartButton", true, false) as Button
@onready var main_menu_button: Button = find_child("MainMenuButton", true, false) as Button
@onready var quit_button: Button = find_child("QuitButton", true, false) as Button

var is_paused: bool = false
var _master_bus_idx: int = 0
var _sfx_bus_idx: int = -1
var _music_bus_idx: int = -1

func _ensure_nodes() -> void:
	if not master_slider:
		master_slider = find_child("MasterVolumeSlider", true, false) as HSlider
	if not master_label:
		master_label = find_child("MasterVolumeValueLabel", true, false) as Label
	if not sfx_slider:
		sfx_slider = find_child("SfxVolumeSlider", true, false) as HSlider
	if not sfx_label:
		sfx_label = find_child("SfxVolumeValueLabel", true, false) as Label
	if not music_slider:
		music_slider = find_child("MusicVolumeSlider", true, false) as HSlider
	if not music_label:
		music_label = find_child("MusicVolumeValueLabel", true, false) as Label
	if not auto_attack_checkbox:
		auto_attack_checkbox = find_child("AutoAttackCheckBox", true, false) as CheckBox
	if not resume_button:
		resume_button = find_child("ResumeButton", true, false) as Button
	if not restart_button:
		restart_button = find_child("RestartButton", true, false) as Button
	if not main_menu_button:
		main_menu_button = find_child("MainMenuButton", true, false) as Button
	if not quit_button:
		quit_button = find_child("QuitButton", true, false) as Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_nodes()
	SoundManager.ensure_audio_buses()
	_master_bus_idx = AudioServer.get_bus_index("Master")
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	_music_bus_idx = AudioServer.get_bus_index("Music")
	
	_ensure_pause_input_action()
	_load_settings()
	hide_menu()
	
	for btn in [resume_button, restart_button, main_menu_button, quit_button, auto_attack_checkbox]:
		if btn:
			btn.mouse_entered.connect(SoundManager.play_hover)

	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	if auto_attack_checkbox:
		auto_attack_checkbox.toggled.connect(_on_auto_attack_toggled)

	if master_slider:
		master_slider.value_changed.connect(_on_master_volume_changed)
		master_slider.drag_ended.connect(_on_volume_drag_ended)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
		sfx_slider.drag_ended.connect(_on_volume_drag_ended)
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)
		music_slider.drag_ended.connect(_on_volume_drag_ended)

## Registra a ação 'pause' para a tecla ESC caso ainda não exista no InputMap
func _ensure_pause_input_action() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", key_event)

## Captura a tecla ESC ou a ação de pausa globalmente, e atalho F11/Alt+Enter para alternar tela
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.alt_pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)):
			var current_mode := DisplayServer.window_get_mode()
			if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)):
		toggle_pause()
		get_viewport().set_input_as_handled()

## Alterna entre pausar e despausar o jogo
func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()

## Pausa a árvore da cena e exibe o modal
func pause_game() -> void:
	SoundManager.play_pause()
	is_paused = true
	get_tree().paused = true
	show_menu()
	if resume_button:
		resume_button.grab_focus()

## Despausa o jogo e esconde o menu
func resume_game() -> void:
	SoundManager.play_unpause()
	is_paused = false
	get_tree().paused = false
	hide_menu()

func show_menu() -> void:
	visible = true

func hide_menu() -> void:
	visible = false

func _on_resume_pressed() -> void:
	SoundManager.play_confirm()
	resume_game()

func _on_restart_pressed() -> void:
	SoundManager.play_confirm()
	UpgradeManager.reset_upgrades()
	resume_game()
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_main_menu_pressed() -> void:
	SoundManager.play_confirm()
	UpgradeManager.reset_upgrades()
	resume_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_quit_pressed() -> void:
	SoundManager.play_confirm()
	resume_game()
	get_tree().quit()

func _on_master_volume_changed(val: float) -> void:
	if master_slider and master_slider.value != val:
		master_slider.value = val
	if master_label:
		master_label.text = "%d%%" % int(val)
	_apply_bus_volume(_master_bus_idx, val)
	_save_settings()

func _on_sfx_volume_changed(val: float) -> void:
	if sfx_slider and sfx_slider.value != val:
		sfx_slider.value = val
	if sfx_label:
		sfx_label.text = "%d%%" % int(val)
	_apply_bus_volume(_sfx_bus_idx, val)
	_save_settings()

func _on_music_volume_changed(val: float) -> void:
	if music_slider and music_slider.value != val:
		music_slider.value = val
	if music_label:
		music_label.text = "%d%%" % int(val)
	_apply_bus_volume(_music_bus_idx, val)
	_save_settings()

func _on_volume_drag_ended(value_changed: bool) -> void:
	if value_changed:
		SoundManager.play_coin()

func _on_auto_attack_toggled(button_pressed: bool) -> void:
	SoundManager.play_confirm()
	_apply_auto_attack(button_pressed)
	_save_settings()

## Aplica o status de auto-ataque no Player
func _apply_auto_attack(enabled: bool) -> void:
	var player_script = load("res://scripts/player.gd")
	if player_script and "auto_attack_enabled" in player_script:
		player_script.auto_attack_enabled = enabled

	if is_inside_tree() and get_tree():
		var player := get_tree().get_first_node_in_group("player")
		if player and "auto_attack_enabled" in player:
			player.auto_attack_enabled = enabled

## Aplica o volume com curva logarítmica/potência perceptiva natural aos ouvidos humanos
func _apply_bus_volume(bus_idx: int, val: float) -> void:
	if bus_idx < 0:
		return
	if val <= 0.01:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var t: float = clampf(val / 100.0, 0.00001, 1.0)
		var linear: float = pow(t, 2.5)
		var db: float = linear_to_db(linear)
		AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_volume(val: float) -> void:
	_apply_bus_volume(_master_bus_idx, val)

func _update_volume_label(val: float) -> void:
	if master_label:
		master_label.text = "%d%%" % int(val)

## Salva as preferências do usuário no disco
func _save_settings() -> void:
	var m_vol: float = master_slider.value if master_slider else 80.0
	var s_vol: float = sfx_slider.value if sfx_slider else 80.0
	var mus_vol: float = music_slider.value if music_slider else 80.0
	var auto_atk: bool = auto_attack_checkbox.button_pressed if auto_attack_checkbox else false
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		var data := {
			"master_volume": m_vol,
			"sfx_volume": s_vol,
			"music_volume": mus_vol,
			"auto_attack": auto_atk
		}
		file.store_string(JSON.stringify(data))
		file.close()

## Carrega as configurações salvas ou aplica os padrões
func _load_settings() -> void:
	_ensure_nodes()
	var default_m_vol: float = 80.0
	var default_s_vol: float = 80.0
	var default_mus_vol: float = 80.0
	var default_auto_attack: bool = false
	if FileAccess.file_exists(SETTINGS_FILE_PATH):
		var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK and typeof(json.data) == TYPE_DICTIONARY:
				if json.data.has("master_volume"):
					default_m_vol = float(json.data["master_volume"])
				if json.data.has("sfx_volume"):
					default_s_vol = float(json.data["sfx_volume"])
				elif json.data.has("master_volume"):
					default_s_vol = default_m_vol
				if json.data.has("music_volume"):
					default_mus_vol = float(json.data["music_volume"])
				elif json.data.has("master_volume"):
					default_mus_vol = default_m_vol
				if json.data.has("auto_attack"):
					default_auto_attack = bool(json.data["auto_attack"])
	
	if master_slider:
		master_slider.value = default_m_vol
	if master_label:
		master_label.text = "%d%%" % int(default_m_vol)
	_apply_bus_volume(_master_bus_idx, default_m_vol)

	if sfx_slider:
		sfx_slider.value = default_s_vol
	if sfx_label:
		sfx_label.text = "%d%%" % int(default_s_vol)
	_apply_bus_volume(_sfx_bus_idx, default_s_vol)

	if music_slider:
		music_slider.value = default_mus_vol
	if music_label:
		music_label.text = "%d%%" % int(default_mus_vol)
	_apply_bus_volume(_music_bus_idx, default_mus_vol)

	if auto_attack_checkbox:
		auto_attack_checkbox.button_pressed = default_auto_attack
	_apply_auto_attack(default_auto_attack)
