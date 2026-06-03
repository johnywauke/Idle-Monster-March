extends Node
# AUTOLOAD: SaveManager
# Salva/carrega o GameState em JSON e credita o progresso offline (v2 1/13).

const SAVE_PATH := "user://savegame.json"
const OFFLINE_CAP_SECONDS := 12 * 60 * 60   # 12h de acumulo maximo (v2 13)

func save_game() -> void:
	var data := GameState.to_save_dict()
	data["saved_at_unix"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] Falha ao abrir o save para escrita.")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Carrega o save e retorna o ouro ganho offline (ja creditado). 0 se nao houver save.
func load_game() -> float:
	if not has_save():
		return 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0.0
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveManager] Save corrompido.")
		return 0.0
	GameState.from_save_dict(parsed)
	return _credit_offline_earnings(float(parsed.get("saved_at_unix", 0.0)))

func _credit_offline_earnings(saved_at_unix: float) -> float:
	if saved_at_unix <= 0.0:
		return 0.0
	var now := Time.get_unix_time_from_system()
	var elapsed := clampf(now - saved_at_unix, 0.0, float(OFFLINE_CAP_SECONDS))
	# Mesma matematica do combate ativo -> e isto que torna o offline possivel (v2 1).
	var gps := BattleSimulator.gold_per_second(GameState.team_base_dps(), GameState.current_phase)
	var earned := gps * elapsed
	GameState.gold += earned
	return earned
