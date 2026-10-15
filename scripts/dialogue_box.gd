extends CanvasLayer

signal dialogue_finished

var dialogue_lines: Array[String] = []
var current_index: int = 0
var is_active: bool = false

@onready var panel_container: PanelContainer = $PanelContainer
@onready var name_label: Label = $PanelContainer/VBoxContainer/NameLabel
@onready var text_label: RichTextLabel = $PanelContainer/VBoxContainer/TextLabel
@onready var next_indicator: Label = $PanelContainer/VBoxContainer/NextIndicator

func _ready() -> void:
	add_to_group("dialogue_box")
	hide_box()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Avança ao pressionar E, Espaço ou Enter (ui_accept / interact)
	var pressed_advance := false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		pressed_advance = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			pressed_advance = true

	if pressed_advance:
		get_viewport().set_input_as_handled()
		advance_dialogue()

## Inicia a exibição da sequência de falas
func start_dialogue(lines: Array[String], speaker_name: String = "NPC") -> void:
	if lines.is_empty():
		return

	dialogue_lines = lines
	current_index = 0
	is_active = true

	# Congela o jogador
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("freeze"):
		player.freeze()

	if name_label:
		name_label.text = speaker_name

	show_box()
	_display_current_line()

func _display_current_line() -> void:
	if current_index >= dialogue_lines.size():
		end_dialogue()
		return

	if text_label:
		text_label.text = dialogue_lines[current_index]

	if next_indicator:
		if current_index == dialogue_lines.size() - 1:
			next_indicator.text = "[E] Fechar"
		else:
			next_indicator.text = "[E] Próximo"

## Avança para a próxima fala ou finaliza
func advance_dialogue() -> void:
	current_index += 1
	if current_index < dialogue_lines.size():
		_display_current_line()
	else:
		end_dialogue()

## Finaliza o diálogo e descongela o jogador
func end_dialogue() -> void:
	if not is_active:
		return

	is_active = false
	hide_box()

	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()

	dialogue_finished.emit()

func show_box() -> void:
	visible = true
	if panel_container:
		panel_container.visible = true

func hide_box() -> void:
	visible = false
	if panel_container:
		panel_container.visible = false
