extends SceneTree

func _init() -> void:
	var img: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk.png").get_image()
	var row_high: Array[bool] = []
	for y in range(img.get_height()):
		var has_high := false
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.7:
				has_high = true
				break
		row_high.append(has_high)
	var spans: Array[Vector2i] = []
	var in_span := false
	var start := 0
	for y in range(img.get_height()):
		if row_high[y] and not in_span:
			in_span = true
			start = y
		elif not row_high[y] and in_span:
			in_span = false
			spans.append(Vector2i(start, y - 1))
	if in_span:
		spans.append(Vector2i(start, img.get_height() - 1))
	print("Walk row spans: ", spans)

	var img_torn: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado.png").get_image()
	row_high.clear()
	for y in range(img_torn.get_height()):
		var has_high := false
		for x in range(img_torn.get_width()):
			if img_torn.get_pixel(x, y).a > 0.7:
				has_high = true
				break
		row_high.append(has_high)
	spans.clear()
	in_span = false
	start = 0
	for y in range(img_torn.get_height()):
		if row_high[y] and not in_span:
			in_span = true
			start = y
		elif not row_high[y] and in_span:
			in_span = false
			spans.append(Vector2i(start, y - 1))
	if in_span:
		spans.append(Vector2i(start, img_torn.get_height() - 1))
	print("Tornado row spans: ", spans)
	quit(0)
