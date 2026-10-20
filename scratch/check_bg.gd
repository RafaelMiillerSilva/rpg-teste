extends SceneTree

func _init() -> void:
	for name in ["walk", "tornado"]:
		var img: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_" + name + ".png").get_image()
		var bg_color = img.get_pixel(0, 0)
		print(name, " (0,0) color: ", bg_color)
		print(name, " (10,10) color: ", img.get_pixel(10, 10))
		print(name, " (700,10) color: ", img.get_pixel(700, 10))
		print(name, " (700,350) color: ", img.get_pixel(700, 350))
	quit(0)
