extends Button
## Tombol menu: kena mouse -> langsung "terpilih", dan saat terpilih muncul tanda panah "›" di depan teks.
## Style (warna, garis merah, dll.) diatur di MAIN MENU/THEME/menu_theme.tres.

@export var arrow := true

var _base := ""


func _ready() -> void:
	_base = text
	mouse_entered.connect(grab_focus)
	if arrow:
		focus_entered.connect(_on_focus_entered)
		focus_exited.connect(_on_focus_exited)


func _on_focus_entered() -> void:
	text = "›  " + _base


func _on_focus_exited() -> void:
	text = _base
