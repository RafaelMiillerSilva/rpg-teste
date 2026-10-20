extends Control

@onready var start_button: Button = $MarginContainer/VBoxContainer/BottomContainer/ButtonsBox/StartButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/BottomContainer/ButtonsBox/BackButton

const LevelManager = preload("res://scripts/level_manager.gd")
const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"
const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"

func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_start_pressed() -> void:
	SoundManager.play_coin()
	LevelManager.current_game_mode = "endless"
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_back_pressed() -> void:
	SoundManager.play_hit()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
