extends Node
## Penghitung buku (notebook) + tampilan "Buku: x/7" di kiri atas layar.
## Pasang sebagai node biasa bernama "NotebookTracker" di scene lantai 1, lalu sambungkan script ini.
##
## Saat buku diambil (pickup_item.gd dengan item_id = notebook), muncul papan kuis matematika
## (think_pad.gd). Setelah 3 soal selesai, buku dihitung dan hilang dari dunia.

signal notebook_collected(collected: int, total: int)
signal quiz_answered(correct: bool)  ## buat nanti: Baldie bisa marah kalau jawaban salah
signal all_collected

@export var label_text := "Notebook"
@export var use_quiz := true  ## false = buku langsung dihitung tanpa kuis

var total := 7
var collected := 0

var _label: Label
var _quiz_open := false


func _ready() -> void:
	add_to_group("notebook_tracker")
	total = int(GameState.NOTEBOOK.get("count", 7))
	QuestionBank.total_books = total

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 14)
	layer.add_child(margin)

	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	margin.add_child(_label)

	_update_label()


## Dipanggil oleh pickup_item.gd saat sebuah buku dihadapi dan tombol interaksi ditekan.
func request_collect(pickup: Node) -> void:
	if _quiz_open:
		return
	if not use_quiz:
		_finish_collect(pickup)
		return
	_quiz_open = true
	var pad := ThinkPad.new()
	add_child(pad)
	pad.answered.connect(func(correct: bool) -> void: quiz_answered.emit(correct))
	pad.finished.connect(func(_correct_count: int) -> void: _finish_collect(pickup))
	pad.start(collected + 1)   # nomor buku yang sedang diambil (1..total)


func _finish_collect(pickup: Node) -> void:
	_quiz_open = false
	if is_instance_valid(pickup):
		pickup.queue_free()
	collected = mini(collected + 1, total)
	_update_label()
	notebook_collected.emit(collected, total)
	if collected >= total:
		all_collected.emit()
		GameState.notice.emit("All notebooks collected!")
	else:
		GameState.notice.emit("%s %d/%d" % [label_text, collected, total])


func _update_label() -> void:
	_label.text = "%s: %d/%d" % [label_text, collected, total]
