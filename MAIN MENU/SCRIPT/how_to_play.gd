extends Control
## Panel "Cara Bermain": 3 tab (Tujuan, Kontrol, Item & Tips). Semua node ada di how_to_play.tscn,
## jadi teks, tombol, dan tampilannya bisa diedit langsung di editor.
## Pakai: panel.open() untuk menampilkan, sinyal closed dikirim waktu ditutup (tombol Back / Esc).
##
## Teks Tujuan & Item ada di node GoalText / ItemText (properti Text di Inspector, format BBCode).
## Daftar tombol ada di node ControlsGrid.

signal closed

const Atmosphere := preload("res://MAIN MENU/SCRIPT/menu_atmosphere.gd")
const BLOOD_BRIGHT := Color(0.92, 0.18, 0.18)

@onready var _tabs: Array = [%TabGoal, %TabControls, %TabItems]
@onready var _pages: Array = [%PageGoal, %PageControls, %PageItems]
@onready var _back: Button = %Back


func _ready() -> void:
	# Ukuran halaman menyesuaikan layar
	var vp := get_viewport_rect().size
	var page_size := Vector2(minf(940.0, vp.x - 120.0), clampf(vp.y - 280.0, 240.0, 470.0))
	for p in _pages:
		p.custom_minimum_size = page_size

	for i in _tabs.size():
		_tabs[i].pressed.connect(_select_tab.bind(i))
	_back.pressed.connect(close)
	_select_tab(0)
	visible = false   # di editor tetap kelihatan; saat game jalan tersembunyi sampai open() dipanggil


func open() -> void:
	visible = true
	_select_tab(0)
	_back.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _select_tab(index: int) -> void:
	for i in _tabs.size():
		var on := i == index
		_pages[i].visible = on
		if on:
			_tabs[i].add_theme_stylebox_override("normal", Atmosphere.box(Color(0.38, 0.04, 0.07, 0.9), BLOOD_BRIGHT, 6))
		else:
			_tabs[i].remove_theme_stylebox_override("normal")
