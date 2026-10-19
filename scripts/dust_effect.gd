extends AnimatedSprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	var anims: Array[String] = ["dust_1", "dust_2"]
	var chosen: String = anims[randi() % anims.size()]
	play(chosen)
	animation_finished.connect(func(): queue_free())
