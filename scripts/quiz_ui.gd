class_name QuizUI
extends CanvasLayer
## Papan soal ala Baldi. Game di-pause selama soal tampil.
## Pakai: var q := QuizUI.open(self, nomor_buku); q.finished.connect(func(benar, salah): ...)
## 30 detik untuk semua soal di satu buku. Tanpa tulisan benar/salah per soal; hasil muncul di akhir.

signal finished(correct: int, wrong: int)

var book_number := 1
var questions: Array[Dictionary] = []
var index := 0
var correct := 0
var wrong := 0
var time_limit := 30.0

var _time_left := 30.0
var _done := false
var _locked := false
var _was_paused := false
var _jitter := 0.0

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _timer_label: Label
var _timer_bar: ProgressBar
var _bar_fill: StyleBoxFlat
var _dots_box: HBoxContainer
var _dots: Array[Panel] = []
var _question: Label
var _broken_box: Control
var _broken_layers: Array[Label] = []
var _input: LineEdit
var _feedback: Label

const CHALK := Color(0.95, 0.95, 0.9)


static func open(host: Node, book: int) -> QuizUI:
	var ui := QuizUI.new()
	ui.book_number = book
	host.get_tree().root.add_child(ui)
	return ui


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	questions = QuestionBank.make_quiz(book_number)
	_time_left = time_limit
	_build_ui()
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_question()
	_pop_in()


func _tw() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _box_style(bg: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	return s


func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 0)
	var ps := _box_style(Color(0.06, 0.17, 0.13), 22, Color(0.55, 0.36, 0.17), 12)
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 26
	ps.shadow_offset = Vector2(0, 10)
	_panel.add_theme_stylebox_override("panel", ps)
	_panel.modulate.a = 0.0
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 24)
	_title.modulate = Color(CHALK, 0.85)
	head.add_child(_title)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 28)
	head.add_child(_timer_label)

	_timer_bar = ProgressBar.new()
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = time_limit
	_timer_bar.value = time_limit
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 12)
	_timer_bar.add_theme_stylebox_override("background", _box_style(Color(0, 0, 0, 0.35), 6))
	_bar_fill = _box_style(Color(0.4, 0.85, 0.5), 6)
	_timer_bar.add_theme_stylebox_override("fill", _bar_fill)
	box.add_child(_timer_bar)

	_dots_box = HBoxContainer.new()
	_dots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_box.add_theme_constant_override("separation", 12)
	box.add_child(_dots_box)
	for i in questions.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(16, 16)
		_dots_box.add_child(d)
		_dots.append(d)

	var area := Control.new()
	area.custom_minimum_size = Vector2(0, 150)
	area.clip_contents = true
	box.add_child(area)
	_question = Label.new()
	_question.set_anchors_preset(Control.PRESET_FULL_RECT)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.add_theme_font_size_override("font_size", 48)
	_question.add_theme_color_override("font_color", CHALK)
	area.add_child(_question)
	_broken_box = Control.new()
	_broken_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_broken_box.clip_contents = true
	_broken_box.visible = false
	area.add_child(_broken_box)
	for i in 3:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 40)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.modulate = Color(1, 1, 1, 0.85)
		_broken_box.add_child(l)
		_broken_layers.append(l)

	_input = LineEdit.new()
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.placeholder_text = "Ketik jawabanmu, lalu Enter"
	_input.add_theme_font_size_override("font_size", 34)
	_input.add_theme_color_override("font_color", CHALK)
	_input.add_theme_color_override("caret_color", CHALK)
	var line := _box_style(Color(0, 0, 0, 0.25), 10, Color(CHALK, 0.85), 0)
	line.border_width_bottom = 3
	line.content_margin_top = 10
	line.content_margin_bottom = 10
	_input.add_theme_stylebox_override("normal", line)
	_input.add_theme_stylebox_override("focus", line)
	_input.text_submitted.connect(_submit)
	box.add_child(_input)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 30)
	_feedback.custom_minimum_size = Vector2(0, 40)
	box.add_child(_feedback)


func _pop_in() -> void:
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.9, 0.9)
	var tw := _tw().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.74, 0.3)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_dots() -> void:
	for i in _dots.size():
		var col := Color(CHALK, 0.25)
		var border := Color(CHALK, 0.6)
		if i < index:
			col = Color(0.95, 0.78, 0.3)       # sudah dijawab
			border = col
		elif i == index:
			col = Color(CHALK, 0.95)           # soal sekarang
			border = col
		_dots[i].add_theme_stylebox_override("panel", _box_style(col, 8, border, 2))


func _show_question() -> void:
	var q := questions[index]
	_title.text = "Buku %d/%d   -   Soal %d/%d" % [book_number, QuestionBank.total_books, index + 1, questions.size()]
	_question.text = q["text"]
	_question.visible = not q["broken"]
	_broken_box.visible = q["broken"]
	if q["broken"]:
		var layers: Array = q["layers"]
		for i in _broken_layers.size():
			_broken_layers[i].text = layers[i]
			_broken_layers[i].position = Vector2(i * 4.0 - 4.0, i * 3.0 + 18.0)
	_input.text = ""
	_input.editable = true
	_input.grab_focus()
	_feedback.text = ""
	_locked = false
	_update_dots()
	var target: Control = _broken_box if q["broken"] else _question
	target.modulate.a = 0.0
	_tw().tween_property(target, "modulate:a", 1.0, 0.22)


func _process(delta: float) -> void:
	if _done:
		return
	_time_left -= delta
	var left := maxf(_time_left, 0.0)
	_timer_label.text = "%d" % ceili(left)
	_timer_bar.value = left
	var urgency := clampf(1.0 - left / 10.0, 0.0, 1.0)
	_bar_fill.bg_color = Color(0.4, 0.85, 0.5).lerp(Color(0.95, 0.25, 0.2), clampf(1.0 - left / time_limit, 0.0, 1.0) * 0.5 + urgency * 0.5)
	_timer_label.modulate = Color.WHITE.lerp(Color(1, 0.35, 0.3), urgency)
	if left < 8.0:
		_timer_label.scale = Vector2.ONE * (1.0 + 0.12 * absf(sin(_time_left * 5.0)))
		_timer_label.pivot_offset = _timer_label.size * 0.5
	if _time_left <= 0.0:
		_time_up()
		return
	# Soal rusak: lapisan teks bergetar tipis, judul berkedip merah (tanpa tulisan peringatan).
	if index >= questions.size() or not questions[index]["broken"]:
		return
	_jitter += delta
	if _jitter >= 0.09:
		_jitter = 0.0
		for i in _broken_layers.size():
			_broken_layers[i].position = Vector2(i * 4.0 - 4.0 + randf_range(-3, 3), i * 3.0 + 18.0 + randf_range(-2, 2))
		_title.modulate = Color(1, randf_range(0.3, 1.0), randf_range(0.3, 1.0))


# Jawaban langsung diproses dan lanjut ke soal berikutnya, tanpa tulisan benar/salah per soal.
func _submit(text: String) -> void:
	if _locked or _done:
		return
	_locked = true
	var q := questions[index]
	if q["broken"]:
		wrong += 1
	else:
		var t := text.strip_edges()
		if t.is_valid_int() and t.to_int() == int(q["answer"]):
			correct += 1
		else:
			wrong += 1
	_title.modulate = Color(CHALK, 0.85)
	index += 1
	if index >= questions.size():
		_end_quiz(false)
	else:
		_show_question()


func _time_up() -> void:
	if _done:
		return
	wrong += questions.size() - index   # soal yang belum dijawab dihitung salah
	index = questions.size()
	_end_quiz(true)


func _end_quiz(timed_out: bool) -> void:
	_done = true
	_locked = true
	_update_dots()
	_show_summary(timed_out)
	await get_tree().create_timer(2.2, true).timeout
	var tw := _tw().set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.25)
	tw.tween_property(_dim, "color:a", 0.0, 0.25)
	await tw.finished
	_finish()


# Satu-satunya tulisan hasil: muncul setelah semua soal selesai.
func _show_summary(timed_out: bool) -> void:
	_title.text = "Hasil Buku %d" % book_number
	_title.modulate = Color(CHALK, 0.85)
	_timer_label.visible = false
	_timer_bar.visible = false
	_dots_box.visible = false
	_broken_box.visible = false
	_question.visible = true
	_question.modulate.a = 1.0
	_question.text = "Waktu habis!" if timed_out else "Selesai"
	_input.visible = false
	if wrong == 0:
		_feedback.text = "Benar %d dari %d.  Bagus, Ibu Jennifer tenang." % [correct, questions.size()]
		_feedback.modulate = Color(0.55, 1, 0.6)
	else:
		_feedback.text = "Benar %d dari %d.  Ibu Jennifer makin kencang ngejarnya!" % [correct, questions.size()]
		_feedback.modulate = Color(1, 0.45, 0.4)
	_feedback.modulate.a = 0.0
	_tw().tween_property(_feedback, "modulate:a", 1.0, 0.4)


func _finish() -> void:
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit(correct, wrong)
	queue_free()
