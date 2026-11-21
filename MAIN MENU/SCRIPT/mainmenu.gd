extends Control
## Main menu. Semua tampilan (judul, tombol, jendela bulan, panel How To Play) sekarang berupa node
## di MainMenu.tscn, jadi bisa dilihat & diedit langsung di panel Scene / viewport / Inspector.
##
## Mau ganti judul game?  Klik node "Title" di panel Scene, isi properti "Text" di Inspector.
## (Kalau Text kosong, judul disembunyikan.) Subtitle dan Footer juga begitu.
##
## Catatan: di editor semua node terlihat (termasuk panel How To Play yang menutupi menu).
## Klik ikon mata di sebelah node "HowToPlay" kalau mau menyembunyikannya sementara saat mengedit.
## Saat game jalan, panel How To Play otomatis tersembunyi sampai tombolnya ditekan.

const GAME_SCENE := "res://lantai 1.tscn"
const OPTIONS_SCENE := "res://MAIN MENU/SCENE/options.tscn"
const CREDITS_SCENE := "res://MAIN MENU/SCENE/credits.tscn"

@onready var _title: Label = %Title
@onready var _line: ColorRect = %Line
@onready var _subtitle: Label = %Subtitle
@onready var _how_to_play: Control = %HowToPlay
@onready var _beam: Polygon2D = %Beam
@onready var _win_glow: TextureRect = %WinGlow
@onready var _win_frame: ColorRect = %Frame
@onready var _win_panes: Array[ColorRect] = []

var _buttons: Array[Button] = []
var _menu_items: Array[Control] = []
var _flicker := 0.0
var _t := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for i in 6:
		_win_panes.append(get_node("WindowDecor/Pane%d" % (i + 1)) as ColorRect)

	for b in [%BtnPlay, %BtnHowToPlay, %BtnOptions, %BtnCredit, %BtnQuit]:
		_buttons.append(b as Button)
	%BtnPlay.pressed.connect(_on_start_button_pressed)
	%BtnHowToPlay.pressed.connect(_on_how_to_play_button_pressed)
	%BtnOptions.pressed.connect(_on_options_pressed)
	%BtnCredit.pressed.connect(_on_credit_button_pressed)
	%BtnQuit.pressed.connect(_on_quit_button_pressed)

	_how_to_play.visible = false
	_how_to_play.connect("closed", _on_back_button_pressed)

	# Judul / subtitle kosong = disembunyikan
	_title.visible = _title.text != ""
	_subtitle.visible = _subtitle.text != ""

	resized.connect(_layout_window)
	_layout_window()

	# Muncul perlahan: layar fade-in, lalu item menu masuk satu per satu dari kiri
	_menu_items.append(_title)
	_menu_items.append(_line)
	_menu_items.append(_subtitle)
	for b in _buttons:
		_menu_items.append(b)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.9)
	for i in _menu_items.size():
		var it := _menu_items[i]
		it.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.25 + 0.09 * i)
		tw.tween_property(it, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

	_buttons[0].grab_focus()


func _process(delta: float) -> void:
	_t += delta
	_win_glow.modulate.a = 0.75 + 0.25 * sin(_t * 0.9)
	# Judul (kalau ada) berkedip tipis seperti lampu rusak
	if _title.visible:
		_flicker -= delta
		if _flicker <= 0.0:
			_flicker = randf_range(2.0, 6.0)
			var tw := create_tween()
			for i in randi_range(2, 4):
				tw.tween_property(_title, "modulate:a", randf_range(0.25, 0.6), 0.04)
				tw.tween_property(_title, "modulate:a", 1.0, 0.06)


# ------------------------------------------------------------------ jendela bulan
# Ukuran & posisi jendela mengikuti ukuran layar saat game jalan.
# Di editor posisinya bisa kamu geser manual, tapi saat game jalan akan dihitung ulang di sini.

func _layout_window() -> void:
	var w := clampf(size.x * 0.24, 190.0, 360.0)
	var h := w * 1.5
	var x := size.x - w - size.x * 0.1
	var y := (size.y - h) * 0.4
	var gap := 10.0

	_win_frame.position = Vector2(x - gap, y - gap)
	_win_frame.size = Vector2(w + gap * 2.0, h + gap * 2.0)
	var pw := (w - gap) * 0.5
	var ph := (h - gap * 2.0) / 3.0
	for i in _win_panes.size():
		var col := i % 2
		var row := i >> 1
		_win_panes[i].position = Vector2(x + col * (pw + gap), y + row * (ph + gap))
		_win_panes[i].size = Vector2(pw, ph)

	_win_glow.size = Vector2(w * 3.2, h * 2.3)
	_win_glow.position = Vector2(x + w * 0.5, y + h * 0.5) - _win_glow.size * 0.5

	# berkas cahaya bulan jatuh ke lantai (miring ke kiri bawah)
	_beam.polygon = PackedVector2Array([
		Vector2(x, y + h), Vector2(x + w, y + h),
		Vector2(x + w - size.x * 0.5, size.y), Vector2(x - size.x * 0.5, size.y),
	])
	var top := Color(0.6, 0.7, 1.0, 0.12)
	var bottom := Color(0.6, 0.7, 1.0, 0.0)
	_beam.vertex_colors = PackedColorArray([top, top, bottom, bottom])


# ------------------------------------------------------------------ tombol

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_credit_button_pressed() -> void:
	get_tree().change_scene_to_file(CREDITS_SCENE)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_how_to_play_button_pressed() -> void:
	_how_to_play.call("open")


func _on_back_button_pressed() -> void:
	_buttons[1].grab_focus()
