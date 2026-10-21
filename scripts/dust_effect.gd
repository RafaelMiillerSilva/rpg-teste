extends AnimatedSprite2D

var _custom_anim_set: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 2
	if not _custom_anim_set:
		var anims: Array[String] = ["dust_1", "dust_2"]
		var chosen: String = anims[randi() % anims.size()]
		play(chosen)
	if not animation_finished.is_connected(_on_anim_finished):
		animation_finished.connect(_on_anim_finished)

func setup_dust_2() -> void:
	_custom_anim_set = true
	animation = &"dust_2"
	play("dust_2")

func setup_dust_1() -> void:
	_custom_anim_set = true
	animation = &"dust_1"
	play("dust_1")

func _on_anim_finished() -> void:
	queue_free()
