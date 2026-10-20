extends SceneTree

func _init() -> void:
	var img: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk.png").get_image()
	# Let's inspect unique alpha values or color distribution
	var alphas: Dictionary = {}
	for y in range(0, img.get_height(), 10):
		for x in range(0, img.get_width(), 10):
			var a = snappedf(img.get_pixel(x, y).a, 0.05)
			alphas[a] = alphas.get(a, 0) + 1
	print("Walk alpha distribution: ", alphas)
	
	# Check where alpha is > 0.6 or 0.8
	var w = img.get_width()
	var h = img.get_height()
	var col_high: Array[bool] = []
	for x in range(w):
		var has_high := false
		for y in range(h):
			if img.get_pixel(x, y).a > 0.7:
				has_high = true
				break
		col_high.append(has_high)
	
	var spans: Array[Vector2i] = []
	var in_span := false
	var start := 0
	for x in range(w):
		if col_high[x] and not in_span:
			in_span = true
			start = x
		elif not col_high[x] and in_span:
			in_span = false
			spans.append(Vector2i(start, x - 1))
	if in_span:
		spans.append(Vector2i(start, w - 1))
	print("Walk spans (alpha > 0.7): ", spans)

	# Same for tornado
	var img_torn: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado.png").get_image()
	col_high.clear()
	for x in range(img_torn.get_width()):
		var has_high := false
		for y in range(img_torn.get_height()):
			if img_torn.get_pixel(x, y).a > 0.7:
				has_high = true
				break
		col_high.append(has_high)
	spans.clear()
	in_span = false
	start = 0
	for x in range(img_torn.get_width()):
		if col_high[x] and not in_span:
			in_span = true
			start = x
		elif not col_high[x] and in_span:
			in_span = false
			spans.append(Vector2i(start, x - 1))
	if in_span:
		spans.append(Vector2i(start, img_torn.get_width() - 1))
	print("Tornado spans (alpha > 0.7): ", spans)
	quit(0)
