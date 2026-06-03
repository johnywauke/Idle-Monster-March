class_name CombatState
extends RefCounted

# Máquina de estado do combate: progressão de fase, boss, farm mode, fever. (v2 §5/7)
# Objeto de dados puro — GameState instancia um e chama update() a cada frame.

enum PhaseState { COMBAT, BOSS_FIGHT, FARM_MODE }

var phase_state: PhaseState = PhaseState.COMBAT
var boss_timer: float = 0.0          # segundos decorridos lutando contra o boss
var boss_wipe_phase: int = 0         # fase em que o boss causou wipe (para farm_phase())

# Fever Mode (v2 §5)
var fever_bar: float = 0.0           # 0.0 .. 1.0
var fever_active: bool = false
var fever_timer: float = 0.0         # segundos restantes do Fever ativo
var fever_cooldown: float = 0.0      # cooldown rígido após o Fever acabar

const FEVER_DURATION    := 10.0      # duração do Fever em segundos (v2 §5)
const FEVER_COOLDOWN    := 120.0     # 2 min de cooldown rígido (v2 §5)
const FEVER_CLICK_FILL  := 0.01      # 1% por clique (v2 §5)
const FEVER_ASPD_MULT   := 3.0       # 3× ASPD durante o Fever (v2 §5)

# Atualiza o estado a cada frame. Retorna dicionário de eventos ocorridos.
# Eventos possíveis: "fever_ended", "boss_enraged".
func update(delta: float) -> Dictionary:
	var events: Dictionary = {}

	if fever_active:
		fever_timer = maxf(fever_timer - delta, 0.0)
		if fever_timer <= 0.0:
			fever_active = false
			fever_cooldown = FEVER_COOLDOWN
			events["fever_ended"] = true
	elif fever_cooldown > 0.0:
		fever_cooldown = maxf(fever_cooldown - delta, 0.0)

	if phase_state == PhaseState.BOSS_FIGHT:
		boss_timer += delta
		if boss_timer >= Formulas.ENRAGE_SECONDS:
			boss_timer = 0.0
			phase_state = PhaseState.FARM_MODE
			events["boss_enraged"] = true

	return events

# Registra um clique na barra de Fever (v2 §5).
# A barra CONGELA durante o Fever ativo e durante o cooldown.
# Retorna true se o Fever foi ativado com este clique.
func add_fever_click() -> bool:
	if fever_active or fever_cooldown > 0.0:
		return false
	fever_bar = minf(fever_bar + FEVER_CLICK_FILL, 1.0)
	if fever_bar >= 1.0:
		fever_active = true
		fever_bar = 0.0
		fever_timer = FEVER_DURATION
		return true
	return false

# Multiplicador de ASPD: 3× durante o Fever, 1× caso contrário. (v2 §5)
func aspd_multiplier() -> float:
	return FEVER_ASPD_MULT if fever_active else 1.0

# Entra na próxima fase. Retorna true se for fase de boss (múltiplo de 10). (v2 §7)
func enter_phase(phase: int) -> bool:
	if phase % 10 == 0:
		phase_state = PhaseState.BOSS_FIGHT
		boss_timer = 0.0
		boss_wipe_phase = phase
		return true
	phase_state = PhaseState.COMBAT
	return false

# Jogador desafia o boss manualmente a partir do Farm Mode. (v2 §7)
func challenge_boss(current_phase: int) -> void:
	boss_wipe_phase = current_phase
	phase_state = PhaseState.BOSS_FIGHT
	boss_timer = 0.0

# Fase de farm quando em Farm Mode: fase_boss - 9. (v2 §7)
func farm_phase() -> int:
	return max(1, boss_wipe_phase - 9)

# --- Serialização ---

func to_dict() -> Dictionary:
	return {
		"phase_state": int(phase_state),
		"boss_timer": boss_timer,
		"boss_wipe_phase": boss_wipe_phase,
		"fever_bar": fever_bar,
		"fever_active": fever_active,
		"fever_timer": fever_timer,
		"fever_cooldown": fever_cooldown,
	}

func from_dict(d: Dictionary) -> void:
	# Restaura o estado de fase a partir do int salvo, de forma segura (sem cast de enum).
	var ps := int(d.get("phase_state", 0))
	if ps == 1:
		phase_state = PhaseState.BOSS_FIGHT
	elif ps == 2:
		phase_state = PhaseState.FARM_MODE
	else:
		phase_state = PhaseState.COMBAT
	boss_timer = float(d.get("boss_timer", 0.0))
	boss_wipe_phase = int(d.get("boss_wipe_phase", 0))
	fever_bar = float(d.get("fever_bar", 0.0))
	fever_active = bool(d.get("fever_active", false))
	fever_timer = float(d.get("fever_timer", 0.0))
	fever_cooldown = float(d.get("fever_cooldown", 0.0))
