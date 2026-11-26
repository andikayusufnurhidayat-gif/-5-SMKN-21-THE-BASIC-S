extends Control
## Panel "Cara Bermain" (scene: HowToPlay.tscn). Teks & tampilan diedit langsung di scene.
## Panggil open() untuk menampilkan; sinyal closed dikirim waktu ditutup (tombol Back / Esc).

signal closed

@onready var _tabs := [%TabGoal, %TabControls, %TabItems]
@onready var _pages := [%GoalPage, %ControlsPage, %ItemsPage]
@onready var _back: Button = %BackButton


func _ready() -> void:
	for i in _tabs.size():
		_tabs[i].pressed.connect(_select_tab.bind(i))
	_back.pressed.connect(close)


func open() -> void:
	visible = true
	_tabs[0].button_pressed = true
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
	for i in _pages.size():
		_pages[i].visible = (i == index)
