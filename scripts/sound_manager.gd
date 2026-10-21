extends Node
class_name SoundManager

## Gerenciador Central de Áudio do RPG
## Gerencia reprodução contínua de playlists de música em loop por tela e pool de efeitos sonoros (SFX).

static var instance: SoundManager = null

const POOL_SIZE: int = 16

# SFX Existentes
const PATH_SLASH: String = "res://assets/sounds/10_Battle_SFX/22_Slash_04.wav"
const PATH_HIT: String = "res://assets/sounds/10_Battle_SFX/15_Impact_flesh_02.wav"
const PATH_ENEMY_DEATH: String = "res://assets/sounds/10_Battle_SFX/69_Enemy_death_01.wav"
const PATH_COIN: String = "res://assets/sounds/10_UI_Menu_SFX/079_Buy_sell_01.wav"
const PATH_POTION: String = "res://assets/sounds/10_UI_Menu_SFX/051_use_item_01.wav"
const PATH_HEAL: String = "res://assets/sounds/8_Buffs_Heals_SFX/02_Heal_02.wav"
const PATH_ARROW: String = "res://assets/sounds/8_Atk_Magic_SFX/25_Wind_01.wav"
const PATH_DIALOGUE: String = "res://assets/sounds/10_UI_Menu_SFX/013_Confirm_03.wav"

# Novos SFX Integrados
const PATH_STEP_GRASS: String = "res://assets/sounds/12_Player_Movement_SFX/03_Step_grass_03.wav"
const PATH_FIRE_EXPLOSION: String = "res://assets/sounds/8_Atk_Magic_SFX/04_Fire_explosion_04_medium.wav"
const PATH_HOVER: String = "res://assets/sounds/10_UI_Menu_SFX/001_Hover_01.wav"
const PATH_CONFIRM: String = "res://assets/sounds/10_UI_Menu_SFX/013_Confirm_03.wav"
const PATH_DENIED: String = "res://assets/sounds/10_UI_Menu_SFX/033_Denied_03.wav"
const PATH_EQUIP: String = "res://assets/sounds/10_UI_Menu_SFX/070_Equip_10.wav"
const PATH_PAUSE: String = "res://assets/sounds/10_UI_Menu_SFX/092_Pause_04.wav"
const PATH_UNPAUSE: String = "res://assets/sounds/10_UI_Menu_SFX/098_Unpause_04.wav"
const PATH_ATK_BUFF: String = "res://assets/sounds/8_Buffs_Heals_SFX/16_Atk_buff_04.wav"
const PATH_DEF_BUFF: String = "res://assets/sounds/8_Buffs_Heals_SFX/17_Def_buff_01.wav"
const PATH_SPEED_BUFF: String = "res://assets/sounds/8_Buffs_Heals_SFX/48_Speed_up_02.wav"
const PATH_BLOCK: String = "res://assets/sounds/10_Battle_SFX/39_Block_03.wav"
const PATH_BOSS_ALERT: String = "res://assets/sounds/10_Battle_SFX/55_Encounter_02.wav"

const FALLBACK_PREFIX: String = "res://assets/sounds/rpg_essentials/"

# Playlists de música em loop por tela/contexto
const PLAYLISTS: Dictionary = {
	"menu": [
		"res://assets/sounds/music/menu music/emmraan-fantasy-kingdom-261257.mp3",
		"res://assets/sounds/music/menu music/kaazoom-song-of-the-ancients-epic-gothic-fantasy-music-436511.mp3",
		"res://assets/sounds/music/menu music/psychronic-battle-of-the-abyss-227337.mp3",
		"res://assets/sounds/music/menu music/tim_kulig_free_music-an-armada-upon-us-280311.mp3"
	],
	"gameplay": [
		"res://assets/sounds/music/background music/savannamusic-to-adventure-193760.mp3",
		"res://assets/sounds/music/andorios-rpg-medieval-animated-music-320583.mp3",
		"res://assets/sounds/music/background music/phatphrogstudio-dragons-calling-legacy-of-the-ancients-477468.mp3",
		"res://assets/sounds/music/background music/nojisuma-ruins-168316.mp3",
		"res://assets/sounds/music/background music/phatphrogstudio-phatphrogstudiocom-arcane-throne-heir-of-valor-477466.mp3",
		"res://assets/sounds/music/background music/dstechnician-dark-circus-113460.mp3",
		"res://assets/sounds/music/background music/spencer_yk-timex27s-running-out-151012.mp3",
		"res://assets/sounds/music/background music/vjgalaxy-rpgs-hand-drums-tribal-background-music-608348.mp3",
		"res://assets/sounds/music/melodyayresgriffiths-goons-electronic-march-video-game-rpg-trolls-ogres-orcs-attack-145267.mp3"
	],
	"boss": [
		"res://assets/sounds/music/boss music/ancient_echoes-dominion-519384.mp3",
		"res://assets/sounds/music/boss music/tim_kulig_free_music-bedlam-280310.mp3"
	],
	"lost": [
		"res://assets/sounds/music/lost music/composiia-depois-da-batalha-173739.mp3"
	],
	"win": [
		"res://assets/sounds/music/win music/melodyayresgriffiths-triumph-instrumental-rpg-adventure-quest-celebration-135451.mp3"
	]
}

# Cache de AudioStream de SFX
var stream_slash: AudioStream
var stream_hit: AudioStream
var stream_enemy_death: AudioStream
var stream_coin: AudioStream
var stream_potion: AudioStream
var stream_heal: AudioStream
var stream_arrow: AudioStream
var stream_dialogue: AudioStream
var stream_step_grass: AudioStream
var stream_fire_explosion: AudioStream
var stream_hover: AudioStream
var stream_confirm: AudioStream
var stream_denied: AudioStream
var stream_equip: AudioStream
var stream_pause: AudioStream
var stream_unpause: AudioStream
var stream_atk_buff: AudioStream
var stream_def_buff: AudioStream
var stream_speed_buff: AudioStream
var stream_block: AudioStream
var stream_boss_alert: AudioStream

# Controle de Música
var _music_player: AudioStreamPlayer = null
var _current_music_category: String = ""
var _current_playlist: Array = []
var _current_track_index: int = 0
var _music_tween: Tween = null
var _base_music_volume_db: float = -10.0

# Pool de SFX
var _players: Array[AudioStreamPlayer] = []

var _pending_track_play: bool = false
var _pending_fade_duration: float = 0.5

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_sounds()
	_init_audio_pool()
	_init_music_player()
	if _pending_track_play:
		_pending_track_play = false
		_play_current_track(_pending_fade_duration)

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
	stream_step_grass = _load_audio_file(PATH_STEP_GRASS)
	stream_fire_explosion = _load_audio_file(PATH_FIRE_EXPLOSION)
	stream_hover = _load_audio_file(PATH_HOVER)
	stream_confirm = _load_audio_file(PATH_CONFIRM)
	stream_denied = _load_audio_file(PATH_DENIED)
	stream_equip = _load_audio_file(PATH_EQUIP)
	stream_pause = _load_audio_file(PATH_PAUSE)
	stream_unpause = _load_audio_file(PATH_UNPAUSE)
	stream_atk_buff = _load_audio_file(PATH_ATK_BUFF)
	stream_def_buff = _load_audio_file(PATH_DEF_BUFF)
	stream_speed_buff = _load_audio_file(PATH_SPEED_BUFF)
	stream_block = _load_audio_file(PATH_BLOCK)
	stream_boss_alert = _load_audio_file(PATH_BOSS_ALERT)

static func ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func _init_audio_pool() -> void:
	ensure_audio_buses()
	if not _players.is_empty():
		return
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)

func _init_music_player() -> void:
	ensure_audio_buses()
	if _music_player and is_instance_valid(_music_player):
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.bus = &"Music"
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

func _get_available_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	# Se todos os canais estiverem ocupados, cria um novo dinamicamente
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.bus = &"SFX"
	add_child(p)
	_players.append(p)
	return p

func _play_stream(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream or not is_inside_tree():
		return
	var p := _get_available_player()
	if not p or not p.is_inside_tree():
		return
	p.stream = stream
	p.volume_db = volume_db
	p.play()

## Garante a existência da instância mesmo ao rodar cenas isoladas
static func _ensure_instance() -> SoundManager:
	if instance and is_instance_valid(instance):
		if instance.is_inside_tree():
			if instance._players.is_empty():
				instance._init_audio_pool()
			if not instance._music_player or not is_instance_valid(instance._music_player):
				instance._init_music_player()
		return instance
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var node = tree.root.get_node_or_null("SoundManager")
		if node and node is SoundManager:
			instance = node
			if instance.is_inside_tree():
				if instance._players.is_empty():
					instance._init_sounds()
					instance._init_audio_pool()
				if not instance._music_player or not is_instance_valid(instance._music_player):
					instance._init_music_player()
			return instance
		var new_mgr := SoundManager.new()
		new_mgr.name = "SoundManager"
		instance = new_mgr
		tree.root.add_child.call_deferred(new_mgr)
		return instance
	return null

# ==============================================================================
# SISTEMA DE MÚSICA EM LOOP POR PLAYLIST
# ==============================================================================

## Toca a playlist correspondente à categoria especificada ("menu", "gameplay", "boss", "lost", "win")
## Se a mesma categoria já estiver tocando, mantém a reprodução sem reiniciar.
static func play_music_playlist(category: String, fade_duration: float = 0.5) -> void:
	var mgr := _ensure_instance()
	if not mgr:
		return
	mgr._start_playlist(category, fade_duration)

func _start_playlist(category: String, fade_duration: float) -> void:
	if not PLAYLISTS.has(category):
		push_warning("SoundManager: Playlist desconhecida '%s'" % category)
		return

	if _current_music_category == category and _music_player and _music_player.playing:
		return # Já está tocando a playlist atual, segue o fluxo naturalmente

	_current_music_category = category
	_current_playlist = PLAYLISTS[category].duplicate()
	_current_track_index = 0

	if _current_playlist.is_empty():
		return

	_play_current_track(fade_duration)

func _play_current_track(fade_duration: float = 0.5) -> void:
	if not is_inside_tree() or not _music_player or not _music_player.is_inside_tree():
		_pending_track_play = true
		_pending_fade_duration = fade_duration
		return

	if _current_playlist.is_empty():
		return

	var track_path: String = _current_playlist[_current_track_index]
	var stream := _load_audio_file(track_path)
	if not stream:
		push_warning("SoundManager: Falha ao carregar faixa musical '%s'" % track_path)
		# Tenta a próxima se falhar
		if _current_playlist.size() > 1:
			_current_track_index = (_current_track_index + 1) % _current_playlist.size()
			_play_current_track(0.1)
		return

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	if _music_player.playing and fade_duration > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
		_music_tween.tween_callback(func():
			_music_player.stream = stream
			_music_player.volume_db = -80.0
			_music_player.play()
			var in_tween := create_tween()
			in_tween.tween_property(_music_player, "volume_db", _base_music_volume_db, fade_duration)
		)
	else:
		_music_player.stream = stream
		if fade_duration > 0.0:
			_music_player.volume_db = -80.0
			_music_player.play()
			_music_tween = create_tween()
			_music_tween.tween_property(_music_player, "volume_db", _base_music_volume_db, fade_duration)
		else:
			_music_player.volume_db = _base_music_volume_db
			_music_player.play()

func _on_music_finished() -> void:
	if _current_playlist.is_empty():
		return
	# Avança ciclicamente para a próxima faixa da playlist em loop infinito
	_current_track_index = (_current_track_index + 1) % _current_playlist.size()
	_play_current_track(0.2)

## Para a música atual com transição suave (fade out)
static func stop_music(fade_duration: float = 0.5) -> void:
	var mgr := _ensure_instance()
	if not mgr or not mgr._music_player:
		return
	mgr._stop_music_internal(fade_duration)

func _stop_music_internal(fade_duration: float) -> void:
	_current_music_category = ""
	if not _music_player or not _music_player.playing:
		return
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if fade_duration > 0.0:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -80.0, fade_duration)
		_music_tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()

## Define o volume base das músicas (padrão: -10 dB)
static func set_music_volume_db(volume_db: float) -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._base_music_volume_db = volume_db
		if mgr._music_player and mgr._music_player.playing:
			mgr._music_player.volume_db = volume_db

# ==============================================================================
# MÉTODOS ESTÁTICOS DE SFX
# ==============================================================================

## Golpe de espada: 22_Slash_04.wav
static func play_slash() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_slash, -3.0)

## Dano de impacto na carne: 15_Impact_flesh_02.wav
static func play_hit() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_hit, -2.0)

## Morte de monstros: 69_Enemy_death_01.wav
static func play_enemy_death() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_enemy_death, 0.0)

## Coleta de moedas de ouro: 079_Buy_sell_01.wav
static func play_coin() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_coin, 0.0)

## Uso de poção de cura do inventário: 051_use_item_01.wav
static func play_potion() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_potion, 0.0)

## Efeito mágico de cura: 02_Heal_02.wav
static func play_heal() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_heal, 0.0)

## Disparo da flecha cortando o vento: 25_Wind_01.wav
static func play_arrow() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_arrow, -4.0)

## Avanço e confirmação de diálogo: 013_Confirm_03.wav
static func play_dialogue() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_dialogue, -6.0)

## Passos na grama do jogador: 03_Step_grass_03.wav
static func play_step_grass() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_step_grass, -12.0)

## Explosão da bola de fogo mágica do Goblin Mage: 04_Fire_explosion_04_medium.wav
static func play_fire_explosion() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_fire_explosion, -2.0)

## Passar o mouse sobre botões e opções: 001_Hover_01.wav
static func play_hover() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_hover, -10.0)

## Confirmação de botões e seleções: 013_Confirm_03.wav
static func play_confirm() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_confirm, -6.0)

## Ação negada (sem moedas suficientes / recusa): 033_Denied_03.wav
static func play_denied() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_denied, -4.0)

## Compra de upgrade ou equipamento: 070_Equip_10.wav
static func play_equip() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_equip, -4.0)

## Abertura do menu de pausa: 092_Pause_04.wav
static func play_pause() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_pause, -4.0)

## Retorno do jogo / despausa: 098_Unpause_04.wav
static func play_unpause() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_unpause, -4.0)

## Buff de Ataque: 16_Atk_buff_04.wav
static func play_atk_buff() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_atk_buff, -3.0)

## Buff de Defesa / Armadura: 17_Def_buff_01.wav
static func play_def_buff() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_def_buff, -3.0)

## Buff de Velocidade: 48_Speed_up_02.wav
static func play_speed_buff() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_speed_buff, -3.0)

## Bloqueio com armadura ou escudo: 39_Block_03.wav
static func play_block() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_block, -3.0)

## Alerta de Boss / Encontro Épico: 55_Encounter_02.wav
static func play_boss_alert() -> void:
	var mgr := _ensure_instance()
	if mgr:
		mgr._play_stream(mgr.stream_boss_alert, -2.0)

## Retrocompatibilidade
static func play_damage() -> void:
	play_hit()

static func set_volume(db: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
