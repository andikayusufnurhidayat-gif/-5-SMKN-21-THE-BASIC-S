extends Button
## Tombol bergaya horor. Gayanya (warna, garis merah) diatur di menu_theme.tres.
## Script ini cuma menambah: tanda panah "›" saat fokus, fokus otomatis saat mouse lewat,
## dan mode "cycle" (tombol pilihan yang berganti tiap diklik, dipakai di Options).

signal changed(index: int)

## Tampilkan tanda panah "›" di depan teks saat tombol difokus.
@export var arrow := true
## Kalau diisi, tombol jadi tombol pilihan: tiap klik pindah ke pilihan berikutnya.
@export var choices: PackedStringArray = PackedStringArray()

var index := 0
var _base := ""


func _ready() -> void:
	_base = text
	if not choices.is_empty():
		_refresh()
	if arrow:
		focus_entered.connect(func(): text = "›  " + _base)
		focus_exited.connect(func(): text = _base)
	mouse_entered.connect(grab_focus)


func _pressed() -> void:
	if choices.is_empty():
		return
	index = (index + 1) % choices.size()
	_refresh()
	changed.emit(index)


## Set pilihan aktif tanpa memicu sinyal changed.
func set_index(i: int) -> void:
	if choices.is_empty():
		return
	index = clampi(i, 0, choices.size() - 1)
	_refresh()


func _refresh() -> void:
	text = "‹  %s  ›" % choices[index]
