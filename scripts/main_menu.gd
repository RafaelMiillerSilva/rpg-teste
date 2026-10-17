extends Control

@onready var new_game_button: Button = $CenterContainer/PanelContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $CenterContainer/PanelContainer/VBoxContainer/LoadGameButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/QuitButton
@onready var status_label: Label = $CenterContainer/PanelContainer/VBoxContainer/StatusLabel

const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"
const SAVE_PATH: String = "user://savegame.json"

func _ready() -> void:
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if load_game_button:
		load_game_button.pressed.connect(_on_load_game_pressed)
		if not FileAccess.file_exists(SAVE_PATH):
			load_game_button.modulate = Color(0.75, 0.75, 0.75, 0.7)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	_load_audio_settings()
	if status_label:
		status_label.text = ""

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

func _on_new_game_pressed() -> void:
	SoundManager.play_coin()
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_load_game_pressed() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		SoundManager.play_damage()
		if status_label:
			status_label.text = "Nenhum jogo salvo encontrado!"
		return

	SoundManager.play_heal()
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = true
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_quit_pressed() -> void:
	SoundManager.play_hit()
	get_tree().quit()
