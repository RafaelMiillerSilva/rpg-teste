@tool
extends StaticBody2D

## Arbusto interativo do Tiny Swords com Y-Sort correto, colisão na base e transparência/tremor.

const TEXTURES: Array[String] = [
	"res://assets/tiny_swords/Terrain/Decorations/Bushes/Bushe1.png",
	"res://assets/tiny_swords/Terrain/Decorations/Bushes/Bushe2.png",
	"res://assets/tiny_swords/Terrain/Decorations/Bushes/Bushe3.png",
	"res://assets/tiny_swords/Terrain/Decorations/Bushes/Bushe4.png"
]

const OFFSETS: Array[Vector2] = [
	Vector2(0, -14),
	Vector2(0, -11),
	Vector2(0, -19),
	Vector2(0, -14)
]

@export_range(1, 4) var bush_type: int = 1:
	set(val):
		bush_type = clampi(val, 1, 4)
		_update_appearance()

@onready var sprite: Sprite2D = $Sprite2D
@onready var foliage_area: Area2D = get_node_or_null("FoliageArea")

var _overlapping_heroes: int = 0
var _fade_tween: Tween
var _rustle_tween: Tween

func _ready() -> void:
	y_sort_enabled = true
	collision_layer = 1
	collision_mask = 0

	_update_appearance()

	if not Engine.is_editor_hint():
		if foliage_area:
			foliage_area.collision_layer = 0
			foliage_area.collision_mask = 5 # Layer 1 (Player) e Layer 4 (Allies)
			foliage_area.body_entered.connect(_on_body_entered)
			foliage_area.body_exited.connect(_on_body_exited)

func _update_appearance() -> void:
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return

	var idx: int = clampi(bush_type - 1, 0, 3)
	var path: String = TEXTURES[idx]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 128, 128)
	sprite.offset = OFFSETS[idx]

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("allies"):
		_overlapping_heroes += 1
		_set_transparency(0.55)
		_rustle()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("allies"):
		_overlapping_heroes = maxi(0, _overlapping_heroes - 1)
		if _overlapping_heroes == 0:
			_set_transparency(1.0)

func _set_transparency(target_alpha: float) -> void:
	if not sprite:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(sprite, "modulate:a", target_alpha, 0.15)

func _rustle() -> void:
	if not sprite:
		return
	if _rustle_tween and _rustle_tween.is_valid():
		_rustle_tween.kill()
	_rustle_tween = create_tween()
	_rustle_tween.tween_property(sprite, "scale", Vector2(1.12, 0.88), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_rustle_tween.tween_property(sprite, "scale", Vector2(0.92, 1.08), 0.08)
	_rustle_tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.08)
