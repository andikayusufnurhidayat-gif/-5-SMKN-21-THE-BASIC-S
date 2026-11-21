class_name ThinkPad
extends CanvasLayer
## Papan kuis matematika yang muncul saat buku diambil: 3 soal, jawaban diketik lalu Enter.
## Game dijeda selama papan terbuka. Dibuat dan dikelola oleh notebook_tracker.gd.

signal answered(correct: bool)
signal finished(correct_count: int)

const QUESTION_COUNT := 3

var _level := 0
var _index := 0
var _correct_count := 0
var _answer := 0
var _busy := false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

var _title: Label
var _question: Label
var _input: LineEdit
var _feedback: Label
var _mark_boxes: Array[PanelContainer] = []
var _mark_labels: Array[Label] = []


## Panggil setelah node ini dimasukkan ke scene. level = tingkat kesulitan (0 = termudah).
func start(level: int) -> void:
	_level = level
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_build_ui()
	_next_question()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("2f9e44"), Color("1b5e28"), 6, 24))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	# Kolom kotak penanda benar/salah, satu per soal.
	var marks_col := VBoxContainer.new()
	marks_col.add_theme_constant_override("separation", 12)
	row.add_child(marks_col)
	for i in QUESTION_COUNT:
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(64, 64)
		box.add_theme_stylebox_override("panel", _box(Color("e9f5e1"), Color("1b5e28"), 3, 10))
		var mark := Label.new()
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.add_theme_font_size_override("font_size", 24)
		box.add_child(mark)
		marks_col.add_child(box)
		_mark_boxes.append(box)
		_mark_labels.append(mark)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(520, 0)
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color.WHITE)
	right.add_child(_title)

	var question_box := PanelContainer.new()
	question_box.add_theme_stylebox_override("panel", _box(Color.WHITE, Color("1b5e28"), 3, 10))
	right.add_child(question_box)
	_question = Label.new()
	_question.custom_minimum_size = Vector2(0, 110)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_question.add_theme_font_size_override("font_size", 44)
	_question.add_theme_color_override("font_color", Color.BLACK)
	question_box.add_child(_question)

	_input = LineEdit.new()
	_input.placeholder_text = "Ketik jawaban lalu tekan Enter"
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.add_theme_font_size_override("font_size", 30)
	_input.custom_minimum_size = Vector2(0, 56)
	_input.text_submitted.connect(_on_submitted)
	right.add_child(_input)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 22)
	_feedback.add_theme_color_override("font_color", Color.WHITE)
	right.add_child(_feedback)


func _next_question() -> void:
	_busy = false
	_title.text = "Soal %d dari %d" % [_index + 1, QUESTION_COUNT]
	_feedback.text = ""
	var q := _make_question(_level)
	_question.text = String(q["text"])
	_answer = int(q["answer"])
	_input.text = ""
	_input.editable = true
	_input.grab_focus()


func _on_submitted(text: String) -> void:
	if _busy:
		return
	var cleaned := text.strip_edges()
	if not cleaned.is_valid_int():
		_feedback.text = "Ketik angka dulu ya."
		return
	_busy = true
	_input.editable = false
	var correct := int(cleaned) == _answer
	if correct:
		_correct_count += 1
		_feedback.text = "Benar!"
	else:
		_feedback.text = "Salah. Jawabannya %d" % _answer
	_set_mark(_index, correct)
	answered.emit(correct)

	await get_tree().create_timer(1.1).timeout
	_index += 1
	if _index >= QUESTION_COUNT:
		_close()
	else:
		_next_question()


func _set_mark(index: int, correct: bool) -> void:
	_mark_labels[index].text = "OK" if correct else "X"
	_mark_labels[index].add_theme_color_override("font_color", Color.WHITE)
	var fill := Color("2f9e44") if correct else Color("e03131")
	_mark_boxes[index].add_theme_stylebox_override("panel", _box(fill, Color("1b5e28"), 3, 10))


func _close() -> void:
	Input.mouse_mode = _prev_mouse_mode
	get_tree().paused = false
	finished.emit(_correct_count)
	queue_free()


# Soal makin sulit seiring banyaknya buku yang sudah terkumpul.
func _make_question(level: int) -> Dictionary:
	var a := 0
	var b := 0
	if level <= 0:
		a = randi_range(1, 9)
		b = randi_range(1, 9)
		return {"text": "%d + %d = ?" % [a, b], "answer": a + b}
	if level == 1:
		if randi() % 2 == 0:
			a = randi_range(10, 40)
			b = randi_range(10, 40)
			return {"text": "%d + %d = ?" % [a, b], "answer": a + b}
		a = randi_range(20, 60)
		b = randi_range(5, a - 1)
		return {"text": "%d - %d = ?" % [a, b], "answer": a - b}
	if level == 2:
		a = randi_range(2, 9)
		b = randi_range(2, 9)
		return {"text": "%d x %d = ?" % [a, b], "answer": a * b}
	a = randi_range(2, 12)
	b = randi_range(2, 12)
	var c := randi_range(1, 20)
	return {"text": "%d x %d + %d = ?" % [a, b, c], "answer": a * b + c}


func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	return s
