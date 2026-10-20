extends SceneTree

func _init() -> void:
	print("--- CHECKING KING GOBLIN SPRITES WITH IMAGE ---")
	for rel_path in [
		"assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_idle.png",
		"assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk.png",
		"assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado.png"
	]:
		var img := Image.load_from_file(rel_path)
		if img:
			print(rel_path, " -> width: ", img.get_width(), " height: ", img.get_height())
		else:
			print(rel_path, " -> NULL")
	quit(0)
