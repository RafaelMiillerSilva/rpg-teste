extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar

func _ready() -> void:
	if player and health_bar:
		player.health_changed.connect(_on_player_health_changed)
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health

func _on_player_health_changed(current: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current
