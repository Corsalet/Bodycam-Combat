class_name Hud
extends CanvasLayer


const COL_TEXT: = Color8(216, 212, 198)
const COL_MUTED: = Color8(168, 162, 144)
const COL_DIM: = Color8(138, 134, 116)
const COL_FOOT: = Color8(110, 106, 92)
const COL_AMBER: = Color8(255, 207, 77)
const COL_RED: = Color8(255, 91, 77)
const COL_BLUE: = Color8(111, 168, 255)
const COL_DEATH: = Color8(255, 83, 64)
const COL_RU: = COL_RED
const COL_US: = COL_BLUE

var root_ctrl: Control
var rec_label: Label
var tk_ru: Label
var tk_us: Label
var timer_label: Label
var pt_labels: = {}
var feed_box: VBoxContainer
var hint_label: Label
var health_label: Label
var health_bar: ColorRect
var heal_bar: ColorRect
var band_label: Label
var ammo_label: Label
var wname_label: Label
var scope_overlay: Control
var battery: = 87.0
var switch_t: = 0.0
var switch_label: Label
var hit_label: Label
var hit_t: = 0.0


var sel_side: = "RU"
var sel_cls: = "assault"
var menu_root: Control
var btn_ru: Button
var btn_us: Button
var btn_ass: Button
var btn_snp: Button
var loadout_label: RichTextLabel
var sens_s: HSlider
var vol_s: HSlider
var sens_v: Label
var vol_v: Label
var psens_s: HSlider
var pvol_s: HSlider
var psens_v: Label
var pvol_v: Label
var death_root: Control
var death_killer: Label
var death_count: Label
var pause_root: Control
var end_root: Control
var end_title: Label
var end_sub: Label
var end_stats: GridContainer

var _bold: FontVariation

func build() -> void :
	_bold = FontVariation.new()
	_bold.base_font = ThemeDB.fallback_font
	_bold.variation_embolden = 0.55
	root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)
	_post()
	_build_game_hud()
	_build_menu()
	_build_pause()
	_build_death()
	_build_end()
	sens_s.value_changed.connect(_on_sens)
	vol_s.value_changed.connect(_on_vol)
	psens_s.value_changed.connect(_on_sens)
	pvol_s.value_changed.connect(_on_vol)
	show_menu_only()



var hud_game: Control
var money_label: Label
var shop_panel: ColorRect
var shop_msg_l: Label
var shop_money_l: Label
var hz_label: Label
var hz_t: = 0.0
var dot_ret: ColorRect
var dot_ring: ColorRect
var main: Node

func _build_game_hud() -> void :
	hud_game = Control.new()
	var mmap: = Minimap.new()
	mmap.main = main
	mmap.position = Vector2(1078, 10)
	mmap.size = Vector2(192, 192)
	mmap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_game.add_child(mmap)
	hud_game.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_game.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(hud_game)
	rec_label = _label("REC TC 00:00 • 0.4.5 G2", 15, Color(0.92, 0.9, 0.85), Vector2(16, 12), false, hud_game)
	var dot: = ColorRect.new()
	dot.color = Color(0.95, 0.2, 0.15)
	dot.position = Vector2(6, 18)
	dot.size = Vector2(9, 9)
	hud_game.add_child(dot)
	tk_ru = _label("RU 250", 16, COL_RU, Vector2(540, 12), true, hud_game)
	tk_us = _label("US 250", 16, COL_US, Vector2(740, 12), true, hud_game)
	timer_label = _label("10:00", 16, Color(0.9, 0.88, 0.82), Vector2(640, 12), true, hud_game)
	for i in 3:
		var id: String = ["A", "B", "C"][i]
		var l: = _label(id, 16, Color(0.9, 0.9, 0.9), Vector2(510 + i * 130, 42), true, hud_game)
		l.name = "pt_" + id
		pt_labels[id] = l
	_label("ПЕРЕВАЛ-9 // СЕКТОР 4", 11, Color(0.55, 0.53, 0.5), Vector2(510, 150), true, hud_game)
	feed_box = VBoxContainer.new()
	feed_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	feed_box.position = Vector2(640, 190)
	feed_box.size = Vector2(600, 200)
	hud_game.add_child(feed_box)
	hint_label = _label("ЦЕЛЬ: ЗАХВАТИТЬ И УДЕРЖИВАТЬ ТОЧКИ А·В·С", 13, Color(0.85, 0.82, 0.75), Vector2(640, 630), true, hud_game)
	_corner_panel(Vector2(14, 622), Vector2(210, 82))
	health_label = _label("100", 22, Color(0.92, 0.9, 0.85), Vector2(26, 628), false, hud_game)
	health_bar = ColorRect.new()
	health_bar.color = Color(0.55, 0.75, 0.4)
	health_bar.position = Vector2(26, 664)
	health_bar.size = Vector2(150, 7)
	hud_game.add_child(health_bar)
	heal_bar = ColorRect.new()
	heal_bar.color = Color(0.85, 0.75, 0.3)
	heal_bar.position = Vector2(26, 656)
	heal_bar.size = Vector2(0, 5)
	heal_bar.visible = false
	hud_game.add_child(heal_bar)
	money_label = _label("₽ 300", 20, Color(0.85, 0.75, 0.3), Vector2(26, 596), false, hud_game)

	hz_label = _label("", 17, Color(0.95, 0.92, 0.85), Vector2(596, 392), true, hud_game)
	hz_label.visible = false

	dot_ring = ColorRect.new()
	dot_ring.color = Color(0.85, 0.2, 0.15, 0.22)
	dot_ring.position = Vector2(631, 350)
	dot_ring.size = Vector2(18, 18)
	dot_ring.visible = false
	hud_game.add_child(dot_ring)
	dot_ret = ColorRect.new()
	dot_ret.color = Color(0.95, 0.25, 0.18)
	dot_ret.position = Vector2(638, 357)
	dot_ret.size = Vector2(4, 4)
	dot_ret.visible = false
	hud_game.add_child(dot_ret)
	_build_shop()
	band_label = _label("БИНТЫ [3] ×5", 12, Color(0.75, 0.73, 0.68), Vector2(26, 678), false, hud_game)
	_corner_panel(Vector2(1056, 622), Vector2(210, 82))
	wname_label = _label("АК-74", 13, Color(0.85, 0.82, 0.75), Vector2(1068, 628), false, hud_game)
	ammo_label = _label("30 / 120", 26, Color(0.92, 0.9, 0.85), Vector2(1068, 646), false, hud_game)
	_label("CAM_01 // ПЕР.ГАРНИЗОННЫЙ // 21.11.2026", 12, Color(0.55, 0.53, 0.5), Vector2(240, 690), false, hud_game)
	_label("BATT 87%", 12, Color(0.55, 0.53, 0.5), Vector2(1140, 598), false, hud_game)
	hit_label = _label("＋", 26, Color(1, 1, 1), Vector2(620, 350), true, hud_game)
	hit_label.visible = false
	switch_label = _label("", 15, Color(0.9, 0.85, 0.6), Vector2(640, 560), true, hud_game)
	switch_label.visible = false
	scope_overlay = _overlay_base()
	scope_overlay.color = Color(0, 0, 0, 0)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_overlay.visible = false
	var sm: = ShaderMaterial.new()
	var sh: = Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float hole = 0.42;\nvoid fragment() {\n\tvec2 p = (UV - vec2(0.5)) * vec2(1.7778, 1.0);\n\tfloat d = length(p);\n\tfloat a = smoothstep(hole - 0.004, hole + 0.004, d);\n\tCOLOR = vec4(0.0, 0.0, 0.0, a);\n}\n"
	sm.shader = sh
	scope_overlay.material = sm
	scope_overlay.draw.connect(_draw_scope)

func _process(dt: float) -> void :
	if hz_t > 0.0:
		hz_t -= dt
		hz_label.modulate.a = clampf(hz_t / 0.9, 0.0, 1.0)
		if hz_t <= 0.0:
			hz_label.visible = false
	_process_rest(dt)
func _process_rest(dt: float) -> void :
	var grain: ColorRect = root_ctrl.get_node("grain")
	if grain:
		(grain.material as ShaderMaterial).set_shader_parameter("u_time", Time.get_ticks_msec() / 1000.0)
	if hit_t > 0.0:
		hit_t -= dt
		if hit_t <= 0.0:
			hit_label.visible = false
	if switch_t > 0.0:
		switch_t -= dt
		if switch_t <= 0.0:
			switch_label.visible = false

func _draw_scope() -> void :

	var c: = scope_overlay
	var s: = c.size
	var cx: = s.x / 2
	var cy: = s.y / 2
	var ri: = 0.42 * s.y
	var ro: = s.x * 2.0
	var black: = Color(0, 0, 0, 1)
	c.draw_line(Vector2(cx - ri, cy), Vector2(cx + ri, cy), Color(0, 0, 0, 1), 2.0)
	c.draw_line(Vector2(cx, cy - ri), Vector2(cx, cy + ri), Color(0, 0, 0, 1), 2.0)
	c.draw_circle(Vector2(cx, cy), 2.0, Color(0, 0, 0, 1))
	for i in 4:
		var off: = ri * (float(i + 1) / 5.0)
		c.draw_circle(Vector2(cx + off, cy), 1.8, Color(0, 0, 0, 1))
		c.draw_circle(Vector2(cx - off, cy), 1.8, Color(0, 0, 0, 1))
		c.draw_circle(Vector2(cx, cy + off), 1.8, Color(0, 0, 0, 1))



func _overlay_base() -> ColorRect:
	var o: = ColorRect.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(o)
	return o

func _label(txt: String, size: int, col: Color, pos: Vector2, center: = false, parent: Control = null) -> Label:
	var l: = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	if center:
		l.position = Vector2(pos.x - 100, pos.y)
		l.custom_minimum_size.x = 200
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		l.position = pos
	(parent if parent else root_ctrl).add_child(l)
	return l

func _post() -> void :
	var grain: = ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: = Shader.new()
	sh.code = "\nshader_type canvas_item;\nrender_mode blend_add;\nuniform float u_time = 0.0;\nfloat hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }\nvoid fragment(){\n\tvec2 px = UV * vec2(1280.0, 720.0);\n\tfloat n = hash(px + vec2(fract(u_time * 13.7) * 91.0, fract(u_time * 7.3) * 57.0));\n\tfloat g = (n - 0.5) * 0.11;\n\tfloat vig = smoothstep(1.15, 0.35, length(UV - vec2(0.5)) * 1.6);\n\tCOLOR = vec4(vec3(g) + vec3(0.03), 1.0 - vig);\n}\n"












	var sm: = ShaderMaterial.new()
	sm.shader = sh
	grain.material = sm
	grain.name = "grain"
	root_ctrl.add_child(grain)

func _style(bg: Color, border: Color, margin_v: = 8.0, margin_h: = 12.0) -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	return sb

func _panel(overlay: ColorRect, width: float, border: Color) -> VBoxContainer:
	var pc: = PanelContainer.new()
	pc.custom_minimum_size.x = width
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	pc.add_theme_stylebox_override("panel", _style(Color(0.045, 0.055, 0.042, 0.97), border, 14.0, 22.0))
	overlay.add_child(pc)
	var vb: = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	pc.add_child(vb)
	return vb

func _cam_line(vb: VBoxContainer, text: String) -> void :
	var l: = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", COL_DIM)
	vb.add_child(l)

func _sect(vb: VBoxContainer, text: String) -> void :
	var l: = Label.new()
	l.text = text
	l.add_theme_font_override("font", _bold)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", COL_DIM)
	vb.add_child(l)
	var line: = ColorRect.new()
	line.color = Color(1, 1, 1, 0.1)
	line.custom_minimum_size.y = 1
	vb.add_child(line)


func _corner_panel(pos: Vector2, psz: Vector2) -> void :
	var p: = Panel.new()
	p.position = pos
	p.size = psz
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.82)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_game.add_child(p)


func _opt_btn(row: HBoxContainer, main_txt: String, sub_txt: String) -> Button:
	var b: = Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 52
	b.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.22), 7.0, 8.0))
	b.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.35), 7.0, 8.0))
	b.add_theme_stylebox_override("pressed", _style(Color(1, 1, 1, 0.09), Color(1, 1, 1, 0.4), 7.0, 8.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var vb: = VBoxContainer.new()
	vb.name = "vb"
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	var m: = Label.new()
	m.text = main_txt
	m.name = "m"
	m.add_theme_font_override("font", _bold)
	m.add_theme_font_size_override("font_size", 14)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(m)
	var s: = Label.new()
	s.text = sub_txt
	s.name = "s"
	s.add_theme_font_size_override("font_size", 10)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(s)
	b.add_child(vb)
	row.add_child(b)
	return b

func _set_opt_sel(b: Button, sel_col: Color, sel_bg: Color, on: bool) -> void :
	var sb: StyleBoxFlat
	if on:
		sb = _style(sel_bg, sel_col, 7.0, 8.0)
	else:
		sb = _style(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.22), 7.0, 8.0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var m: Label = b.get_node("vb/m")
	var s: Label = b.get_node("vb/s")
	m.add_theme_color_override("font_color", sel_col if on else Color8(207, 202, 187))
	s.add_theme_color_override("font_color", Color8(207, 202, 187) if on else COL_DIM)

func _go_btn(vb: VBoxContainer, text: String, amber: = false) -> Button:
	var b: = Button.new()
	b.text = text
	b.custom_minimum_size.y = 46
	if amber:
		b.add_theme_stylebox_override("normal", _style(Color8(43, 36, 19), Color8(138, 106, 42), 10.0, 12.0))
		b.add_theme_color_override("font_color", Color8(255, 226, 160))
	else:
		b.add_theme_stylebox_override("normal", _style(Color8(29, 43, 22), Color8(90, 138, 58), 10.0, 12.0))
		b.add_theme_color_override("font_color", Color8(207, 232, 168))
	b.add_theme_font_override("font", _bold)
	b.add_theme_font_size_override("font_size", 16)
	vb.add_child(b)
	return b

func _slider_row(vb: VBoxContainer, lab: String, val: float, vmin: float, vmax: float) -> Array:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l: = Label.new()
	l.text = lab
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COL_MUTED)
	row.add_child(l)
	var sl: = HSlider.new()
	sl.min_value = vmin
	sl.max_value = vmax
	sl.value = val
	sl.custom_minimum_size = Vector2(220, 20)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	var v: = Label.new()
	v.text = ("%.1f" % val) if vmax <= 2.0 else str(int(val))
	v.custom_minimum_size.x = 40
	v.add_theme_font_size_override("font_size", 11)
	v.add_theme_color_override("font_color", COL_MUTED)
	row.add_child(v)
	vb.add_child(row)
	return [sl, v]



func _build_menu() -> void :
	menu_root = _overlay_base()
	menu_root.color = Color(0.02, 0.027, 0.02, 0.88)
	var vb: = _panel(menu_root, 560, Color(1, 1, 1, 0.2))
	_cam_line(vb, "CAM_01 // СИСТЕМА АКТИВНА")
	var title: = RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.text = "[b]BODYCAM[/b][color=#ffcf4d]//[/color] ОПЕРАЦИЯ «ПЕРЕВАЛ»"
	title.add_theme_font_override("bold_font", _bold)
	title.add_theme_font_size_override("normal_font_size", 26)
	title.add_theme_font_size_override("bold_font_size", 26)
	title.add_theme_color_override("default_color", Color8(232, 230, 223))
	vb.add_child(title)
	var sub: = Label.new()
	sub.text = "ТАКТИЧЕСКИЙ ШУТЕР • ОФЛАЙН-РАУНД С БОТАМИ • ЗАХВАТ ТОЧЕК • 10 МИНУТ"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", COL_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sub)
	_sect(vb, "СТОРОНА")
	var row1: = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	vb.add_child(row1)
	btn_ru = _opt_btn(row1, "РОССИЯ", "ВС РФ • 127-я МОТСТРЕЛКОВАЯ")
	btn_us = _opt_btn(row1, "США", "US ARMY • 2-я БРОНЕТАНКОВАЯ")
	btn_ru.pressed.connect( func() -> void : _pick_side("RU"))
	btn_us.pressed.connect( func() -> void : _pick_side("US"))
	_sect(vb, "КЛАСС")
	var row2: = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	vb.add_child(row2)
	btn_ass = _opt_btn(row2, "ШТУРМОВИК", "АВТОМАТ + ПИСТОЛЕТ")
	btn_snp = _opt_btn(row2, "СНАЙПЕР", "СНАЙПЕРСКАЯ ВИНТОВКА + ПИСТОЛЕТ")
	btn_ass.pressed.connect( func() -> void : _pick_cls("assault"))
	btn_snp.pressed.connect( func() -> void : _pick_cls("sniper"))

	var lp: = PanelContainer.new()
	lp.add_theme_stylebox_override("panel", _style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.25), 8.0, 11.0))
	loadout_label = RichTextLabel.new()
	loadout_label.bbcode_enabled = true
	loadout_label.fit_content = true
	loadout_label.scroll_active = false
	loadout_label.add_theme_font_size_override("normal_font_size", 12)
	loadout_label.add_theme_color_override("default_color", Color8(207, 202, 187))
	lp.add_child(loadout_label)
	vb.add_child(lp)
	_sect(vb, "УПРАВЛЕНИЕ")
	var grid: = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	for pair in [["W A S D", "движение"], ["SHIFT", "спринт"], ["ЛКМ", "огонь"], ["ПКМ", "прицел / оптика"], ["R", "перезарядка"], ["1 / 2", "смена оружия"], ["ESC", "пауза"]]:
		var b: = Label.new()
		b.text = pair[0]
		b.add_theme_font_override("font", _bold)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", Color8(207, 202, 187))
		grid.add_child(b)
		var s: = Label.new()
		s.text = pair[1]
		s.add_theme_font_size_override("font_size", 11)
		s.add_theme_color_override("font_color", COL_MUTED)
		grid.add_child(s)
	vb.add_child(grid)
	var sl1: = _slider_row(vb, "ЧУВСТВ. ", 1.0, 0.2, 2.0)
	sens_s = sl1[0]
	sens_v = sl1[1]
	var sl2: = _slider_row(vb, "ГРОМКОСТЬ ", 70.0, 0, 100)
	vol_s = sl2[0]
	vol_v = sl2[1]
	var go: = _go_btn(vb, "▶  В БОЙ")
	go.pressed.connect( func() -> void : get_parent().start_match(sel_side, sel_cls))
	var foot: = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	var f1: = Label.new()
	f1.text = "BUILD 22 • v0.4.7 G1  КАРТА «ПЕРЕВАЛ-9»"
	f1.add_theme_font_size_override("font_size", 10)
	f1.add_theme_color_override("font_color", COL_FOOT)
	foot.add_child(f1)
	var f2: = Label.new()
	f2.text = "РЕЖИМ: ЗАХВАТ (ОФЛАЙН)"
	f2.add_theme_font_size_override("font_size", 10)
	f2.add_theme_color_override("font_color", COL_FOOT)
	f2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(f2)
	vb.add_child(foot)
	var note: = Label.new()
	note.text = "NET: онлайн-кооп/-versus режим будет подключён позже (заготовки PeerJS уже в коде)."
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", COL_FOOT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note)
	_refresh_menu_sel()

func _on_sens(v: float) -> void :
	sens_s.set_value_no_signal(v)
	psens_s.set_value_no_signal(v)
	sens_v.text = "%.1f" % v
	psens_v.text = "%.1f" % v
	get_parent().mouse_sens = v

func _on_vol(v: float) -> void :
	vol_s.set_value_no_signal(v)
	pvol_s.set_value_no_signal(v)
	vol_v.text = str(int(v))
	pvol_v.text = str(int(v))
	var db: = linear_to_db(clampf(v / 100.0, 0.001, 1.0)) if v > 0 else -60.0
	AudioServer.set_bus_volume_db(0, db)

func _pick_side(side: String) -> void :
	sel_side = side
	_refresh_menu_sel()

func _pick_cls(cls: String) -> void :
	sel_cls = cls
	_refresh_menu_sel()

func _refresh_menu_sel() -> void :
	_set_opt_sel(btn_ru, COL_RED, Color(120, 20, 10, 0.16), sel_side == "RU")
	_set_opt_sel(btn_us, COL_BLUE, Color(15, 40, 120, 0.16), sel_side == "US")
	_set_opt_sel(btn_ass, COL_AMBER, Color(120, 90, 10, 0.14), sel_cls == "assault")
	_set_opt_sel(btn_snp, COL_AMBER, Color(120, 90, 10, 0.14), sel_cls == "sniper")
	var w: Array = Guns.CLASSES[sel_side][sel_cls]
	var a: Dictionary = Guns.WPN[w[0]]
	var b: Dictionary = Guns.WPN[w[1]]
	loadout_label.text = "СНАРЯЖЕНИЕ: [color=#ffcf4d]" + a["name"] + "[/color] (" + String(a["mode"]).to_lower() + ") • [color=#ffcf4d]" + b["name"] + "[/color]\nУРОН: " + str(a["dmg"]) + " / " + str(b["dmg"]) + " • МАГАЗИН: " + str(a["mag"]) + " / " + str(b["mag"])



func _build_pause() -> void :
	pause_root = _overlay_base()
	pause_root.color = Color(0.02, 0.027, 0.02, 0.88)
	var vb: = _panel(pause_root, 380, Color(1, 1, 1, 0.2))
	_cam_line(vb, "CAM_01 // ПАУЗА")
	var t: = Label.new()
	t.text = "ПАУЗА"
	t.add_theme_font_override("font", _bold)
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color8(232, 230, 223))
	vb.add_child(t)
	var s: = Label.new()
	s.text = "РАУНД ПРИОСТАНОВЛЕН"
	s.add_theme_font_size_override("font_size", 11)
	s.add_theme_color_override("font_color", COL_MUTED)
	vb.add_child(s)
	var sl1: = _slider_row(vb, "ЧУВСТВ. ", 1.0, 0.2, 2.0)
	psens_s = sl1[0]
	psens_v = sl1[1]
	var sl2: = _slider_row(vb, "ГРОМКОСТЬ ", 70.0, 0, 100)
	pvol_s = sl2[0]
	pvol_v = sl2[1]
	var resume: = _go_btn(vb, "▶  ПРОДОЛЖИТЬ")
	resume.pressed.connect( func() -> void : get_parent().resume_game())
	var quit: = _go_btn(vb, "В ГЛАВНОЕ МЕНЮ (СДАТЬСЯ)", true)
	quit.pressed.connect( func() -> void : get_parent().to_menu())
	pause_root.visible = false

func _build_death() -> void :
	death_root = _overlay_base()
	death_root.color = Color(0.02, 0.027, 0.02, 0.55)
	var vb: = _panel(death_root, 460, Color(1, 0.31, 0.24, 0.4))
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_cam_line(vb, "CAM_01 // СИГНАЛ ПОТЕРЯН")
	var lab: = Label.new()
	lab.text = "ВЫ УБИТЫ"
	lab.add_theme_font_override("font", _bold)
	lab.add_theme_font_size_override("font_size", 34)
	lab.add_theme_color_override("font_color", COL_DEATH)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lab)
	death_killer = Label.new()
	death_killer.text = "—"
	death_killer.add_theme_font_size_override("font_size", 14)
	death_killer.add_theme_color_override("font_color", COL_TEXT)
	death_killer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(death_killer)
	death_count = Label.new()
	death_count.text = "РЕСПАВН ЧЕРЕЗ 6"
	death_count.add_theme_font_override("font", _bold)
	death_count.add_theme_font_size_override("font_size", 18)
	death_count.add_theme_color_override("font_color", COL_AMBER)
	death_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(death_count)
	death_root.visible = false

	var dmenu: = _go_btn(vb, "В ГЛАВНОЕ МЕНЮ", true)
	dmenu.pressed.connect( func() -> void : get_parent().to_menu())

func _build_end() -> void :
	end_root = _overlay_base()
	end_root.color = Color(0.02, 0.027, 0.02, 0.88)
	var vb: = _panel(end_root, 460, Color(1, 1, 1, 0.2))
	_cam_line(vb, "CAM_01 // ЗАПИСЬ ЗАВЕРШЕНА")
	end_title = Label.new()
	end_title.text = "—"
	end_title.add_theme_font_override("font", _bold)
	end_title.add_theme_font_size_override("font_size", 32)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_title)
	end_sub = Label.new()
	end_sub.text = "—"
	end_sub.add_theme_font_size_override("font_size", 12)
	end_sub.add_theme_color_override("font_color", COL_MUTED)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_sub)
	end_stats = GridContainer.new()
	end_stats.columns = 2
	end_stats.add_theme_constant_override("h_separation", 24)
	end_stats.add_theme_constant_override("v_separation", 4)
	var sc: = CenterContainer.new()
	sc.add_child(end_stats)
	vb.add_child(sc)
	var again: = _go_btn(vb, "▶  ЕЩЁ РАЗ")
	again.pressed.connect( func() -> void : get_parent().start_match(sel_side, sel_cls))
	var to_menu: = _go_btn(vb, "В ГЛАВНОЕ МЕНЮ", true)
	to_menu.pressed.connect( func() -> void : get_parent().to_menu())
	end_root.visible = false



func show_menu_only() -> void :
	hud_game.visible = false
	menu_root.visible = true
	pause_root.visible = false
	death_root.visible = false
	end_root.visible = false

func hide_all_ov() -> void :
	hud_game.visible = true
	menu_root.visible = false
	pause_root.visible = false
	death_root.visible = false
	end_root.visible = false

func set_timecode(tc: String) -> void :
	rec_label.text = "REC TC " + tc + " • 0.4.5 G2"

func set_score(ru: int, us: int, time_s: int) -> void :
	tk_ru.text = "RU " + str(ru)
	tk_us.text = "US " + str(us)
	timer_label.text = "%02d:%02d" % [time_s / 60, time_s % 60]

func set_points(points: Array) -> void :
	for p in points:
		var l: Label = pt_labels[p["id"]]
		if p["contested"]:
			l.add_theme_color_override("font_color", Color(1, 0.75, 0.2))
		elif p["owner"] == "RU":
			l.add_theme_color_override("font_color", COL_RU)
		elif p["owner"] == "US":
			l.add_theme_color_override("font_color", COL_US)
		else:
			l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

func add_feed(a: String, a_team: String, b: String, b_team: String, weapon: String) -> void :
	var l: = Label.new()
	l.text = a + "  ▶  " + b + "  [" + weapon + "]"
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color8(210, 206, 195) if a_team == "RU" else Color8(170, 195, 235))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	feed_box.add_child(l)
	feed_box.move_child(l, 0)
	var t: = root_ctrl.get_tree().create_timer(6.0)
	t.timeout.connect(l.queue_free)
	while feed_box.get_child_count() > 6:
		var last: = feed_box.get_child(feed_box.get_child_count() - 1)
		feed_box.remove_child(last)
		last.queue_free()

func set_heal(p: float) -> void :
	heal_bar.visible = p > 0.0
	heal_bar.size.x = 150.0 * clampf(p, 0.0, 1.0)

func set_health(hp: float, bandages: int) -> void :
	health_label.text = str(int(hp))
	health_bar.size.x = 150.0 * hp / 100.0
	band_label.text = "БИНТЫ [3] ×" + str(bandages)

func set_ammo(mag: int, reserve: int, wname: String, mode: String) -> void :
	ammo_label.text = str(mag) + " / " + str(reserve)
	wname_label.text = wname + " • " + mode

func _build_shop() -> void :
	shop_panel = ColorRect.new()
	shop_panel.color = Color(0.06, 0.06, 0.05, 0.88)
	shop_panel.position = Vector2(856, 150)
	shop_panel.size = Vector2(400, 340)
	shop_panel.visible = false
	hud_game.add_child(shop_panel)
	_label("МАГАЗИН ОБВЕСОВ  •  [B] ЗАКРЫТЬ", 16, Color(0.9, 0.78, 0.4), Vector2(20, 12), false, shop_panel)
	var items: = [["1", "КОЛЛИМАТОР 1П63", "250"], ["2", "ОПТИКА ПСО-1", "400"], ["3", "ГЛУШИТЕЛЬ", "300"], ["4", "РАСШ. МАГАЗИН", "200"]]
	for i in items.size():
		_label("%s   %s  —  ₽ %s" % [items[i][0], items[i][1], items[i][2]], 18, Color(0.92, 0.9, 0.85), Vector2(20, 56 + i * 44), false, shop_panel)
	shop_msg_l = _label("", 15, Color(0.9, 0.5, 0.3), Vector2(20, 240), false, shop_panel)
	shop_money_l = _label("₽ 300", 22, Color(0.85, 0.75, 0.3), Vector2(20, 280), false, shop_panel)

func show_shop(b: bool) -> void :
	shop_panel.visible = b

func shop_msg(txt: String) -> void :
	shop_msg_l.text = txt

func set_money(v: int) -> void :
	money_label.text = "₽ " + str(v)
	shop_money_l.text = "₽ " + str(v)

func hitzone(zone: String) -> void :
	hz_label.text = zone
	hz_label.modulate = Color(0.9, 0.25, 0.2) if zone == "ГОЛОВА" else (Color(0.95, 0.92, 0.85) if zone == "ТЕЛО" else Color(0.65, 0.72, 0.8))
	hz_label.visible = true
	hz_t = 0.9

func set_dot(b: bool) -> void :
	dot_ret.visible = b
	dot_ring.visible = b

func show_switch(wname: String) -> void :
	switch_label.text = "▸ " + wname
	switch_label.visible = true
	switch_t = 1.4

func hitmarker(ok: bool) -> void :
	hit_label.visible = ok
	hit_t = 0.18

func show_death(killer: String, weapon: String) -> void :
	death_root.visible = true
	death_killer.text = killer + "  [" + weapon + "]"

func hide_death() -> void :
	death_root.visible = false

func set_death_timer(t: float) -> void :
	death_count.text = "РЕСПАВН ЧЕРЕЗ " + str(maxi(1, int(ceil(t))))

func set_ads_scope(on: bool) -> void :
	scope_overlay.visible = on

func show_menu() -> void :
	show_menu_only()

func hide_menu() -> void :
	hide_all_ov()

func show_pause() -> void :
	pause_root.visible = true

func hide_pause() -> void :
	pause_root.visible = false

func show_end(winner: String, player_team: String, ru: int, us: int, kills: int, deaths: int, caps: int) -> void :
	end_root.visible = true
	if winner == "RU":
		end_title.text = "ПОБЕДА РОССИИ"
		end_title.add_theme_color_override("font_color", COL_RED)
	elif winner == "US":
		end_title.text = "ПОБЕДА США"
		end_title.add_theme_color_override("font_color", COL_BLUE)
	else:
		end_title.text = "НИЧЬЯ"
		end_title.add_theme_color_override("font_color", COL_AMBER)
	if winner == "draw":
		end_sub.text = "СЕКТОР НЕ ВЗЯТ НИ КЕМ"
	else:
		end_sub.text = "ВАШ АРМ ОТСТОЯЛ СЕКТОР" if winner == player_team else "СЕКТОР ПОТЕРЯН"
	_fill_stats(ru, us, kills, deaths, caps)

func _fill_stats(ru: int, us: int, kills: int, deaths: int, caps: int) -> void :
	for c in end_stats.get_children():
		c.queue_free()
	for pair in [["УБИЙСТВ", str(kills)], ["СМЕРТЕЙ", str(deaths)], ["ЗАХВАТОВ", str(caps)], ["БИЛЕТЫ RU/US", str(ru) + " / " + str(us)]]:
		var s: = Label.new()
		s.text = pair[0]
		s.add_theme_font_size_override("font_size", 13)
		s.add_theme_color_override("font_color", COL_MUTED)
		end_stats.add_child(s)
		var b: = Label.new()
		b.text = pair[1]
		b.add_theme_font_override("font", _bold)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", COL_TEXT)
		end_stats.add_child(b)

func hide_end() -> void :
	end_root.visible = false


class Minimap extends Control:
	var main: Node

	func _process(_dt: float) -> void :
		if visible:
			queue_redraw()

	func _draw() -> void :
		if main == null or main.player == null:
			return
		var S: = size.x
		var half: = 220.0
		var to_map: = func(wp: Vector3) -> Vector2:
			return Vector2((wp.x + half) / (half * 2.0) * S, (wp.z + half) / (half * 2.0) * S)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.02, 0.82))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.14), false, 1.0)
		for team in ["RU", "US"]:
			var b: Dictionary = World.BASES[team]
			var bm: Vector2 = to_map.call(Vector3(b["x"], 0, b["z"]))
			draw_rect(Rect2(bm - Vector2(4, 4), Vector2(8, 8)), Hud.COL_RU if team == "RU" else Hud.COL_US)
		for p in main.points:
			var col: = Color(0.62, 0.6, 0.55, 0.9)
			if p["owner"] == "RU":
				col = Hud.COL_RU
			elif p["owner"] == "US":
				col = Hud.COL_US
			var m: Vector2 = to_map.call(Vector3(p["x"], 0, p["z"]))
			draw_circle(m, 10.0, Color(col.r, col.g, col.b, 0.32))
			draw_arc(m, 10.0, 0, TAU, 24, col, 2.0)
			draw_string(ThemeDB.fallback_font, m + Vector2(-3.5, 4), str(p["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.93, 0.88))
		for b in main.bots:
			if b.alive and b.team == main.player.team:
				draw_circle(to_map.call(b.global_position), 2.5, Color(0.45, 0.85, 0.4, 0.9))
		var pm: Vector2 = to_map.call(main.player.global_position)
		var fwd: = Vector2( - sin(main.player.yaw), - cos(main.player.yaw)) * 7.0
		var side: = Vector2(fwd.y, - fwd.x) * 0.5
		draw_colored_polygon(PackedVector2Array([pm + fwd, pm - fwd * 0.6 + side, pm - fwd * 0.6 - side]), Color(1.0, 0.82, 0.3))
