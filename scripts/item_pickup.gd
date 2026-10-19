extends Area2D

@export_enum("coin", "potion") var item_type: String = "coin":
	set(value):
		item_type = value
		_update_appearance()

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var color_rect = $Sprite2D # Retrocompatibilidade

const COIN_TEXTURE: Texture2D = preload("res://assets/tiny_swords/Terrain/Resources/Gold/Gold Resource/Gold_Resource.png")
const POTION_TEXTURE: Texture2D = preload("res://assets/sprites/potion.png")

var _bob_tween: Tween

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if item_type == "coin":
		add_to_group("coins")
	_update_appearance()
	_start_bobbing()

func _update_appearance() -> void:
	if not sprite:
		return
	if item_type == "potion":
		sprite.texture = POTION_TEXTURE
		sprite.scale = Vector2(1.0, 1.0)
		sprite.modulate = Color.WHITE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		sprite.texture = COIN_TEXTURE
		sprite.scale = Vector2(0.4, 0.4)
		sprite.modulate = Color.WHITE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Animação de flutuação suave infinita (bobbing effect) via Tween
func _start_bobbing() -> void:
	if not sprite:
		return
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	sprite.position.y = 0.0
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(sprite, "position:y", -6.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(sprite, "position:y", 6.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if item_type == "coin":
		SoundManager.play_coin()
		if body.has_method("add_coins"):
			body.add_coins(1)
		elif "coins" in body:
			body.coins += 1
			if body.has_signal("coins_changed"):
				body.coins_changed.emit(body.coins)
	elif item_type == "potion":
		SoundManager.play_potion()
		if body.has_method("add_potions"):
			body.add_potions(1)
		elif "potions" in body:
			body.potions += 1
			if body.has_signal("potions_changed"):
				body.potions_changed.emit(body.potions)

	queue_free()
