extends SceneTree

func _init() -> void:
	print("--- TESTING LOAD OF IMPORTED ASSETS ---")
	var wp: Texture2D = load("res://wallpaper/wallpaper_background.png")
	print("Wallpaper load: ", wp != null, " size: ", wp.get_size() if wp else Vector2.ZERO)

	var idle: Texture2D = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_idle.png")
	print("King Idle load: ", idle != null, " size: ", idle.get_size() if idle else Vector2.ZERO)

	var walk: Texture2D = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk.png")
	print("King Walk load: ", walk != null, " size: ", walk.get_size() if walk else Vector2.ZERO)

	var tornado: Texture2D = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado.png")
	print("King Tornado load: ", tornado != null, " size: ", tornado.get_size() if tornado else Vector2.ZERO)
	quit(0)
