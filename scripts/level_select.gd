extends Control

@onready var status_badge: Label = $MarginContainer/VBoxContainer/CardsContainer/Level1Card/CardMargin/VBoxContainer/StatusBadge
@onready var best_time_label: Label = $MarginContainer/VBoxContainer/CardsContainer/Level1Card/CardMargin/VBoxContainer/BestTimeLabel
@onready var play_button: Button = $MarginContainer/VBoxContainer/CardsContainer/Level1Card/CardMargin/VBoxContainer/PlayButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/BottomBar/BackButton

const LevelManager = preload("res://scripts/level_manager.gd")
const MAIN_MENU_PATH: String = "res://scenes/main_menu.tscn"
const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"

func _ready() -> void:
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	_update_level_info()

func _update_level_info() -> void:
	var completed := LevelManager.is_level_1_completed()
	var best_time := LevelManager.get_level_1_best_time()

	if status_badge:
		if completed:
			status_badge.text = "✅ Concluído"
			status_badge.modulate = Color(0.4, 1.0, 0.4)
		else:
			status_badge.text = "⚔️ Em Aberto"
			status_badge.modulate = Color(1.0, 0.85, 0.3)

	if best_time_label:
		if completed and best_time > 0.0:
			best_time_label.text = "⏱️ Melhor Tempo: " + LevelManager.format_time(best_time, true)
			best_time_label.modulate = Color(1.0, 0.9, 0.5)
		else:
			best_time_label.text = "⏱️ Melhor Tempo: --:--"
			best_time_label.modulate = Color(0.7, 0.7, 0.7, 0.7)

func _on_play_pressed() -> void:
	SoundManager.play_coin()
	LevelManager.current_game_mode = "story"
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)

func _on_back_pressed() -> void:
	SoundManager.play_hit()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
