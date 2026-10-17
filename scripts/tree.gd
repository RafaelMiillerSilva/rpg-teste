@tool
extends StaticBody2D

## Árvore do Tiny Swords com Y-Sort automático e suporte às variações Tree1, Tree2, Tree3 e Tree4.
## O ponto de pivô (0,0) é posicionado exatamente na base do tronco no chão.

const TEXTURES: Array[String] = [
	"res://assets/tiny_swords/Terrain/Resources/Wood/Trees/Tree1.png",
	"res://assets/tiny_swords/Terrain/Resources/Wood/Trees/Tree2.png",
	"res://assets/tiny_swords/Terrain/Resources/Wood/Trees/Tree3.png",
	"res://assets/tiny_swords/Terrain/Resources/Wood/Trees/Tree4.png"
]

@export_range(1, 4) var tree_type: int = 1:
	set(val):
		tree_type = clampi(val, 1, 4)
		_update_appearance()

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	y_sort_enabled = true
	# No jogo, se não foi especificado um tipo diferente, distribui variações naturalmente
	if not Engine.is_editor_hint() and tree_type == 1 and randf() < 0.65:
		tree_type = randi_range(1, 4)
	_update_appearance()

func _update_appearance() -> void:
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return

	var idx: int = clampi(tree_type - 1, 0, 3)
	var path: String = TEXTURES[idx]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)

	sprite.region_enabled = true
	if idx < 2:
		# Tree1 e Tree2 são 192x256. Base do tronco alinhada com o chão em (0,0)
		sprite.region_rect = Rect2(0, 0, 192, 256)
		sprite.offset = Vector2(0, -96)
	else:
		# Tree3 e Tree4 são 192x192. Base do tronco alinhada com o chão em (0,0)
		sprite.region_rect = Rect2(0, 0, 192, 192)
		sprite.offset = Vector2(0, -70)
