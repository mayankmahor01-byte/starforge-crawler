class_name GameHUD
extends CanvasLayer

signal gas_changed(pressed: bool)
signal brake_changed(pressed: bool)
signal boost_changed(pressed: bool)
signal restart_requested()
signal button_popped()

var _distance_label: Label
var _score_label: Label
var _combo_badge: PanelContainer
var _combo_label: Label
var _speed_label: Label
var _battery_bar: ProgressBar
var _boost_bar: ProgressBar
var _popup_container: Control
var _gameover_panel: PanelContainer
var _gameover_title: Label
var _gameover_stats: Label


func _ready() -> void:
	_build_ui()


func _make_candy_style(bg: Color, border: Color, radius: int = 22, bottom_depth: int = 7) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = bottom_depth
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.shadow_color = Color(0.05, 0.07, 0.15, 0.42)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	return sb


func _style_label(lbl: Label, size: int, color: Color = Color.WHITE, outline_size: int = 6) -> void:
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.12, 0.20))
	lbl.add_theme_constant_override("outline_size", outline_size)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- TOP BAR (Distance, Score, Battery, Restart) ---
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 22
	top_bar.offset_right = -22
	top_bar.offset_top = 18
	top_bar.offset_bottom = 86
	top_bar.add_theme_constant_override("separation", 16)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)

	# Distance Pill
	var dist_pill := PanelContainer.new()
	dist_pill.add_theme_stylebox_override("panel", _make_candy_style(Color(0.14, 0.62, 0.98), Color(0.09, 0.14, 0.25), 20, 6))
	top_bar.add_child(dist_pill)
	var dist_margin := MarginContainer.new()
	dist_margin.add_theme_constant_override("margin_left", 18)
	dist_margin.add_theme_constant_override("margin_right", 18)
	dist_pill.add_child(dist_margin)
	_distance_label = Label.new()
	_distance_label.text = "0 m"
	_style_label(_distance_label, 28, Color.WHITE, 6)
	dist_margin.add_child(_distance_label)

	# Score / Star Shards Pill
	var score_pill := PanelContainer.new()
	score_pill.add_theme_stylebox_override("panel", _make_candy_style(Color(1.0, 0.72, 0.08), Color(0.28, 0.15, 0.04), 20, 6))
	top_bar.add_child(score_pill)
	var score_margin := MarginContainer.new()
	score_margin.add_theme_constant_override("margin_left", 18)
	score_margin.add_theme_constant_override("margin_right", 18)
	score_pill.add_child(score_margin)
	_score_label = Label.new()
	_score_label.text = "★ 0"
	_style_label(_score_label, 28, Color(1.0, 0.99, 0.86), 6)
	score_margin.add_child(_score_label)

	# Combo Multiplier Badge
	_combo_badge = PanelContainer.new()
	_combo_badge.add_theme_stylebox_override("panel", _make_candy_style(Color(0.96, 0.18, 0.56), Color(0.25, 0.04, 0.16), 20, 6))
	_combo_badge.visible = false
	top_bar.add_child(_combo_badge)
	var combo_m := MarginContainer.new()
	combo_m.add_theme_constant_override("margin_left", 14)
	combo_m.add_theme_constant_override("margin_right", 14)
	_combo_badge.add_child(combo_m)
	_combo_label = Label.new()
	_combo_label.text = "x2!"
	_style_label(_combo_label, 26, Color(1.0, 0.96, 0.55), 6)
	combo_m.add_child(_combo_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	# Battery Bar
	var bat_box := VBoxContainer.new()
	bat_box.custom_minimum_size = Vector2(210, 0)
	top_bar.add_child(bat_box)
	var bat_lbl := Label.new()
	bat_lbl.text = "BATTERY"
	_style_label(bat_lbl, 15, Color(0.9, 1.0, 0.92), 4)
	bat_box.add_child(bat_lbl)

	_battery_bar = ProgressBar.new()
	_battery_bar.min_value = 0.0
	_battery_bar.max_value = 100.0
	_battery_bar.value = 100.0
	_battery_bar.show_percentage = false
	_battery_bar.custom_minimum_size = Vector2(210, 26)
	_battery_bar.add_theme_stylebox_override("background", _make_candy_style(Color(0.12, 0.14, 0.22), Color(0.06, 0.08, 0.14), 12, 4))
	_battery_bar.add_theme_stylebox_override("fill", _make_candy_style(Color(0.26, 0.90, 0.28), Color(0.08, 0.35, 0.10), 10, 3))
	bat_box.add_child(_battery_bar)

	# Quick Restart Button
	var restart_btn := _create_touch_button("↻", Color(0.55, 0.32, 0.96), Color(0.18, 0.08, 0.35), Vector2(68, 62), 30)
	restart_btn.pressed.connect(func():
		button_popped.emit()
		restart_requested.emit()
	)
	top_bar.add_child(restart_btn)

	# --- CENTER FLOATING POPUP LAYER ---
	_popup_container = Control.new()
	_popup_container.set_anchors_preset(Control.PRESET_CENTER)
	_popup_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_popup_container)

	# --- BOTTOM CONTROLS ---
	# Bottom-Left: BRAKE / TILT LEFT
	var brake_btn := _create_touch_button("BRAKE\n◀ TILT", Color(0.96, 0.28, 0.36), Color(0.32, 0.06, 0.10), Vector2(180, 118), 24)
	brake_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	brake_btn.offset_left = 26
	brake_btn.offset_top = -144
	brake_btn.offset_right = 206
	brake_btn.offset_bottom = -26
	brake_btn.button_down.connect(func():
		_bounce_button(brake_btn, 0.90)
		button_popped.emit()
		brake_changed.emit(true)
	)
	brake_btn.button_up.connect(func():
		_bounce_button(brake_btn, 1.0)
		brake_changed.emit(false)
	)
	root.add_child(brake_btn)

	# Bottom-Center: Speedometer + Boost Gauge
	var center_dash := VBoxContainer.new()
	center_dash.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center_dash.offset_left = 340
	center_dash.offset_right = -440
	center_dash.offset_top = -98
	center_dash.offset_bottom = -22
	center_dash.alignment = BoxContainer.ALIGNMENT_CENTER
	center_dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center_dash)

	_speed_label = Label.new()
	_speed_label.text = "0 KM/H"
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_speed_label, 30, Color(1.0, 0.98, 0.85), 6)
	center_dash.add_child(_speed_label)

	_boost_bar = ProgressBar.new()
	_boost_bar.min_value = 0.0
	_boost_bar.max_value = 100.0
	_boost_bar.value = 100.0
	_boost_bar.show_percentage = false
	_boost_bar.custom_minimum_size = Vector2(220, 22)
	_boost_bar.add_theme_stylebox_override("background", _make_candy_style(Color(0.12, 0.14, 0.22), Color(0.06, 0.08, 0.14), 11, 4))
	_boost_bar.add_theme_stylebox_override("fill", _make_candy_style(Color(0.06, 0.90, 1.0), Color(0.04, 0.32, 0.45), 9, 3))
	center_dash.add_child(_boost_bar)

	# Bottom-Right: BOOST + GAS
	var right_box := HBoxContainer.new()
	right_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right_box.offset_left = -396
	right_box.offset_top = -144
	right_box.offset_right = -26
	right_box.offset_bottom = -26
	right_box.add_theme_constant_override("separation", 16)
	root.add_child(right_box)

	var boost_btn := _create_touch_button("⚡ BOOST", Color(0.06, 0.78, 0.98), Color(0.04, 0.22, 0.38), Vector2(168, 118), 24)
	boost_btn.button_down.connect(func():
		_bounce_button(boost_btn, 0.90)
		button_popped.emit()
		boost_changed.emit(true)
	)
	boost_btn.button_up.connect(func():
		_bounce_button(boost_btn, 1.0)
		boost_changed.emit(false)
	)
	right_box.add_child(boost_btn)

	var gas_btn := _create_touch_button("GAS\nTILT ▶", Color(0.24, 0.85, 0.22), Color(0.06, 0.30, 0.08), Vector2(186, 118), 24)
	gas_btn.button_down.connect(func():
		_bounce_button(gas_btn, 0.90)
		button_popped.emit()
		gas_changed.emit(true)
	)
	gas_btn.button_up.connect(func():
		_bounce_button(gas_btn, 1.0)
		gas_changed.emit(false)
	)
	right_box.add_child(gas_btn)

	# --- GAME OVER / INSTANT RETRY MODAL ---
	_gameover_panel = PanelContainer.new()
	_gameover_panel.set_anchors_preset(Control.PRESET_CENTER)
	_gameover_panel.offset_left = -220
	_gameover_panel.offset_right = 220
	_gameover_panel.offset_top = -145
	_gameover_panel.offset_bottom = 145
	_gameover_panel.add_theme_stylebox_override("panel", _make_candy_style(Color(0.16, 0.20, 0.36, 0.96), Color(1.0, 0.78, 0.16), 28, 10))
	_gameover_panel.visible = false
	root.add_child(_gameover_panel)

	var go_m := MarginContainer.new()
	go_m.add_theme_constant_override("margin_left", 28)
	go_m.add_theme_constant_override("margin_right", 28)
	go_m.add_theme_constant_override("margin_top", 24)
	go_m.add_theme_constant_override("margin_bottom", 24)
	_gameover_panel.add_child(go_m)

	var go_v := VBoxContainer.new()
	go_v.add_theme_constant_override("separation", 16)
	go_v.alignment = BoxContainer.ALIGNMENT_CENTER
	go_m.add_child(go_v)

	_gameover_title = Label.new()
	_gameover_title.text = "ROVER FLIPPED!"
	_gameover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_gameover_title, 34, Color(1.0, 0.86, 0.22), 7)
	go_v.add_child(_gameover_title)

	_gameover_stats = Label.new()
	_gameover_stats.text = "Distance: 0 m\nScore: ★ 0"
	_gameover_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_gameover_stats, 24, Color.WHITE, 5)
	go_v.add_child(_gameover_stats)

	var retry_btn := _create_touch_button("PLAY AGAIN!", Color(0.24, 0.88, 0.24), Color(0.06, 0.30, 0.08), Vector2(260, 74), 28)
	retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_btn.pressed.connect(func():
		button_popped.emit()
		restart_requested.emit()
	)
	go_v.add_child(retry_btn)


func _create_touch_button(txt: String, bg: Color, border: Color, min_sz: Vector2, font_sz: int) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = min_sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.pivot_offset = min_sz * 0.5
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", border)
	btn.add_theme_constant_override("outline_size", 6)

	var normal := _make_candy_style(bg, border, 24, 9)
	var pressed := _make_candy_style(bg.lightened(0.12), border, 24, 4)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn


func _bounce_button(btn: Control, target_scale: float) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_ELASTIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE * target_scale, 0.22)


func update_telemetry(distance_m: int, score: int, combo: int, speed_kmh: float, battery: float, boost: float) -> void:
	_distance_label.text = "%d m" % distance_m
	_score_label.text = "★ %d" % score
	_speed_label.text = "%d KM/H" % int(round(speed_kmh))
	_battery_bar.value = battery
	_boost_bar.value = boost

	if combo > 1:
		_combo_badge.visible = true
		_combo_label.text = "x%d!" % combo
	else:
		_combo_badge.visible = false


func show_popup(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-220, -140)
	lbl.custom_minimum_size = Vector2(440, 60)
	lbl.pivot_offset = Vector2(220, 30)
	lbl.scale = Vector2(0.3, 0.3)
	_style_label(lbl, 38, color, 8)
	_popup_container.add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.12, 1.12), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", -245.0, 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45).set_delay(0.65)
	tw.chain().tween_callback(lbl.queue_free)


func show_game_over(reason: String, distance_m: int, score: int) -> void:
	_gameover_title.text = reason
	_gameover_stats.text = "Distance: %d m\nScore: ★ %d" % [distance_m, score]
	_gameover_panel.visible = true
	_gameover_panel.pivot_offset = _gameover_panel.size * 0.5
	_gameover_panel.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(_gameover_panel, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_game_over() -> void:
	_gameover_panel.visible = false
