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

	if status_label:
		status_label.text = ""

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
