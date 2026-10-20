extends SceneTree

func _init() -> void:
	var img_walk: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk.png").get_image()
	print("Walk pixel (0,0): ", img_walk.get_pixel(0, 0))
	print("Walk pixel (100,100): ", img_walk.get_pixel(100, 100))
	print("Walk pixel (350,175): ", img_walk.get_pixel(350, 175))
	
	var img_torn: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado.png").get_image()
	print("Torn pixel (0,0): ", img_torn.get_pixel(0, 0))
	
	# Check if there are distinct sub-images or what the non-transparent/transparent parts are:
	# Let's count non-transparent pixels in 4 quadrants or grid
	var w = img_walk.get_width()
	var h = img_walk.get_height()
	print("Walk w=", w, " h=", h)
	quit(0)
