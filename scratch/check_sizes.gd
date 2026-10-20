extends SceneTree

func _init() -> void:
	var f := FileAccess.open("res://scratch/output.txt", FileAccess.WRITE)
	var paths = [
		"res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_idle.png",
		"res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk_clean.png",
		"res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado_clean.png"
	]
	for p in paths:
		var tex = load(p) as Texture2D
		if tex:
			f.store_line("%s size: %s" % [p.get_file(), str(tex.get_size())])
		else:
			f.store_line("Failed: %s" % p)
	f.close()
	quit()
