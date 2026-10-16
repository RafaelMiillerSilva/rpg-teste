extends Area2D

@export_enum("coin", "potion") var item_type: String = "coin":
	set(value):
		item_type = value
		_update_appearance()

@onready var color_rect: ColorRect = $ColorRect

const COLOR_COIN: Color = Color(1.0, 0.84, 0.0, 1.0)
const COLOR_POTION: Color = Color(0.95, 0.25, 0.45, 1.0)

var _bob_tween: Tween

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_update_appearance()
	_start_bobbing()

func _update_appearance() -> void:
	if not color_rect:
		return
	if item_type == "potion":
		color_rect.color = COLOR_POTION
	else:
		color_rect.color = COLOR_COIN

## Animação de flutuação suave infinita (bobbing effect) via Tween
func _start_bobbing() -> void:
	if not color_rect:
		return
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	color_rect.position.y = -8.0
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(color_rect, "position:y", -12.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(color_rect, "position:y", -4.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
		SoundManager.play_heal()
		if body.has_method("add_potions"):
			body.add_potions(1)
		elif "potions" in body:
			body.potions += 1
			if body.has_signal("potions_changed"):
				body.potions_changed.emit(body.potions)

	queue_free()
