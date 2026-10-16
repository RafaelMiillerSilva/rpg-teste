extends Control

@onready var retry_button: Button = $CenterContainer/PanelContainer/VBoxContainer/RetryButton
@onready var menu_button: Button = $CenterContainer/PanelContainer/VBoxContainer/MenuButton

const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu.tscn"

func _ready() -> void:
	SoundManager.play_damage()

	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

func _on_retry_pressed() -> void:
	SoundManager.play_coin()
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_menu_pressed() -> void:
	SoundManager.play_hit()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
