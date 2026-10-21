extends CanvasLayer

signal dialogue_finished
signal purchase_confirmed
signal purchase_cancelled

const BLUE_BUTTON_TEX: Texture2D = preload("res://assets/tiny_swords/UI Elements/UI Elements/Buttons/SmallBlueRoundButton_Pressed.png")
const RED_BUTTON_TEX: Texture2D = preload("res://assets/tiny_swords/UI Elements/UI Elements/Buttons/SmallRedRoundButton_Pressed.png")

var dialogue_lines: Array[String] = []
var current_index: int = 0
var is_active: bool = false
var is_purchase_dialogue: bool = false
var _on_confirm_callback: Callable = Callable()
var _on_cancel_callback: Callable = Callable()

@onready var panel_container: PanelContainer = $PanelContainer if has_node("PanelContainer") else null
@onready var name_label: Label = find_child("NameLabel", true, false) as Label
@onready var text_label: RichTextLabel = find_child("TextLabel", true, false) as RichTextLabel
@onready var next_indicator: Label = find_child("NextIndicator", true, false) as Label

var purchase_buttons_container: HBoxContainer = null
var yes_button: TextureButton = null
var no_button: TextureButton = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialogue_box")
	_setup_purchase_buttons()
	hide_box()

func _setup_purchase_buttons() -> void:
	if purchase_buttons_container:
		return
	if not panel_container:
		panel_container = $PanelContainer if has_node("PanelContainer") else null
	var vbox := panel_container.get_node_or_null("VBoxContainer") if panel_container else null
	if not vbox:
		return

	purchase_buttons_container = HBoxContainer.new()
	purchase_buttons_container.name = "PurchaseButtonsContainer"
	purchase_buttons_container.alignment = BoxContainer.ALIGNMENT_END
	purchase_buttons_container.add_theme_constant_override("separation", 24)
	purchase_buttons_container.visible = false

	# Botão Sim (Azul redondo com sprite SmallBlueRoundButton_Pressed.png e texto "Sim" dentro)
	yes_button = TextureButton.new()
	yes_button.name = "YesButton"
	yes_button.texture_normal = BLUE_BUTTON_TEX
	yes_button.texture_pressed = BLUE_BUTTON_TEX
	yes_button.texture_hover = BLUE_BUTTON_TEX
	yes_button.ignore_texture_size = true
	yes_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	yes_button.custom_minimum_size = Vector2(58, 58)
	yes_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var yes_label := Label.new()
	yes_label.text = "Sim"
	yes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yes_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	yes_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	yes_label.add_theme_font_size_override("font_size", 16)
	yes_label.add_theme_color_override("font_color", Color.WHITE)
	yes_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	yes_label.add_theme_constant_override("shadow_offset_x", 1)
	yes_label.add_theme_constant_override("shadow_offset_y", 1)
	yes_label.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.35, 1.0))
	yes_label.add_theme_constant_override("outline_size", 3)
	yes_button.add_child(yes_label)

	# Botão Não (Vermelho redondo com sprite SmallRedRoundButton_Pressed.png e texto "Não" dentro)
	no_button = TextureButton.new()
	no_button.name = "NoButton"
	no_button.texture_normal = RED_BUTTON_TEX
	no_button.texture_pressed = RED_BUTTON_TEX
	no_button.texture_hover = RED_BUTTON_TEX
	no_button.ignore_texture_size = true
	no_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	no_button.custom_minimum_size = Vector2(58, 58)
	no_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var no_label := Label.new()
	no_label.text = "Não"
	no_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	no_label.add_theme_font_size_override("font_size", 16)
	no_label.add_theme_color_override("font_color", Color.WHITE)
	no_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	no_label.add_theme_constant_override("shadow_offset_x", 1)
	no_label.add_theme_constant_override("shadow_offset_y", 1)
	no_label.add_theme_color_override("font_outline_color", Color(0.35, 0.05, 0.05, 1.0))
	no_label.add_theme_constant_override("outline_size", 3)
	no_button.add_child(no_label)

	yes_button.mouse_entered.connect(SoundManager.play_hover)
	no_button.mouse_entered.connect(SoundManager.play_hover)
	yes_button.pressed.connect(_on_yes_button_pressed)
	no_button.pressed.connect(_on_no_button_pressed)

	purchase_buttons_container.add_child(yes_button)
	purchase_buttons_container.add_child(no_button)
	vbox.add_child(purchase_buttons_container)

func _on_yes_button_pressed() -> void:
	if not is_active:
		return
	SoundManager.play_confirm()
	var cb := _on_confirm_callback
	_on_confirm_callback = Callable()
	_on_cancel_callback = Callable()
	is_purchase_dialogue = false
	if purchase_buttons_container:
		purchase_buttons_container.visible = false
	if cb.is_valid():
		cb.call()
	purchase_confirmed.emit()

func _on_no_button_pressed() -> void:
	if not is_active:
		return
	SoundManager.play_denied()
	var cb := _on_cancel_callback
	_on_confirm_callback = Callable()
	_on_cancel_callback = Callable()
	is_purchase_dialogue = false
	if purchase_buttons_container:
		purchase_buttons_container.visible = false
	if cb.is_valid():
		cb.call()
	purchase_cancelled.emit()
	end_dialogue()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if is_purchase_dialogue:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			get_viewport().set_input_as_handled()
			_on_no_button_pressed()
		return

	# Avança ao pressionar E, Espaço ou Enter em diálogos normais
	var pressed_advance := false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		pressed_advance = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			pressed_advance = true
		elif event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			end_dialogue()
			return

	if pressed_advance:
		get_viewport().set_input_as_handled()
		SoundManager.play_dialogue()
		advance_dialogue()

## Inicia diálogo de confirmação de compra com botões Sim e Não clicáveis
func start_purchase_dialogue(lines: Variant, speaker_name: String = "NPC", on_confirm: Callable = Callable(), on_cancel: Callable = Callable()) -> void:
	_setup_purchase_buttons()
	_on_confirm_callback = on_confirm
	_on_cancel_callback = on_cancel
	is_purchase_dialogue = true
	start_dialogue(lines, speaker_name)
	if next_indicator:
		next_indicator.visible = false
	if purchase_buttons_container:
		purchase_buttons_container.visible = true

## Inicia a exibição da sequência de falas do NPC (aceita Array[String] ou String direta)
func start_dialogue(lines: Variant, speaker_name: String = "NPC") -> void:
	dialogue_lines.clear()
	if lines is String:
		if (lines as String).strip_edges().is_empty():
			return
		dialogue_lines.append(lines as String)
	elif lines is Array:
		if (lines as Array).is_empty():
			return
		for item in lines:
			dialogue_lines.append(str(item))
	else:
		return

	_setup_purchase_buttons()
	current_index = 0
	is_active = true

	# Pausa o jogo assim como na loja
	if is_inside_tree() and get_tree():
		get_tree().paused = true

	# Congela o jogador durante a conversa
	if is_inside_tree():
		var player := get_tree().get_first_node_in_group("player")
		if player:
			if player.has_method("freeze_player"):
				player.freeze_player()
			elif player.has_method("freeze"):
				player.freeze()

	if name_label:
		name_label.text = speaker_name

	if not is_purchase_dialogue:
		if purchase_buttons_container:
			purchase_buttons_container.visible = false
		if next_indicator:
			next_indicator.visible = true

	show_box()
	_display_current_line()

func _display_current_line() -> void:
	if current_index >= dialogue_lines.size():
		end_dialogue()
		return

	if text_label:
		text_label.text = dialogue_lines[current_index]

	if next_indicator and not is_purchase_dialogue:
		if current_index == dialogue_lines.size() - 1:
			next_indicator.text = "[E] Fechar"
		else:
			next_indicator.text = "[E] Continuar"

## Avança para a próxima fala da lista ou encerra o diálogo
func advance_dialogue() -> void:
	current_index += 1
	if current_index < dialogue_lines.size():
		_display_current_line()
	else:
		end_dialogue()

## Encerra o diálogo, descongela o jogador, despausa o jogo e emite o sinal de término
func end_dialogue() -> void:
	if not is_active:
		return

	is_active = false
	is_purchase_dialogue = false
	_on_confirm_callback = Callable()
	_on_cancel_callback = Callable()
	if purchase_buttons_container:
		purchase_buttons_container.visible = false

	hide_box()

	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("unfreeze_player"):
			player.unfreeze_player()
		elif player.has_method("unfreeze"):
			player.unfreeze()

	# Despausa o jogo ao fechar o diálogo
	if is_inside_tree() and get_tree():
		get_tree().paused = false

	dialogue_finished.emit()

func show_box() -> void:
	visible = true
	if panel_container:
		panel_container.visible = true

func hide_box() -> void:
	visible = false
	if panel_container:
		panel_container.visible = false
