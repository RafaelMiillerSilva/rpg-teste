extends SceneTree

func _init() -> void:
	print("--- CLEANING KING GOBLIN SPRITES ---")
	
	# 1. Clean Walk
	var tex_walk := load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk.png") as Texture2D
	var img_walk: Image = tex_walk.get_image()
	for y in range(img_walk.get_height()):
		for x in range(img_walk.get_width()):
			var p: Color = img_walk.get_pixel(x, y)
			if p.a <= 0.6:
				img_walk.set_pixel(x, y, Color(0, 0, 0, 0))
	img_walk.save_png("assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk_clean.png")
	print("Saved goblinking_walk_clean.png")

	# 2. Clean Tornado
	var tex_torn := load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado.png") as Texture2D
	var img_torn: Image = tex_torn.get_image()
	for y in range(img_torn.get_height()):
		for x in range(img_torn.get_width()):
			var p: Color = img_torn.get_pixel(x, y)
			if p.a <= 0.6:
				img_torn.set_pixel(x, y, Color(0, 0, 0, 0))
	img_torn.save_png("assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado_clean.png")
	print("Saved goblinking_tornado_clean.png")

	quit(0)
