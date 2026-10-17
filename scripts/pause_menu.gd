extends CanvasLayer

## Menu de Pausa [ESC] com controle de volume, reiniciar e sair.
## ProcessMode ALWAYS permite funcionamento com o jogo pausado.

const SETTINGS_FILE_PATH: String = "user://audio_settings.json"
const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

@onready var overlay: ColorRect = $Overlay
@onready var center_container: CenterContainer = $CenterContainer
@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var volume_slider: HSlider = $CenterContainer/PanelContainer/VBoxContainer/VolumeContainer/VolumeSlider
@onready var volume_value_label: Label = $CenterContainer/PanelContainer/VBoxContainer/VolumeContainer/HeaderContainer/VolumeValueLabel
@onready var resume_button: Button = $CenterContainer/PanelContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/PanelContainer/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/QuitButton

var is_paused: bool = false
var _master_bus_idx: int = 0
var _is_dragging_slider: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master_bus_idx = AudioServer.get_bus_index("Master")
	
	_ensure_pause_input_action()
	_load_volume_setting()
	hide_menu()
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
		volume_slider.drag_started.connect(func(): _is_dragging_slider = true)
		volume_slider.drag_ended.connect(_on_volume_drag_ended)

## Registra a ação 'pause' para a tecla ESC caso ainda não exista no InputMap
func _ensure_pause_input_action() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", key_event)

## Captura a tecla ESC ou a ação de pausa globalmente
func _input(event: InputEvent) -> void:
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
	is_paused = true
	get_tree().paused = true
	show_menu()
	if resume_button:
		resume_button.grab_focus()

## Despausa o jogo e esconde o menu
func resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	hide_menu()

func show_menu() -> void:
	visible = true

func hide_menu() -> void:
	visible = false

func _on_resume_pressed() -> void:
	SoundManager.play_coin()
	resume_game()

func _on_restart_pressed() -> void:
	SoundManager.play_coin()
	resume_game()
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_main_menu_pressed() -> void:
	SoundManager.play_hit()
	resume_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _on_quit_pressed() -> void:
	SoundManager.play_hit()
	resume_game()
	get_tree().quit()

func _on_volume_changed(val: float) -> void:
	_update_volume_label(val)
	_apply_volume(val)
	_save_volume_setting(val)

func _on_volume_drag_ended(value_changed: bool) -> void:
	_is_dragging_slider = false
	if value_changed:
		SoundManager.play_coin()

func _update_volume_label(val: float) -> void:
	if volume_value_label:
		volume_value_label.text = "%d%%" % int(val)

## Aplica o volume com curva logarítmica/potência perceptiva natural aos ouvidos humanos
func _apply_volume(val: float) -> void:
	if _master_bus_idx < 0:
		_master_bus_idx = AudioServer.get_bus_index("Master")
	if _master_bus_idx < 0:
		_master_bus_idx = 0
	
	if val <= 0.01:
		AudioServer.set_bus_mute(_master_bus_idx, true)
	else:
		AudioServer.set_bus_mute(_master_bus_idx, false)
		# Curva perceptiva exponencial (t^2.5):
		# Em 100% -> 0 dB
		# Em 50%  -> ~ -15 dB (sensação equilibrada de metade do volume)
		# Em 10%  -> ~ -50 dB (suave e baixo)
		# Em 2%   -> ~ -85 dB (extremamente baixo, quase um sussurro)
		var t: float = clampf(val / 100.0, 0.00001, 1.0)
		var linear: float = pow(t, 2.5)
		var db: float = linear_to_db(linear)
		AudioServer.set_bus_volume_db(_master_bus_idx, db)

## Salva a preferência de volume do usuário no disco
func _save_volume_setting(val: float) -> void:
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		var data := { "master_volume": val }
		file.store_string(JSON.stringify(data))
		file.close()

## Carrega a configuração salva ou aplica o padrão de 80%
func _load_volume_setting() -> void:
	var default_vol: float = 80.0
	if FileAccess.file_exists(SETTINGS_FILE_PATH):
		var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK and typeof(json.data) == TYPE_DICTIONARY:
				if json.data.has("master_volume"):
					default_vol = float(json.data["master_volume"])
	
	if volume_slider:
		volume_slider.value = default_vol
	_update_volume_label(default_vol)
	_apply_volume(default_vol)
