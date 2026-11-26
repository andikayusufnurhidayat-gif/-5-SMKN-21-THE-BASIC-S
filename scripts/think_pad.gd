class_name ThinkPad
extends CanvasLayer
## Papan kuis matematika yang muncul saat buku diambil: 3 soal penjumlahan 1-10, jawaban diketik lalu Enter.
## Di sekitar 4 dari 7 buku, soal 3 adalah soal RUSAK (tulisan dicoret-coret bertumpuk, pasti salah).
## Game dijeda selama papan terbuka. Dibuat dan dikelola oleh notebook_tracker.gd.

signal answered(correct: bool)
signal finished(correct_count: int)

const QUESTION_COUNT := 3

var _book := 1
var _questions: Array[Dictionary] = []
var _index := 0
var _correct_count := 0
var _answer := 0
var _busy := false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

var _title: Label
var _question: Label
var _broken_box: Control
var _broken_layers: Array[Label] = []
var _jitter := 0.0
var _input: LineEdit
var _feedback: Label
var _mark_boxes: Array[PanelContainer] = []
var _mark_labels: Array[Label] = []


## Panggil setelah node ini dimasukkan ke scene. book_number = buku ke-berapa (1..total) yang sedang diambil.
func start(book_number: int) -> void:
	_book = book_number
	_questions = QuestionBank.make_quiz(_book)
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
	# Soal rusak: 3 lapis teks yang tercetak bertumpuk, dipotong di tepi kotak soal.
	_broken_box = Control.new()
	_broken_box.custom_minimum_size = Vector2(0, 110)
	_broken_box.clip_contents = true
	_broken_box.visible = false
	question_box.add_child(_broken_box)
	for i in 3:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color.BLACK)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.modulate = Color(1, 1, 1, 0.85)
		_broken_box.add_child(l)
		_broken_layers.append(l)

	_input = LineEdit.new()
	_input.placeholder_text = "Type your answer then press Enter"
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
	_title.text = "Question %d of %d" % [_index + 1, QUESTION_COUNT]
	_title.add_theme_color_override("font_color", Color.WHITE)
	_feedback.text = ""
	var q := _questions[_index]
	var is_broken: bool = q["broken"]
	_question.visible = not is_broken
	_broken_box.visible = is_broken
	if is_broken:
		var layers: Array = q["layers"]
		for i in _broken_layers.size():
			_broken_layers[i].text = String(layers[i])
			_broken_layers[i].position = Vector2(6.0 + i * 4.0, 10.0 + i * 3.0)
	else:
		_question.text = String(q["text"])
	_answer = int(q["answer"])
	_input.text = ""
	_input.editable = true
	_input.grab_focus()


func _on_submitted(text: String) -> void:
	if _busy:
		return
	var cleaned := text.strip_edges()
	var is_broken: bool = _questions[_index]["broken"]
	if not is_broken and not cleaned.is_valid_int():
		_feedback.text = "Type a number first."
		return
	_busy = true
	_input.editable = false
	var correct := (not is_broken) and int(cleaned) == _answer
	_title.add_theme_color_override("font_color", Color.WHITE)
	if correct:
		_correct_count += 1
		_feedback.text = "Correct!"
	elif is_broken:
		_feedback.text = "Salah."   # soal rusak nggak punya jawaban benar
	else:
		_feedback.text = "Wrong. The answer is %d" % _answer
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


# Soal rusak: lapisan teks bergetar tipis dan judul berkedip merah (tanpa tulisan peringatan).
func _process(delta: float) -> void:
	if _busy or _index >= _questions.size() or not _questions[_index]["broken"]:
		return
	_jitter += delta
	if _jitter < 0.09:
		return
	_jitter = 0.0
	for i in _broken_layers.size():
		_broken_layers[i].position = Vector2(6.0 + i * 4.0 + randf_range(-3, 3), 10.0 + i * 3.0 + randf_range(-2, 2))
	_title.add_theme_color_override("font_color", Color(1, randf_range(0.3, 1.0), randf_range(0.3, 1.0)))


func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	return s
