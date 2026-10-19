extends SceneTree

func _init() -> void:
	print("Loading goblin_healer.tscn:")
	var res = load("res://scenes/enemies/goblin_healer.tscn")
	print("Loaded healer:", res)
	print("Loading goblin_giant.tscn:")
	var g = load("res://scenes/enemies/goblin_giant.tscn")
	print("Loaded giant:", g)
	quit()
