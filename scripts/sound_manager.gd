extends Node
class_name SoundManager

## Gerenciador de Áudio Retrô com síntese procedural 8-bit balanceada.
## Volumes calibrados para um nível suave e confortável aos ouvidos.

static var instance: SoundManager = null

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 6

## Volume master dos efeitos sonoros em decibéis (-15 dB é suave e seguro para fones)
@export var master_volume_db: float = -15.0:
	set(value):
		master_volume_db = value
		_update_players_volume()

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_sounds()
	_init_audio_pool()

func _init_audio_pool() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		p.volume_db = master_volume_db
		add_child(p)
		_players.append(p)

func _update_players_volume() -> void:
	for p in _players:
		if is_instance_valid(p):
			p.volume_db = master_volume_db

func _get_available_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

func _play_sound(sound_name: String) -> void:
	if _sounds.has(sound_name):
		var p := _get_available_player()
		p.stream = _sounds[sound_name]
		p.volume_db = master_volume_db
		p.play()

## Garante a existência da instância mesmo ao rodar cenas isoladas
static func _ensure_instance() -> SoundManager:
	if instance and is_instance_valid(instance):
		return instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var node = tree.root.get_node_or_null("SoundManager")
		if node and node is SoundManager:
			instance = node
			return instance
		var new_mgr := SoundManager.new()
		new_mgr.name = "SoundManager"
		tree.root.add_child(new_mgr)
		instance = new_mgr
		return instance
	return null

## Define o volume geral dos efeitos (em dB)
static func set_volume(db: float) -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr.master_volume_db = db

## Tom suave e aveludado de corte para o golpe da espada
static func play_hit() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_sound("hit")

## Dois tons agudos suaves e melódicos (estilo sininho agradável)
static func play_coin() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_sound("coin")

## Arpeggio melódico relaxante e acolhedor de cura
static func play_heal() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_sound("heal")

## Tom de impacto abafado ao tomar dano, sem estalos
static func play_damage() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_sound("damage")

# ==============================================================================
# SÍNTESE PROCEDURAL DE ONDAS RETRÔ SUAVES
# ==============================================================================

func _init_sounds() -> void:
	_sounds["hit"] = _generate_hit_sound()
	_sounds["coin"] = _generate_coin_sound()
	_sounds["heal"] = _generate_heal_sound()
	_sounds["damage"] = _generate_damage_sound()

func _create_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

func _generate_hit_sound() -> AudioStreamWAV:
	var duration: float = 0.12
	var count: int = int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count)

	var phase: float = 0.0
	for i in range(count):
		var progress: float = float(i) / float(count)
		var freq: float = lerp(200.0, 50.0, progress)
		phase += freq / float(SAMPLE_RATE)

		# Senóide com suave ruído rosa/branco atenuado para simular o ar da lâmina
		var tone: float = sin(phase * TAU) * 0.7
		var noise: float = randf_range(-0.15, 0.15)
		var envelope: float = pow(1.0 - progress, 2.2)
		var sample: float = (tone + noise) * envelope * 0.35
		bytes[i] = clampi(int(sample * 127.0 + 128.0), 0, 255)

	return _create_stream(bytes)

func _generate_coin_sound() -> AudioStreamWAV:
	var duration: float = 0.22
	var count: int = int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count)

	var phase: float = 0.0
	var split_sample: int = int(0.06 * SAMPLE_RATE)

	for i in range(count):
		var freq: float
		var envelope: float
		if i < split_sample:
			# Nota 1: Si5 (987.77 Hz) - toque suave
			freq = 987.77
			var t_note: float = float(i) / float(split_sample)
			envelope = 1.0 - (t_note * 0.2)
		else:
			# Nota 2: Mi6 (1318.51 Hz) - brilho suave
			freq = 1318.51
			var t_note: float = float(i - split_sample) / float(count - split_sample)
			envelope = pow(1.0 - t_note, 1.4)

		phase += freq / float(SAMPLE_RATE)

		# Senóide pura com leve harmônico quente (sem estridência de onda quadrada crua)
		var sine: float = sin(phase * TAU)
		var sub_harm: float = sin(phase * TAU * 0.5) * 0.2
		var sample: float = (sine * 0.8 + sub_harm) * envelope * 0.30
		bytes[i] = clampi(int(sample * 127.0 + 128.0), 0, 255)

	return _create_stream(bytes)

func _generate_heal_sound() -> AudioStreamWAV:
	var duration: float = 0.32
	var count: int = int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count)

	var phase: float = 0.0
	var note_duration: float = duration / 3.0
	var note_samples: int = int(note_duration * SAMPLE_RATE)
	var freqs: Array[float] = [523.25, 659.25, 783.99]

	for i in range(count):
		var note_idx: int = mini(int(float(i) / float(note_samples)), 2)
		var freq: float = freqs[note_idx]
		phase += freq / float(SAMPLE_RATE)

		var local_t: float = float(i % note_samples) / float(note_samples)
		# Envelope com curva suave em sino para cada nota
		var env: float = sin(local_t * PI)
		var wave: float = sin(phase * TAU) * 0.85 + sin(phase * TAU * 2.0) * 0.15
		var sample: float = wave * env * 0.25
		bytes[i] = clampi(int(sample * 127.0 + 128.0), 0, 255)

	return _create_stream(bytes)

func _generate_damage_sound() -> AudioStreamWAV:
	var duration: float = 0.15
	var count: int = int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(count)

	var phase: float = 0.0
	for i in range(count):
		var progress: float = float(i) / float(count)
		var freq: float = lerp(140.0, 30.0, progress)
		phase += freq / float(SAMPLE_RATE)

		# Impacto grave abafado sem frequências agudas perfurantes
		var tone: float = sin(phase * TAU) * 0.7
		var noise: float = randf_range(-0.1, 0.1)
		var envelope: float = pow(1.0 - progress, 2.0)
		var sample: float = (tone + noise) * envelope * 0.32
		bytes[i] = clampi(int(sample * 127.0 + 128.0), 0, 255)

	return _create_stream(bytes)
