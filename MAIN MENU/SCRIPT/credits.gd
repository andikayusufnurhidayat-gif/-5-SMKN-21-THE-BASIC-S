extends Control
## Credits: teks bergulir ke atas di latar gelap. Selesai (atau di-skip) -> kembali ke Main Menu.
## Klik / Esc / Enter / Space = lewati.
##
## Semua teks ada di node "Scroller" (di credits.tscn) sebagai Label, jadi nama, judul, dan ukurannya
## bisa diedit langsung di editor. Tambah baris baru = duplikat salah satu Label (Ctrl+D) lalu ubah Text-nya.
## Di editor teks diletakkan di atas layar supaya kelihatan; saat game jalan, script memindahkannya
## ke bawah layar lalu menggulirnya ke atas.

const MENU_SCENE := "res://MAIN MENU/SCENE/MainMenu.tscn"

@export var speed := 65.0   ## kecepatan gulir (piksel/detik)

@onready var _scroller: VBoxContainer = %Scroller
@onready var _back: Button = %BtnBack

var _leaving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vp := get_viewport_rect().size

	_scroller.custom_minimum_size = Vector2(vp.x * 0.7, 0)
	_scroller.size = Vector2(vp.x * 0.7, 0)
	_scroller.position = Vector2(vp.x * 0.15, vp.y + 20.0)

	_back.pressed.connect(_on_back_pressed)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)


func _process(delta: float) -> void:
	if _leaving:
		return
	_scroller.position.y -= speed * delta
	# Semua teks sudah lewat di atas layar -> selesai
	if _scroller.position.y + _scroller.get_combined_minimum_size().y < -40.0:
		_go_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var skip := false
	if event is InputEventMouseButton and event.pressed:
		skip = true
	elif event is InputEventKey and event.pressed and not event.echo:
		skip = event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
	if skip:
		_go_menu()


func _on_back_pressed() -> void:
	_go_menu()


func _go_menu() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	get_tree().change_scene_to_file(MENU_SCENE)
