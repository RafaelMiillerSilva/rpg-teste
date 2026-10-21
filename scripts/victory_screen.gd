extends Control

@onready var title_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var time_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatsBox/StatsVBox/TimeLabel
@onready var record_badge: Label = $MarginContainer/PanelContainer/VBoxContainer/StatsBox/StatsVBox/RecordBadge
@onready var gold_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatsBox/StatsVBox/GoldLabel
@onready var level_select_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonsBox/LevelSelectButton
@onready var play_again_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ButtonsBox/PlayAgainButton

const LevelManager = preload("res://scripts/level_manager.gd")
const LEVEL_SELECT_PATH: String = "res://scenes/level_select.tscn"
const WORLD_SCENE_PATH: String = "res://scenes/world.tscn"
const SoundManager = preload("res://scripts/sound_manager.gd")

var is_in_game_overlay: bool = false:
	set(val):
		is_in_game_overlay = val
		var wp = get_node_or_null("Wallpaper")
		if wp:
			wp.visible = not is_in_game_overlay

func _ready() -> void:
	SoundManager.play_music_playlist("win")

	if is_in_game_overlay or get_parent() is CanvasLayer:
		var wallpaper = get_node_or_null("Wallpaper")
		if wallpaper:
			wallpaper.visible = false

	for btn in [level_select_button, play_again_button]:
		if btn:
			btn.mouse_entered.connect(SoundManager.play_hover)

	if level_select_button:
		level_select_button.pressed.connect(_on_level_select_pressed)
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)

	_populate_victory_data()

func _populate_victory_data() -> void:
	var total_time := LevelManager.last_completion_time
	var is_record := LevelManager.last_is_new_record
	var gold := LevelManager.last_coins_collected

	if time_label:
		time_label.text = "⏱️ Tempo de Conclusão: " + LevelManager.format_time(total_time)

	if record_badge:
		record_badge.visible = is_record

	if gold_label:
		gold_label.text = "🪙 Ouro Coletado: %d" % gold

	SoundManager.play_confirm()
	SoundManager.play_heal()

func _on_level_select_pressed() -> void:
	SoundManager.play_confirm()
	UpgradeManager.reset_upgrades()
	get_tree().change_scene_to_file(LEVEL_SELECT_PATH)

func _on_play_again_pressed() -> void:
	SoundManager.play_confirm()
	UpgradeManager.reset_upgrades()
	LevelManager.current_game_mode = "story"
	var world_script = load("res://scripts/world.gd")
	if world_script and "auto_load_save_on_start" in world_script:
		world_script.auto_load_save_on_start = false
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)
