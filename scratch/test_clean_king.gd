extends SceneTree

func _init() -> void:
	var w = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk_clean.png")
	var t = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado_clean.png")
	var i = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_idle.png")
	print("Clean Walk: ", w != null)
	print("Clean Tornado: ", t != null)
	print("Idle: ", i != null)
	quit(0)
