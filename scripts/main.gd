extends Control
# Gerenciador de telas: TopHUD + 3 abas (Batalha / Time / Gacha) + auto-save.
# Substitui o antigo bootstrap de texto.

const AUTOSAVE_INTERVAL := 30.0   # segundos entre auto-saves

var _hud: TopHUD
var _battle: BattleScreen
var _team: TeamScreen
var _gacha: GachaScreen
var _content: Control             # container das telas (excluindo HUD e tabs)
var _tab_buttons: Array           # Button por aba
var _current_screen: Control      = null
var _autosave_timer: float        = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Semente o estado de demo se o save estiver vazio
	var offline_gold := SaveManager.load_game()
	if GameState.team.is_empty():
		_seed_demo_state()
	if offline_gold > 0.0:
		print("[Main] Ouro offline creditado: %s" % Numbers.format(offline_gold))

	_build_layout()
	_show_screen(_battle)

# ---------------------------------------------------------------------------
# Layout raiz
# ---------------------------------------------------------------------------

func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# HUD topo
	_hud = TopHUD.new()
	root.add_child(_hud)

	# Área de conteúdo (expande)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	root.add_child(_content)

	# Cria as telas (invisíveis até serem selecionadas)
	_battle = BattleScreen.new()
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle.visible = false
	_battle.hud_needs_refresh.connect(func(): _hud.refresh())
	_content.add_child(_battle)

	_team = TeamScreen.new()
	_team.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_team.visible = false
	_team.team_changed.connect(_on_team_changed)
	_content.add_child(_team)

	_gacha = GachaScreen.new()
	_gacha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gacha.visible = false
	_gacha.inventory_changed.connect(_on_inventory_changed)
	_content.add_child(_gacha)

	# Barra de abas inferior
	_build_tab_bar(root)

func _build_tab_bar(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", ThemeHelper.BG_PANEL)
	parent.add_child(sep)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 68)
	bar.add_theme_constant_override("separation", 0)
	bar.add_theme_stylebox_override("panel", ThemeHelper.flat(ThemeHelper.BG_ROOT))
	parent.add_child(bar)

	_tab_buttons = []
	var tab_data := [
		{"label": "Batalha", "screen_idx": 0, "color": Color(0.20, 0.55, 0.90)},
		{"label": "Time",    "screen_idx": 1, "color": Color(0.25, 0.70, 0.30)},
		{"label": "Gacha",   "screen_idx": 2, "color": Color(0.70, 0.45, 0.10)},
	]

	for td in tab_data:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = td["label"]
		btn.add_theme_font_size_override("font_size", 16)
		_style_tab(btn, td["color"], false)
		var idx: int = td["screen_idx"]
		btn.pressed.connect(func(): _on_tab_pressed(idx))
		bar.add_child(btn)
		_tab_buttons.append({"btn": btn, "color": td["color"]})

# ---------------------------------------------------------------------------
# Navegação entre abas
# ---------------------------------------------------------------------------

func _on_tab_pressed(idx: int) -> void:
	var screens := [_battle, _team, _gacha]
	_show_screen(screens[idx])
	_refresh_tab_styles(idx)

func _show_screen(screen: Control) -> void:
	if _current_screen != null:
		_current_screen.visible = false
	_current_screen = screen
	screen.visible = true
	_hud.refresh()

func _refresh_tab_styles(active_idx: int) -> void:
	for i in _tab_buttons.size():
		var td: Dictionary = _tab_buttons[i]
		_style_tab(td["btn"], td["color"], i == active_idx)

func _style_tab(btn: Button, color: Color, active: bool) -> void:
	var bg := color.darkened(0.5 if not active else 0.15)
	var border_w := 3 if active else 0
	btn.add_theme_stylebox_override("normal",  ThemeHelper.flat(bg, color, border_w, 0))
	btn.add_theme_stylebox_override("hover",   ThemeHelper.flat(bg.lightened(0.08), color, border_w, 0))
	btn.add_theme_stylebox_override("pressed", ThemeHelper.flat(bg.darkened(0.08), color, border_w, 0))
	btn.add_theme_stylebox_override("focus",   ThemeHelper.flat(bg, color, border_w, 0))
	btn.add_theme_color_override("font_color", ThemeHelper.TEXT_MAIN if active else ThemeHelper.TEXT_DIM)

# ---------------------------------------------------------------------------
# Reatividade entre telas
# ---------------------------------------------------------------------------

func _on_team_changed() -> void:
	# Notifica a tela de batalha para reconstruir os cards de monstros
	if is_instance_valid(_battle):
		_battle.notify_team_changed()
	_hud.refresh()

func _on_inventory_changed() -> void:
	if is_instance_valid(_team):
		_team.refresh()
	_hud.refresh()

# ---------------------------------------------------------------------------
# Loop principal: auto-save + HUD
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		SaveManager.save_game()

# ---------------------------------------------------------------------------
# Estado de demo (usado só quando não há save)
# ---------------------------------------------------------------------------

func _seed_demo_state() -> void:
	GameState.current_phase = 1
	GameState.max_phase     = 1
	GameState.gold          = 5000.0
	GameState.gems          = 300

	var starter_ids := ["emberfox", "ignis_knight", "slurp", "pebble", "zappcat"]
	for id in starter_ids:
		var md := ContentDB.get_monster(id)
		if md != null:
			GameState.add_to_team(MonsterInstance.new(md, 15, 1))

	# Alguns monstros no inventário para demonstrar o gacha
	for id in ["flare_dragon", "tidal_turtle", "gaia_titan"]:
		var md := ContentDB.get_monster(id)
		if md != null:
			GameState.inventory.append(MonsterInstance.new(md, 1, 1))
