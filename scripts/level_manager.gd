class_name LevelManager
extends RefCounted

const PROGRESS_FILE: String = "user://level_progress.json"

static var current_game_mode: String = "story" # "story" ou "endless"

# Dados da partida recém-concluída para a tela de vitória
static var last_completion_time: float = 0.0
static var last_is_new_record: bool = false
static var last_coins_collected: int = 0

## Carrega o progresso salvo em user://level_progress.json
static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(PROGRESS_FILE):
		return {
			"level_1_completed": false,
			"level_1_best_time": 0.0
		}
	var file := FileAccess.open(PROGRESS_FILE, FileAccess.READ)
	if not file:
		return {
			"level_1_completed": false,
			"level_1_best_time": 0.0
		}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {
		"level_1_completed": false,
		"level_1_best_time": 0.0
	}

## Salva a conclusão do Level 1 e atualiza o recorde se for menor
static func record_level_1_victory(time_seconds: float, coins: int) -> bool:
	var data := load_progress()
	var prev_best: float = float(data.get("level_1_best_time", 0.0))
	var is_record := false

	if prev_best <= 0.0 or time_seconds < prev_best:
		is_record = true
		data["level_1_best_time"] = time_seconds
	data["level_1_completed"] = true

	var file := FileAccess.open(PROGRESS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

	last_completion_time = time_seconds
	last_is_new_record = is_record
	last_coins_collected = coins
	return is_record

## Retorna se o Level 1 foi concluído
static func is_level_1_completed() -> bool:
	var data := load_progress()
	return bool(data.get("level_1_completed", false))

## Retorna o melhor tempo do Level 1 (em segundos)
static func get_level_1_best_time() -> float:
	var data := load_progress()
	return float(data.get("level_1_best_time", 0.0))

## Formata segundos em MM:SS ou MMm SSs
static func format_time(total_seconds: float, detailed: bool = false) -> String:
	var total_int := int(floor(maxf(0.0, total_seconds)))
	var mins := total_int / 60
	var secs := total_int % 60
	if detailed:
		if mins > 0:
			return "%dm %02ds" % [mins, secs]
		else:
			return "%ds" % secs
	return "%02d:%02d" % [mins, secs]
