extends SceneTree

func _init() -> void:
	print("--- INSPECTING KING SPRITE DETAILS ---")
	var img_idle: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_idle.png").get_image()
	print("Idle size: ", img_idle.get_size())
	
	var img_walk: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_walk.png").get_image()
	print("Walk size: ", img_walk.get_size())
	
	var img_tornado: Image = load("res://assets/tiny_swords/Units/monsters/goblin/King_goblin/goblinking_tornado.png").get_image()
	print("Tornado size: ", img_tornado.get_size())

	# Let's check transparency / bounding boxes or horizontal slices
	_check_grid(img_idle, "Idle")
	_check_grid(img_walk, "Walk")
	_check_grid(img_tornado, "Tornado")
	quit(0)

func _check_grid(img: Image, name: String) -> void:
	print("\nAnalyzing ", name, ":")
	# Check vertical projection (columns with pixels)
	var w = img.get_width()
	var h = img.get_height()
	var col_has_pixels: Array[bool] = []
	for x in range(w):
		var has_pix := false
		for y in range(h):
			if img.get_pixel(x, y).a > 0.05:
				has_pix = true
				break
		col_has_pixels.append(has_pix)
	
	# Find spans of active vs empty columns
	var spans: Array[Vector2i] = []
	var in_span := false
	var span_start := 0
	for x in range(w):
		if col_has_pixels[x] and not in_span:
			in_span = true
			span_start = x
		elif not col_has_pixels[x] and in_span:
			in_span = false
			spans.append(Vector2i(span_start, x - 1))
	if in_span:
		spans.append(Vector2i(span_start, w - 1))
	print(name, " column spans (count ", spans.size(), "): ", spans)

	# Check horizontal projection (rows with pixels)
	var row_has_pixels: Array[bool] = []
	for y in range(h):
		var has_pix := false
		for x in range(w):
			if img.get_pixel(x, y).a > 0.05:
				has_pix = true
				break
		row_has_pixels.append(has_pix)
	var row_spans: Array[Vector2i] = []
	in_span = false
	span_start = 0
	for y in range(h):
		if row_has_pixels[y] and not in_span:
			in_span = true
			span_start = y
		elif not row_has_pixels[y] and in_span:
			in_span = false
			row_spans.append(Vector2i(span_start, y - 1))
	if in_span:
		row_spans.append(Vector2i(span_start, h - 1))
	print(name, " row spans (count ", row_spans.size(), "): ", row_spans)
