extends Node
class_name SoundManager

## Gerenciador Central de Áudio Oficial do RPG (RPG Essentials Free)
## Gerencia pools de AudioStreamPlayer e executa efeitos sonoros com volumes balanceados.

static var instance: SoundManager = null

const POOL_SIZE: int = 12

const PATH_SLASH: String = "res://assets/sounds/10_Battle_SFX/22_Slash_04.wav"
const PATH_HIT: String = "res://assets/sounds/10_Battle_SFX/15_Impact_flesh_02.wav"
const PATH_ENEMY_DEATH: String = "res://assets/sounds/10_Battle_SFX/69_Enemy_death_01.wav"
const PATH_COIN: String = "res://assets/sounds/10_UI_Menu_SFX/079_Buy_sell_01.wav"
const PATH_POTION: String = "res://assets/sounds/10_UI_Menu_SFX/051_use_item_01.wav"
const PATH_HEAL: String = "res://assets/sounds/8_Buffs_Heals_SFX/02_Heal_02.wav"
const PATH_ARROW: String = "res://assets/sounds/8_Atk_Magic_SFX/25_Wind_01.wav"
const PATH_DIALOGUE: String = "res://assets/sounds/10_UI_Menu_SFX/013_Confirm_03.wav"

const FALLBACK_PREFIX: String = "res://assets/sounds/rpg_essentials/"

var stream_slash: AudioStream
var stream_hit: AudioStream
var stream_enemy_death: AudioStream
var stream_coin: AudioStream
var stream_potion: AudioStream
var stream_heal: AudioStream
var stream_arrow: AudioStream
var stream_dialogue: AudioStream

var _players: Array[AudioStreamPlayer] = []

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_sounds()
	_init_audio_pool()

func _load_audio_file(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	var alt_path := path.replace("res://assets/sounds/", FALLBACK_PREFIX)
	if ResourceLoader.exists(alt_path):
		var res = load(alt_path)
		if res is AudioStream:
			return res
	if FileAccess.file_exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	return null

func _init_sounds() -> void:
	stream_slash = _load_audio_file(PATH_SLASH)
	stream_hit = _load_audio_file(PATH_HIT)
	stream_enemy_death = _load_audio_file(PATH_ENEMY_DEATH)
	stream_coin = _load_audio_file(PATH_COIN)
	stream_potion = _load_audio_file(PATH_POTION)
	stream_heal = _load_audio_file(PATH_HEAL)
	stream_arrow = _load_audio_file(PATH_ARROW)
	stream_dialogue = _load_audio_file(PATH_DIALOGUE)

func _init_audio_pool() -> void:
	if not _players.is_empty():
		return
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.bus = &"Master"
		add_child(p)
		_players.append(p)

func _get_available_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# Se todos os canais estiverem ocupados, cria um novo dinamicamente
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.bus = &"Master"
	add_child(p)
	_players.append(p)
	return p

func _play_stream(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream:
		return
	var p := _get_available_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

## Garante a existência da instância mesmo ao rodar cenas isoladas
static func _ensure_instance() -> SoundManager:
	if instance and is_instance_valid(instance):
		if instance._players.is_empty():
			instance._init_audio_pool()
		return instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var node = tree.root.get_node_or_null("SoundManager")
		if node and node is SoundManager:
			instance = node
			if instance._players.is_empty():
				instance._init_sounds()
				instance._init_audio_pool()
			return instance
		var new_mgr := SoundManager.new()
		new_mgr.name = "SoundManager"
		tree.root.add_child(new_mgr)
		instance = new_mgr
		instance._init_sounds()
		instance._init_audio_pool()
		return instance
	return null

## Golpe de espada: 22_Slash_04.wav (volume_db = -3)
static func play_slash() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_slash, -3.0)

## Dano de impacto na carne: 15_Impact_flesh_02.wav (volume_db = -2)
static func play_hit() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_hit, -2.0)

## Morte de monstros: 69_Enemy_death_01.wav
static func play_enemy_death() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_enemy_death, 0.0)

## Coleta/compra com moedas de ouro: 079_Buy_sell_01.wav
static func play_coin() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_coin, 0.0)

## Uso de poção de cura do inventário: 051_use_item_01.wav
static func play_potion() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_potion, 0.0)

## Efeito divino/mágico de cura: 02_Heal_02.wav
static func play_heal() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_heal, 0.0)

## Disparo da flecha cortando o vento: 25_Wind_01.wav (volume_db = -4)
static func play_arrow() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_arrow, -4.0)

## Avanço e confirmação de diálogo: 013_Confirm_03.wav (volume_db = -6)
static func play_dialogue() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_dialogue, -6.0)

## Retrocompatibilidade para chamadas de dano
static func play_damage() -> void:
	play_hit()

## Retrocompatibilidade para alteração de volume mestre
static func set_volume(db: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
