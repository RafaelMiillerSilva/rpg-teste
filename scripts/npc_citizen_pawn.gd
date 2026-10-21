class_name NPCCitizenPawn
extends CharacterBody2D

## Cidadão Aldeão Estático da Vila.
## Representa uma das 8 variantes de Pawns do Tiny Swords como morador local.

@export_enum("axe", "hammer", "knife", "meat", "pickaxe", "wood", "normal", "gold") var variant: String = "axe":
	set(val):
		variant = val
		_update_sprite_variant()

@export var citizen_name: String = "Cidadão da Vila"

var is_player_in_range: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var interaction_area: Area2D = $InteractionArea if has_node("InteractionArea") else null
@onready var interaction_label: Label = $InteractionLabel if has_node("InteractionLabel") else null

const CITIZEN_DIALOGUES: Dictionary = {
	"axe": "Majestade! A lenha para o inverno está quase pronta. Que vossa guarda nos proteja dos invasores!",
	"hammer": "Saudações, meu Rei! Estou reforçando as vigas e telhados das casas da nossa vila.",
	"knife": "Bem-vindo, soberano! Cortando as melhores provisões para o banquete da vitória da guarda real.",
	"meat": "Vida longa ao Rei! Nosso rebanho de ovelhas está bem alimentado e seguro atrás dos muros.",
	"pickaxe": "Majestade! As pedras que extraímos da pedreira servem para reparar o castelo e as torres.",
	"wood": "Trabalho duro todo dia para construir um reino próspero, meu nobre Rei!",
	"normal": "Que honra receber o Rei em nossa humilde vila! Estamos todos torcendo por vós!",
	"gold": "Salve, Majestade! Cuido das carruagens de ouro. Melhore a velocidade e capacidade de nossos coletores na Casa dos Peões!"
}

const CITIZEN_NAMES: Dictionary = {
	"axe": "Edgar, o Lenhador",
	"hammer": "Barnaby, o Construtor",
	"knife": "Tobias, o Cozinheiro",
	"meat": "Otis, o Açougueiro",
	"pickaxe": "Goran, o Minerador",
	"wood": "Silas, o Carregador",
	"normal": "Pip, o Camponês",
	"gold": "Midas, o Tesoureiro Local"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("citizens")
	add_to_group("npcs")
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	y_sort_enabled = true

	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").disabled = true

	_update_sprite_variant()

	if interaction_label:
		interaction_label.visible = false

	if interaction_area:
		interaction_area.monitoring = false
		interaction_area.monitorable = false

func _update_sprite_variant() -> void:
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation(variant):
			animated_sprite.play(variant)
	citizen_name = CITIZEN_NAMES.get(variant, "Cidadão da Vila")

func take_damage(_amount: int = 0, _knockback: Vector2 = Vector2.ZERO, _attacker = null) -> void:
	# Cidadãos são pacíficos e não sofrem dano
	pass

func _unhandled_input(_event: InputEvent) -> void:
	# Diálogo desativado por enquanto (compra de tropas feita exclusivamente nas construções)
	return

func _talk() -> void:
	# Diálogo desativado por enquanto (compra de tropas feita exclusivamente nas construções)
	return

func _on_body_entered(_body: Node2D) -> void:
	is_player_in_range = false
	if interaction_label:
		interaction_label.visible = false

func _on_body_exited(_body: Node2D) -> void:
	is_player_in_range = false
	if interaction_label:
		interaction_label.visible = false
