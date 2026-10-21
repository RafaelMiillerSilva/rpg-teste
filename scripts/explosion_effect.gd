class_name ExplosionEffect
extends AnimatedSprite2D

## Efeito de explosão para animação de derrota do Boss (Explosion_01 e Explosion_02).

var _custom_anim_set: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4
	if not _custom_anim_set:
		var anims: Array[String] = ["explosion_1", "explosion_2"]
		var chosen: String = anims[randi() % anims.size()]
		play(chosen)
	if not animation_finished.is_connected(_on_anim_finished):
		animation_finished.connect(_on_anim_finished)

func setup_explosion_1() -> void:
	_custom_anim_set = true
	animation = &"explosion_1"
	play("explosion_1")

func setup_explosion_2() -> void:
	_custom_anim_set = true
	animation = &"explosion_2"
	play("explosion_2")

func _on_anim_finished() -> void:
	queue_free()
