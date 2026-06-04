class_name BattleScreen
extends Control

# Arena de batalha SIDE-SCROLLER (v2 §1/3): os monstros marcham para a direita,
# param e atacam o inimigo que entra pela direita. Toda a "juice" visual mora aqui;
# a matematica de combate/economia continua em GameState/BattleSimulator/Formulas.
#
# Camadas da arena (de tras para a frente):
#   ceu -> colinas (parallax) -> chao -> detalhe do chao (parallax) ->
#   pega-clique (tocar = atacar) -> sprites (time + inimigo) -> HUD do inimigo -> numeros
#
# Contrato publico preservado (usado por main.gd):
#   class_name BattleScreen, extends Control
#   signal hud_needs_refresh
#   func notify_team_changed()

signal hud_needs_refresh

const KILLS_PER_PHASE := 10
const ADVANCE_TIME := 0.55          # segundos de marcha entre inimigos comuns
const ENEMY_SWING_INTERVAL := 1.6   # inimigo revida (visual) a cada X s

# --- Estado de combate (logica) ---
var _enemy_hp: float = 0.0
var _enemy_max_hp: float = 1.0
var _enemy_type: EnemyData = null
var _enemy_alive: bool = false
var _kills_this_phase: int = 0

# --- Sprites ---
var _team_sprites: Array = []        # CreatureSprite por slot (ou null)
var _enemy_sprites: Array = []       # 1..N (swarm) compartilhando o mesmo pool de HP
var _attack_timers: Array = []       # cooldown de ataque por slot do time
var _enemy_swing_timer: float = 0.0
var _advance_timer: float = 0.0      # > 0 = marchando (sem ataques)
var _num_cd: float = 0.0             # throttle de numeros flutuantes
var _flash_cd: float = 0.0           # throttle de flash do inimigo

# --- Nos da arena ---
var _arena: Control
var _bg_sky: ColorRect
var _hills_far: _BgLayer
var _hills_near: _BgLayer
var _ground: ColorRect
var _click_catcher: Button
var _sprite_layer: Control
var _crown: Label
var _top_overlay: Control
var _numbers_overlay: Control

# --- HUD do inimigo (sobre a arena) ---
var _enemy_name_lbl: Label
var _enemy_hp_bar: ProgressBar
var _enemy_hp_lbl: Label
var _enrage_bar: ProgressBar
var _enrage_lbl: Label
var _boss_lbl: Label

# --- Faixa inferior ---
var _phase_lbl: Label
var _kill_lbl: Label
var _biome_lbl: Label
var _fever_bar: ProgressBar
var _fever_status_lbl: Label
var _dps_lbl: Label
var _gps_lbl: Label
var _farm_banner: PanelContainer
var _farm_lbl: Label

# ===========================================================================
# Ciclo de vida
# ===========================================================================

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_arena.resized.connect(_relayout)
	_rebuild_team_sprites()
	call_deferred("_relayout")
	call_deferred("_spawn_enemy")

func _process(delta: float) -> void:
	if not visible:
		return

	# Renda passiva de ouro (mesma matematica do offline). (v2 §1)
	GameState.gold += BattleSimulator.gold_per_second(
		GameState.team_base_dps(), GameState.current_phase) * delta

	# Maquina de estado de fever/enrage.
	var events := GameState.combat.update(delta)
	if events.get("boss_enraged", false):
		_on_boss_enraged()

	_num_cd = maxf(_num_cd - delta, 0.0)
	_flash_cd = maxf(_flash_cd - delta, 0.0)

	if _advance_timer > 0.0:
		_tick_advance(delta)
	elif _enemy_alive:
		_tick_combat(delta)

	_process_ultimates(delta)

	# Transicao suave de cor de ceu por bioma.
	var target := ThemeHelper.biome_color(GameState.current_phase)
	_bg_sky.color = _bg_sky.color.lerp(target, delta * 1.5)

	_refresh_ui()
	emit_signal("hud_needs_refresh")

# --- Fase de marcha (entre inimigos comuns) ---

func _tick_advance(delta: float) -> void:
	for s in _team_sprites:
		if s != null:
			s.set_marching(true)
	_scroll_bg(delta, 130.0)
	_advance_timer -= delta
	if _advance_timer <= 0.0:
		for s in _team_sprites:
			if s != null:
				s.set_marching(false)
		_spawn_enemy()

# --- Combate ativo (atacando o inimigo presente) ---

func _tick_combat(delta: float) -> void:
	var fever_mult := GameState.combat.aspd_multiplier()

	# Ataques do time (discretos, por ASPD). A soma estatistica = DPS do GDD.
	for i in _team_sprites.size():
		var m: MonsterInstance = GameState.team[i] if i < GameState.team.size() else null
		var spr = _team_sprites[i]
		if m == null or spr == null:
			continue
		var rate := maxf(m.effective_aspd() * fever_mult, 0.05)
		_attack_timers[i] -= delta
		if _attack_timers[i] <= 0.0:
			_attack_timers[i] += 1.0 / rate
			_monster_attack(i, m, spr)

	# Inimigo revida (so visual: o "wipe" vem do Enrage, v2 §7).
	_enemy_swing_timer -= delta
	if _enemy_swing_timer <= 0.0:
		_enemy_swing_timer = ENEMY_SWING_INTERVAL
		_enemy_swing()

func _monster_attack(slot: int, m: MonsterInstance, spr: CreatureSprite) -> void:
	spr.play_attack()
	# Dano por golpe com critico aleatorio (media = ATK_final*(1+cr*(cd-1))).
	var atk := m.final_atk()
	var is_crit := GameState.rng.randf() < m.effective_crit_rate()
	var crit_mult := m.data.crit_dmg if (is_crit and m.data != null) else 1.0
	var dmg := atk * crit_mult
	if _is_ranged(m):
		var el := m.data.element if m.data != null else "FOGO"
		_spawn_projectile(_sprite_center(spr), _enemy_center(), EmojiDB.projectile(el),
			ThemeHelper.element_color(el), func(): _damage_enemy(dmg, is_crit))
	else:
		_damage_enemy(dmg, is_crit)

func _enemy_swing() -> void:
	var front = _front_sprite()
	for es in _enemy_sprites:
		if es != null:
			es.play_attack()
	if front != null:
		front.play_hurt()

# ===========================================================================
# Dano / inimigos / fases
# ===========================================================================

func _damage_enemy(dmg: float, is_crit: bool = false) -> void:
	if not _enemy_alive:
		return
	_enemy_hp = maxf(_enemy_hp - dmg, 0.0)
	if _flash_cd <= 0.0:
		_flash_cd = 0.04
		var es = _enemy_sprites[GameState.rng.randi() % _enemy_sprites.size()] if not _enemy_sprites.is_empty() else null
		if es != null:
			es.play_hurt()
	if _num_cd <= 0.0:
		_num_cd = 0.06
		var clr := ThemeHelper.FEVER_CLR if is_crit else ThemeHelper.HP_LOW
		var txt := ("%s!" % Numbers.format(dmg)) if is_crit else ("-%s" % Numbers.format(dmg))
		_spawn_number(_enemy_center(), txt, clr, 20 if is_crit else 16)
	if _enemy_hp <= 0.0:
		_on_enemy_killed()

func _spawn_enemy() -> void:
	var phase := GameState.current_phase
	var is_boss := (phase % 10 == 0)
	var enemies := ContentDB.enemies.values()
	if enemies.is_empty():
		return
	_enemy_type = enemies[GameState.rng.randi() % enemies.size()]
	_enemy_max_hp = _enemy_type.hp_mult * (Formulas.boss_hp(phase) if is_boss else Formulas.enemy_hp(phase))
	_enemy_hp = _enemy_max_hp
	_enemy_alive = true
	_enemy_swing_timer = ENEMY_SWING_INTERVAL

	if is_boss:
		GameState.combat.enter_phase(phase)
	else:
		GameState.combat.phase_state = CombatState.PhaseState.COMBAT

	_build_enemy_sprites(is_boss)
	_refresh_enemy_ui()

func _on_enemy_killed() -> void:
	_enemy_alive = false
	var phase := GameState.current_phase
	var is_boss := (phase % 10 == 0)
	var gold := BattleSimulator.gold_per_kill(phase)
	GameState.gold += gold
	_spawn_number(_enemy_center(), "+%s G" % Numbers.format(gold), ThemeHelper.GOLD_COLOR, 18)

	# Anima morte e libera os sprites.
	for es in _enemy_sprites:
		if es != null:
			es.die()
			es.death_finished.connect(es.queue_free)
	_enemy_sprites.clear()
	if _crown != null:
		_crown.visible = false

	if is_boss:
		_advance_phase()
	else:
		_kills_this_phase += 1
		if _kills_this_phase >= KILLS_PER_PHASE:
			_advance_phase()
		else:
			_advance_timer = ADVANCE_TIME   # marcha breve ate o proximo

func _advance_phase() -> void:
	_kills_this_phase = 0
	GameState.current_phase += 1
	if GameState.current_phase > GameState.max_phase:
		GameState.max_phase = GameState.current_phase
	GameState.combat.enter_phase(GameState.current_phase)
	_advance_timer = ADVANCE_TIME

func _on_boss_enraged() -> void:
	# Wipe -> Farm Mode (v2 §7).
	for es in _enemy_sprites:
		if es != null:
			es.queue_free()
	_enemy_sprites.clear()
	_enemy_alive = false
	GameState.current_phase = GameState.combat.farm_phase()
	_kills_this_phase = 0
	_advance_timer = ADVANCE_TIME

func _on_challenge_boss() -> void:
	var boss_phase := GameState.combat.boss_wipe_phase
	GameState.current_phase = boss_phase
	GameState.combat.challenge_boss(boss_phase)
	for es in _enemy_sprites:
		if es != null:
			es.queue_free()
	_enemy_sprites.clear()
	_enemy_alive = false
	_advance_timer = 0.05

# ===========================================================================
# Ultimates (v2 §1/5)
# ===========================================================================

func _process_ultimates(delta: float) -> void:
	for i in GameState.team.size():
		var m := GameState.team[i]
		if m == null:
			continue
		var just_ready := m.add_ult_energy(m.effective_aspd() * MonsterInstance.ULT_ENERGY_PER_ATTACK * delta)
		if just_ready:
			_on_ult_ready(i)
		elif m.is_ult_ready():
			m._ult_auto_timer += delta
			if m._ult_auto_timer >= MonsterInstance.ULT_AUTO_DELAY:
				_fire_ultimate_slot(i)

func _on_ult_ready(slot_idx: int) -> void:
	var spr = _team_sprites[slot_idx] if slot_idx < _team_sprites.size() else null
	if spr != null:
		spr.set_ready_glow(true)
		_spawn_number(_sprite_center(spr) + Vector2(0, -spr.diameter * 0.5), "ULT!", ThemeHelper.FEVER_CLR, 16)

func _fire_ultimate_slot(slot_idx: int) -> void:
	var m := GameState.team[slot_idx] if slot_idx < GameState.team.size() else null
	if m == null:
		return
	var ult_name := m.fire_ultimate()
	if ult_name.is_empty():
		return
	var spr = _team_sprites[slot_idx] if slot_idx < _team_sprites.size() else null
	if spr != null:
		spr.set_ready_glow(false)
		spr.play_attack()
	# Burst placeholder: 3x o DPS do monstro. (v2 §1)
	var dmg := m.expected_dps() * 3.0
	_spawn_number(_enemy_center() + Vector2(0, -44), ult_name, ThemeHelper.FEVER_CLR, 18)
	_damage_enemy(dmg, true)

# ===========================================================================
# Input
# ===========================================================================

func _on_enemy_clicked() -> void:
	if not _enemy_alive:
		return
	var dmg := GameState.click_damage()
	GameState.combat.add_fever_click()
	_damage_enemy(dmg, false)

func _on_monster_clicked(slot_idx: int) -> void:
	if slot_idx >= GameState.team.size():
		return
	var m := GameState.team[slot_idx]
	if m == null:
		return
	var spr = _team_sprites[slot_idx] if slot_idx < _team_sprites.size() else null
	if m.is_ult_ready():
		_fire_ultimate_slot(slot_idx)
	else:
		# Clique no aliado = +5% de Ultimate. (v2 §5)
		if m.add_ult_energy(0.05):
			_on_ult_ready(slot_idx)
		if spr != null:
			var el := m.data.element if m.data != null else "FOGO"
			_spawn_number(_sprite_center(spr), "+ULT", ThemeHelper.element_color(el), 14)

# ===========================================================================
# Construcao da UI
# ===========================================================================

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# --- Topo: fase / kills / bioma ---
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(Color(0, 0, 0, 0.45), 8))
	root.add_child(top_row)
	_phase_lbl = ThemeHelper.label("Fase 1", ThemeHelper.TEXT_DIM, 14)
	top_row.add_child(_phase_lbl)
	_biome_lbl = ThemeHelper.label(ThemeHelper.biome_name(GameState.current_phase),
		ThemeHelper.biome_color(GameState.current_phase).lightened(0.55), 12)
	_biome_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_biome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(_biome_lbl)
	_kill_lbl = ThemeHelper.label("", ThemeHelper.TEXT_DIM, 13)
	top_row.add_child(_kill_lbl)

	# --- Arena (a estrela) ---
	_arena = Control.new()
	_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena.clip_contents = true
	root.add_child(_arena)
	_build_arena_layers()

	# --- Faixa inferior: fever + info + farm ---
	_build_bottom_bar(root)

func _build_arena_layers() -> void:
	_bg_sky = ColorRect.new()
	_bg_sky.color = ThemeHelper.biome_color(GameState.current_phase)
	_bg_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_bg_sky)

	_hills_far = _BgLayer.new()
	_hills_far.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hills_far.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hills_far.col = Color(0, 0, 0, 0.18)
	_hills_far.tile = 230.0
	_hills_far.amp = 70.0
	_arena.add_child(_hills_far)

	_ground = ColorRect.new()
	_ground.color = Color(0, 0, 0, 0.34)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_ground)

	_hills_near = _BgLayer.new()
	_hills_near.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hills_near.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hills_near.col = Color(0, 0, 0, 0.28)
	_hills_near.tile = 150.0
	_hills_near.amp = 34.0
	_arena.add_child(_hills_near)

	# Pega-clique: tocar em area vazia = atacar o inimigo (clicker feel).
	_click_catcher = Button.new()
	_click_catcher.flat = true
	_click_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_click_catcher.focus_mode = Control.FOCUS_NONE
	_click_catcher.pressed.connect(_on_enemy_clicked)
	_arena.add_child(_click_catcher)

	# Camada dos sprites (acima do pega-clique, abaixo dos overlays).
	# IGNORE deixa o clique passar para os sprites (STOP) e, no vazio, para o pega-clique.
	_sprite_layer = Control.new()
	_sprite_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_sprite_layer)

	# Coroa de boss (acima do inimigo).
	_crown = EmojiDB.make_label("👑", 34)
	_crown.visible = false
	_arena.add_child(_crown)

	# HUD do inimigo (nome + HP + enrage), ancorado no topo da arena.
	_top_overlay = Control.new()
	_top_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_top_overlay)
	_build_enemy_hud()

	# Numeros flutuantes (sempre por cima).
	_numbers_overlay = Control.new()
	_numbers_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_numbers_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_numbers_overlay)

func _build_enemy_hud() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 8
	box.offset_left = 60
	box.offset_right = -60
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_overlay.add_child(box)

	_boss_lbl = ThemeHelper.label("BOSS", ThemeHelper.BOSS_CLR, 14)
	_boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_lbl.visible = false
	box.add_child(_boss_lbl)

	_enemy_name_lbl = ThemeHelper.label("...", ThemeHelper.TEXT_MAIN, 15)
	_enemy_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_enemy_name_lbl)

	_enemy_hp_bar = ThemeHelper.progress_bar(ThemeHelper.HP_FULL, 12)
	box.add_child(_enemy_hp_bar)

	_enemy_hp_lbl = ThemeHelper.label("", ThemeHelper.HP_FULL, 12)
	_enemy_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_enemy_hp_lbl)

	_enrage_lbl = ThemeHelper.label("", ThemeHelper.DANGER_CLR, 12)
	_enrage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enrage_lbl.visible = false
	box.add_child(_enrage_lbl)

	_enrage_bar = ThemeHelper.progress_bar(ThemeHelper.DANGER_CLR, 8)
	_enrage_bar.visible = false
	box.add_child(_enrage_bar)

	# HUD nao deve interceptar o clique de ataque.
	for c in box.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_bottom_bar(parent: VBoxContainer) -> void:
	# Banner Farm Mode (acima da faixa de info).
	_farm_banner = PanelContainer.new()
	_farm_banner.visible = false
	_farm_banner.add_theme_stylebox_override("panel",
		ThemeHelper.flat(Color(0.12, 0.06, 0.02), ThemeHelper.FEVER_CLR, 2, 8))
	parent.add_child(_farm_banner)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 4)
	_farm_banner.add_child(fcol)
	fcol.add_child(_centered(ThemeHelper.label("FARM MODE", ThemeHelper.FEVER_CLR, 14)))
	_farm_lbl = _centered(ThemeHelper.label("", ThemeHelper.TEXT_DIM, 12))
	fcol.add_child(_farm_lbl)
	var challenge_btn := ThemeHelper.button("Desafiar Boss", ThemeHelper.BOSS_CLR, 14)
	challenge_btn.pressed.connect(_on_challenge_boss)
	fcol.add_child(challenge_btn)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 104)
	bar.add_theme_constant_override("separation", 0)
	parent.add_child(bar)

	# Fever (esquerda)
	var fever_col := VBoxContainer.new()
	fever_col.custom_minimum_size = Vector2(190, 0)
	fever_col.add_theme_constant_override("separation", 4)
	fever_col.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(Color(0, 0, 0, 0.45), 10))
	bar.add_child(fever_col)
	fever_col.add_child(ThemeHelper.label("FEVER MODE", ThemeHelper.FEVER_CLR, 13))
	_fever_bar = ThemeHelper.progress_bar(ThemeHelper.FEVER_CLR, 16)
	fever_col.add_child(_fever_bar)
	_fever_status_lbl = ThemeHelper.label("Toque para atacar", ThemeHelper.TEXT_DIM, 11)
	_fever_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fever_col.add_child(_fever_status_lbl)

	bar.add_child(VSeparator.new())

	# Info (direita)
	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 5)
	info_col.add_theme_stylebox_override("panel", ThemeHelper.flat_margin(Color(0, 0, 0, 0.40), 10))
	bar.add_child(info_col)
	_dps_lbl = ThemeHelper.label("DPS: —", ThemeHelper.TEXT_MAIN, 15)
	_gps_lbl = ThemeHelper.label("Ouro/s: —", ThemeHelper.GOLD_COLOR, 13)
	info_col.add_child(_dps_lbl)
	info_col.add_child(_gps_lbl)
	info_col.add_child(ThemeHelper.label("Toque no monstro p/ Ultimate", ThemeHelper.TEXT_DIM, 11))

# ===========================================================================
# Sprites: criacao e posicionamento
# ===========================================================================

func _rebuild_team_sprites() -> void:
	for s in _team_sprites:
		if s != null and is_instance_valid(s):
			s.queue_free()
	_team_sprites.clear()
	_attack_timers.clear()
	for i in GameState.TEAM_SIZE:
		var m: MonsterInstance = GameState.team[i] if i < GameState.team.size() else null
		if m == null or m.data == null:
			_team_sprites.append(null)
			_attack_timers.append(0.0)
			continue
		var spr := CreatureSprite.new()
		spr.emoji = EmojiDB.for_monster(m.data.id, m.data.element)
		spr.body_color = ThemeHelper.element_color(m.data.element)
		spr.diameter = _role_size(m.data.role)
		spr.face_dir = 1
		_sprite_layer.add_child(spr)
		var slot := i
		spr.clicked.connect(func(): _on_monster_clicked(slot))
		_team_sprites.append(spr)
		_attack_timers.append(GameState.rng.randf() * 0.4)
	_relayout()

func _build_enemy_sprites(is_boss: bool) -> void:
	for es in _enemy_sprites:
		if es != null and is_instance_valid(es):
			es.queue_free()
	_enemy_sprites.clear()

	var base := _enemy_size(_enemy_type.type) * (1.5 if is_boss else 1.0)
	var count := 3 if (_enemy_type.type == "SWARM" and not is_boss) else 1
	for k in count:
		var es := CreatureSprite.new()
		es.emoji = EmojiDB.for_enemy(_enemy_type.type)
		es.body_color = ThemeHelper.enemy_type_color(_enemy_type.type)
		es.diameter = base
		es.face_dir = -1
		_sprite_layer.add_child(es)
		es.clicked.connect(_on_enemy_clicked)
		_enemy_sprites.append(es)

	_crown.visible = is_boss
	_boss_lbl.visible = is_boss
	_place_enemies()
	# Entrada marchando pela direita.
	var w := _arena.size.x
	for es in _enemy_sprites:
		es.walk_in_from(w * 0.45, 0.6)

func _relayout() -> void:
	var sz := _arena.size
	if sz.x < 10.0 or sz.y < 10.0:
		return
	var ground_y := sz.y * 0.82
	# Chao.
	_ground.position = Vector2(0, ground_y)
	_ground.size = Vector2(sz.x, sz.y - ground_y)
	# Colinas (base na linha do chao).
	_hills_far.base_y = ground_y + 6.0
	_hills_far.queue_redraw()
	_hills_near.base_y = ground_y + 16.0
	_hills_near.queue_redraw()
	# Time em formacao diagonal na esquerda.
	for i in _team_sprites.size():
		var spr = _team_sprites[i]
		if spr == null:
			continue
		_place(spr, _slot_center(i, sz, ground_y))
	_place_enemies()

func _slot_center(i: int, sz: Vector2, ground_y: float) -> Vector2:
	# slot 0 = frente (mais a direita / embaixo); slot 6 = retaguarda.
	var x := sz.x * 0.36 - float(i) * 33.0
	var y := ground_y - float(i % 2) * 46.0 - float(i / 2) * 5.0
	return Vector2(x, y)

func _place_enemies() -> void:
	var sz := _arena.size
	if sz.x < 10.0:
		return
	var ground_y := sz.y * 0.82
	var ex := sz.x * 0.80
	for k in _enemy_sprites.size():
		var es = _enemy_sprites[k]
		if es == null:
			continue
		var off := Vector2(float(k) * 30.0 - 30.0, float(k % 2) * 34.0)
		_place(es, Vector2(ex, ground_y - es.diameter * 0.42) + off)
	if _crown != null and not _enemy_sprites.is_empty():
		var lead = _enemy_sprites[0]
		_crown.position = Vector2(ex - 17.0, ground_y - lead.diameter * 0.42 - lead.diameter * 0.62)

func _place(spr: CreatureSprite, center: Vector2) -> void:
	spr.position = center - spr.size * 0.5

# ===========================================================================
# Projeteis e numeros flutuantes
# ===========================================================================

func _spawn_projectile(from: Vector2, to: Vector2, emoji: String, tint: Color, on_hit: Callable) -> void:
	var p := EmojiDB.make_label(emoji, 30)
	p.size = Vector2(40, 40)
	p.position = from - Vector2(20, 20)
	p.modulate = tint.lightened(0.2)
	_numbers_overlay.add_child(p)
	var dur := clampf(from.distance_to(to) / 900.0, 0.12, 0.4)
	var tw := create_tween()
	tw.tween_property(p, "position", to - Vector2(20, 20), dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if on_hit.is_valid():
			on_hit.call()
		p.queue_free()
	)

func _spawn_number(pos: Vector2, text: String, color: Color, size: int = 16) -> void:
	var lbl := ThemeHelper.label(text, color, size)
	lbl.position = pos - Vector2(30, 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_numbers_overlay.add_child(lbl)
	var drift := Vector2(GameState.rng.randf_range(-22.0, 22.0), -70.0)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + drift, 0.85)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.85)
	tw.tween_callback(lbl.queue_free)

# ===========================================================================
# Atualizacao da UI
# ===========================================================================

func _refresh_ui() -> void:
	_refresh_enemy_ui()
	_refresh_fever_ui()
	_refresh_info_ui()
	_refresh_glow()

func _refresh_enemy_ui() -> void:
	var phase := GameState.current_phase
	var is_boss := (phase % 10 == 0)
	var in_fight := GameState.combat.phase_state == CombatState.PhaseState.BOSS_FIGHT
	var in_farm := GameState.combat.phase_state == CombatState.PhaseState.FARM_MODE

	if _enemy_alive and _enemy_type != null and _enemy_max_hp > 0.0:
		var frac := clampf(_enemy_hp / _enemy_max_hp, 0.0, 1.0)
		_enemy_hp_bar.value = frac
		_enemy_hp_bar.add_theme_stylebox_override("fill",
			ThemeHelper.flat(ThemeHelper.hp_color(frac), Color.TRANSPARENT, 0, 3))
		_enemy_hp_lbl.text = "%s / %s" % [Numbers.format(maxf(_enemy_hp, 0.0)), Numbers.format(_enemy_max_hp)]
		_enemy_name_lbl.text = _enemy_type.display_name
		_enemy_hp_bar.visible = true
		_enemy_hp_lbl.visible = true
		_enemy_name_lbl.visible = true
	else:
		_enemy_hp_bar.visible = false
		_enemy_hp_lbl.visible = false
		_enemy_name_lbl.visible = (_advance_timer > 0.0)
		if _advance_timer > 0.0:
			_enemy_name_lbl.text = "Marchando..."

	if is_boss and in_fight and _enemy_alive:
		var timer := GameState.combat.boss_timer
		var ratio := 1.0 - clampf(timer / Formulas.ENRAGE_SECONDS, 0.0, 1.0)
		_enrage_bar.value = ratio
		_enrage_bar.visible = true
		_enrage_lbl.text = "Enrage em %.1fs" % maxf(Formulas.ENRAGE_SECONDS - timer, 0.0)
		_enrage_lbl.visible = true
		_enrage_bar.add_theme_stylebox_override("fill",
			ThemeHelper.flat(ThemeHelper.DANGER_CLR.lerp(ThemeHelper.BOSS_CLR, 1.0 - ratio), Color.TRANSPARENT, 0, 3))
	else:
		_enrage_bar.visible = false
		_enrage_lbl.visible = false
	_boss_lbl.visible = is_boss and _enemy_alive and not in_farm
	if _crown != null:
		_crown.visible = is_boss and _enemy_alive

	_phase_lbl.text = ("BOSS %d" % phase) if is_boss else ("Fase %d" % phase)
	_phase_lbl.add_theme_color_override("font_color",
		ThemeHelper.BOSS_CLR if (is_boss and in_fight) else ThemeHelper.TEXT_DIM)
	_biome_lbl.text = ThemeHelper.biome_name(phase)
	_kill_lbl.text = ("%d / %d" % [_kills_this_phase, KILLS_PER_PHASE]) if not is_boss else ""

	_farm_banner.visible = in_farm
	if in_farm:
		_farm_lbl.text = "Farmando fase %d — boss travado em %d" % [
			GameState.combat.farm_phase(), GameState.combat.boss_wipe_phase]

func _refresh_fever_ui() -> void:
	var c := GameState.combat
	_fever_bar.value = 1.0 if c.fever_active else c.fever_bar
	if c.fever_active:
		_fever_bar.add_theme_stylebox_override("fill", ThemeHelper.flat(ThemeHelper.FEVER_CLR.lightened(0.3)))
		_fever_status_lbl.text = "ATIVO! (%.1fs)" % c.fever_timer
		_fever_status_lbl.add_theme_color_override("font_color", ThemeHelper.FEVER_CLR)
	elif c.fever_cooldown > 0.0:
		_fever_bar.add_theme_stylebox_override("fill", ThemeHelper.flat(ThemeHelper.TEXT_DIM))
		_fever_status_lbl.text = "Cooldown: %.0fs" % c.fever_cooldown
		_fever_status_lbl.add_theme_color_override("font_color", ThemeHelper.TEXT_DIM)
	else:
		_fever_bar.add_theme_stylebox_override("fill", ThemeHelper.flat(ThemeHelper.FEVER_CLR))
		_fever_status_lbl.text = "Toque para atacar"
		_fever_status_lbl.add_theme_color_override("font_color", ThemeHelper.TEXT_DIM)

func _refresh_info_ui() -> void:
	var dps := GameState.team_base_dps()
	_dps_lbl.text = "DPS: %s" % Numbers.format(dps)
	_gps_lbl.text = "Ouro/s: %s" % Numbers.format(BattleSimulator.gold_per_second(dps, GameState.current_phase))

func _refresh_glow() -> void:
	for i in _team_sprites.size():
		var spr = _team_sprites[i]
		var m: MonsterInstance = GameState.team[i] if i < GameState.team.size() else null
		if spr != null and m != null:
			spr.set_ready_glow(m.is_ult_ready())

# ===========================================================================
# Parallax
# ===========================================================================

func _scroll_bg(delta: float, speed: float) -> void:
	_hills_far.scroll += speed * 0.35 * delta
	_hills_far.queue_redraw()
	_hills_near.scroll += speed * delta
	_hills_near.queue_redraw()

# ===========================================================================
# Helpers
# ===========================================================================

func _is_ranged(m: MonsterInstance) -> bool:
	if m == null or m.data == null:
		return false
	return m.data.role.begins_with("RANGED") or m.data.range_px >= 150.0

func _role_size(role: String) -> float:
	if role == "MELEE_TANK" or role == "MELEE_BRUISER":
		return 96.0
	if role == "RANGED_NUKE":
		return 84.0
	if role == "MELEE_ASSASSINO":
		return 72.0
	return 78.0

func _enemy_size(type: String) -> float:
	if type == "BRUISER":
		return 122.0
	if type == "SWARM":
		return 52.0
	if type == "DIVER":
		return 80.0
	if type == "HEALER":
		return 82.0
	return 88.0

func _sprite_center(spr: CreatureSprite) -> Vector2:
	return spr.position + spr.size * 0.5

func _enemy_center() -> Vector2:
	if _enemy_sprites.is_empty():
		return Vector2(_arena.size.x * 0.80, _arena.size.y * 0.55)
	var lead = _enemy_sprites[0]
	return lead.position + lead.size * 0.5

func _front_sprite() -> CreatureSprite:
	for s in _team_sprites:
		if s != null:
			return s
	return null

func _centered(lbl: Label) -> Label:
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

# ===========================================================================
# API publica
# ===========================================================================

func notify_team_changed() -> void:
	_rebuild_team_sprites()

# ===========================================================================
# Camada de parallax (colinas) — classe interna
# ===========================================================================

class _BgLayer extends Control:
	var col: Color = Color(0, 0, 0, 0.25)
	var scroll: float = 0.0
	var amp: float = 40.0
	var tile: float = 180.0
	var base_y: float = 0.0

	func _draw() -> void:
		if base_y <= 0.0:
			base_y = size.y * 0.82
		var w := size.x
		var off := fmod(scroll, tile)
		var x := -off - tile
		while x < w + tile:
			_bump(x)
			x += tile

	func _bump(x0: float) -> void:
		var pts := PackedVector2Array()
		pts.append(Vector2(x0, size.y))
		var steps := 12
		for i in steps + 1:
			var t := float(i) / float(steps)
			pts.append(Vector2(x0 + t * tile, base_y - sin(t * PI) * amp))
		pts.append(Vector2(x0 + tile, size.y))
		draw_colored_polygon(pts, col)
