class_name TroopBannerCard
extends Control

## Cartão de Banner de Tropa Recrutada:
## Exibe o Banner_Slots.png na lateral esquerda com animação IDLE completa da tropa,
## barra de vida em tempo real e adaptação dinâmica de tamanho.

const ICON_WARRIOR: Texture2D = preload("res://assets/ui/troops/icon_warrior.png")
const ICON_ARCHER: Texture2D = preload("res://assets/ui/troops/icon_archer.png")
const ICON_LANCER: Texture2D = preload("res://assets/ui/troops/icon_lancer.png")
const ICON_MONK: Texture2D = preload("res://assets/ui/troops/icon_monk.png")

# Configurações de centralização e escala base para cada classe dentro do banner
const TROOP_CONFIGS := {
	"warrior": {
		"scale": 0.40,
		"offset": Vector2(-5.0, 4.0)
	},
	"archer": {
		"scale": 0.40,
		"offset": Vector2(3.0, 4.0)
	},
	"monk": {
		"scale": 0.42,
		"offset": Vector2(0.0, -3.0)
	},
	"lancer": {
		"scale": 0.27,
		"offset": Vector2(10.0, 20.0)
	}
}

@onready var banner_bg: TextureRect = $BannerBackground
@onready var sprite_container: Control = $SpriteContainer
@onready var troop_anim_sprite: AnimatedSprite2D = $SpriteContainer/TroopAnimatedSprite
@onready var troop_icon: TextureRect = $TroopIcon
@onready var health_bar: ProgressBar = $HealthProgressBar

var _ally_node: Node2D = null
var _unit_name: String = ""
var _is_dying: bool = false
var _fill_style: StyleBoxFlat = null
var _base_scale: float = 0.40
var _base_offset: Vector2 = Vector2.ZERO
var _current_scale_factor: float = 1.0

func _ready() -> void:
	_ensure_nodes()
	_update_internal_layout()

func _ensure_nodes() -> void:
	if not banner_bg:
		banner_bg = get_node_or_null("BannerBackground")
	if not sprite_container:
		sprite_container = get_node_or_null("SpriteContainer")
	if not troop_anim_sprite and sprite_container:
		troop_anim_sprite = sprite_container.get_node_or_null("TroopAnimatedSprite")
	if not troop_icon:
		troop_icon = get_node_or_null("TroopIcon")
	if not health_bar:
		health_bar = get_node_or_null("HealthProgressBar")
	if health_bar and not _fill_style:
		_setup_health_bar_styles()

func _setup_health_bar_styles() -> void:
	if not health_bar:
		return

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.10, 0.10, 0.12, 0.90)
	bg_style.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("background", bg_style)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = Color(0.25, 0.85, 0.3, 1.0)
	_fill_style.set_corner_radius_all(2)
	health_bar.add_theme_stylebox_override("fill", _fill_style)

func setup(ally: Node2D, unit_name: String) -> void:
	_ally_node = ally
	_unit_name = unit_name
	_ensure_nodes()
	_configure_troop_animation(unit_name)

	if is_instance_valid(ally):
		if ally.has_signal("health_updated"):
			if not ally.health_updated.is_connected(_on_health_updated):
				ally.health_updated.connect(_on_health_updated)

		if not ally.tree_exiting.is_connected(_on_ally_tree_exiting):
			ally.tree_exiting.connect(_on_ally_tree_exiting)

		var cur_hp: int = ally.get("current_health") if ally.get("current_health") != null else 100
		var max_hp: int = ally.get("max_health") if ally.get("max_health") != null else 100
		update_health(cur_hp, max_hp)

	_update_internal_layout()

## Configura e inicia a animação IDLE completa da tropa dentro do slot
func _configure_troop_animation(unit_name: String) -> void:
	var lower := unit_name.to_lower()
	var config_key := "warrior"
	if "archer" in lower or "arqueiro" in lower:
		config_key = "archer"
	elif "lancer" in lower or "lanceiro" in lower:
		config_key = "lancer"
	elif "monk" in lower or "monge" in lower:
		config_key = "monk"

	var cfg = TROOP_CONFIGS.get(config_key, {"scale": 0.40, "offset": Vector2.ZERO})
	_base_scale = cfg["scale"]
	_base_offset = cfg["offset"]

	var has_valid_anim := false
	if is_instance_valid(_ally_node) and troop_anim_sprite:
		var ally_anim: AnimatedSprite2D = _ally_node.get_node_or_null("AnimatedSprite2D")
		if ally_anim and ally_anim.sprite_frames and ally_anim.sprite_frames.has_animation("idle"):
			troop_anim_sprite.sprite_frames = ally_anim.sprite_frames
			troop_anim_sprite.animation = "idle"
			troop_anim_sprite.visible = true
			troop_anim_sprite.play("idle")

			# Variação sutil no frame inicial para que as tropas respirem com ritmo orgânico
			var frame_count := ally_anim.sprite_frames.get_frame_count("idle")
			if frame_count > 0:
				troop_anim_sprite.frame = randi() % frame_count

			has_valid_anim = true
			if troop_icon:
				troop_icon.visible = false

	# Fallback estático caso a tropa não possua AnimatedSprite2D
	if not has_valid_anim:
		if troop_anim_sprite:
			troop_anim_sprite.visible = false
		if troop_icon:
			troop_icon.visible = true
			if config_key == "warrior":
				troop_icon.texture = ICON_WARRIOR
			elif config_key == "archer":
				troop_icon.texture = ICON_ARCHER
			elif config_key == "lancer":
				troop_icon.texture = ICON_LANCER
			elif config_key == "monk":
				troop_icon.texture = ICON_MONK

## Adapta dinamicamente o tamanho do slot e escala interna conforme a quantidade de tropas
func apply_layout_size(new_size: Vector2, scale_factor: float) -> void:
	_ensure_nodes()
	_current_scale_factor = scale_factor
	custom_minimum_size = new_size
	size = new_size
	_update_internal_layout()

## Atualiza as posições e proporções internas (janela de sprite animado e barra de vida)
func _update_internal_layout() -> void:
	_ensure_nodes()
	pivot_offset = size * 0.5

	# 1. Ajusta o SpriteContainer para a área nobre central do banner
	if sprite_container:
		var sc_w: float = size.x * 0.84
		var sc_h: float = size.y * 0.64
		sprite_container.size = Vector2(sc_w, sc_h)
		sprite_container.position = Vector2((size.x - sc_w) * 0.5, size.y * 0.08)

		# Posiciona e escala o AnimatedSprite2D dentro da janela de corte
		if troop_anim_sprite:
			var center_pos := Vector2(sc_w * 0.5, sc_h * 0.5)
			troop_anim_sprite.position = center_pos + (_base_offset * _current_scale_factor)
			var final_scale: float = _base_scale * _current_scale_factor
			troop_anim_sprite.scale = Vector2(final_scale, final_scale)

	# 2. Ajusta o TroopIcon estático (fallback)
	if troop_icon and troop_icon.visible:
		var icon_w: float = size.x * 0.75
		var icon_h: float = size.y * 0.60
		troop_icon.size = Vector2(icon_w, icon_h)
		troop_icon.position = Vector2((size.x - icon_w) * 0.5, size.y * 0.10)

	# 3. Ajusta a HealthProgressBar na base do banner
	if health_bar:
		var bar_w: float = size.x * 0.74
		var bar_h: float = clampf(5.0 * _current_scale_factor, 3.0, 6.0)
		var bottom_margin: float = clampf(5.0 * _current_scale_factor, 3.0, 7.0)
		health_bar.size = Vector2(bar_w, bar_h)
		health_bar.position = Vector2((size.x - bar_w) * 0.5, size.y - bar_h - bottom_margin)

func _on_health_updated(current: int, max_val: int) -> void:
	if _is_dying:
		return
	update_health(current, max_val)

func update_health(current: int, max_val: int) -> void:
	_ensure_nodes()
	if not health_bar:
		return

	health_bar.max_value = maxf(1.0, float(max_val))
	health_bar.value = clampf(float(current), 0.0, health_bar.max_value)

	var ratio: float = health_bar.value / health_bar.max_value
	if _fill_style:
		if ratio > 0.5:
			_fill_style.bg_color = Color(0.25, 0.85, 0.3, 1.0) # Verde saudável
		elif ratio > 0.25:
			_fill_style.bg_color = Color(0.95, 0.80, 0.15, 1.0) # Amarelo alerta
		else:
			_fill_style.bg_color = Color(0.92, 0.20, 0.20, 1.0) # Vermelho crítico

func _on_ally_tree_exiting() -> void:
	if not _is_dying:
		play_death_and_remove()

func play_death_and_remove() -> void:
	if _is_dying:
		return
	_is_dying = true

	var tween := create_tween().set_parallel(true)
	if tween:
		tween.tween_property(self, "modulate", Color(0.7, 0.2, 0.2, 0.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(0.6, 0.6), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()
