extends SceneTree

func _init() -> void:
	var font = load("res://assets/font/AncientModernTales-a7Po.ttf") as FontFile
	if font:
		print("Font loaded successfully: ", font)
		var test_str = "JOGAR Modo História Modo Endless Sair Vitória Seleção de Fases"
		for ch in ["A", "a", "é", "ã", "ó", "ç", "í"]:
			var has_g = font.has_char(ch.unicode_at(0))
			print("Char '", ch, "': ", has_g)
	else:
		print("Failed to load font")
	quit()
