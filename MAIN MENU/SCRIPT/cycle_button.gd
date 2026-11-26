extends Button
## Tombol pilihan: tiap diklik pindah ke pilihan berikutnya (berputar). Isi pilihan diatur di Inspector (choices).

signal changed(index: int)

@export var choices: PackedStringArray = []
@export var index := 0


func _ready() -> void:
	_refresh()
	pressed.connect(_on_pressed)
	mouse_entered.connect(grab_focus)


## Ganti pilihan lewat kode tanpa memicu sinyal changed.
func set_index(i: int) -> void:
	if choices.is_empty():
		return
	index = clampi(i, 0, choices.size() - 1)
	_refresh()


func _on_pressed() -> void:
	if choices.is_empty():
		return
	index = (index + 1) % choices.size()
	_refresh()
	changed.emit(index)


func _refresh() -> void:
	if not choices.is_empty():
		text = "‹  %s  ›" % choices[clampi(index, 0, choices.size() - 1)]
