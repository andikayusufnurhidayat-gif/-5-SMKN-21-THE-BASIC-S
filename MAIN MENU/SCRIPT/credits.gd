extends Control
## Credits: teks bergulir ke atas di latar gelap. Selesai (atau di-skip) -> kembali ke Main Menu.
## Klik / Esc / Enter / Space = lewati.

const Atmosphere := preload("res://MAIN MENU/SCRIPT/menu_atmosphere.gd")
const MENU_SCENE := "res://MAIN MENU/SCENE/MainMenu.tscn"

const BONE := Color(0.93, 0.91, 0.86)
const BLOOD_BRIGHT := Color(0.92, 0.18, 0.18)

@export var speed := 130.0   ## kecepatan gulir (piksel/detik)

# [jenis, teks]
# jenis: big, sub, section (judul bagian), role (jabatan), name, small (aset), gap
const LINES := [
	["big", "AFTER THE BELL"],
	["sub", "A School Adventure Game"],
	["gap", ""], ["gap", ""],

	["section", "Direction & Design"],
	["role", "Game Designer"],
	["name", "•  Andika"],
	["gap", ""], ["gap", ""],

	["section", "Programming"],
	["role", "Gameplay & System Programmer"],
	["name", "•  Syafira"], ["name", "•  Andika"],
	["gap", ""], ["gap", ""],

	["section", "Art & Visuals"],
	["role", "3D Character & Environment Artist"],
	["name", "•  Mayzura"], ["name", "•  Issabel"],
	["gap", ""],
	["role", "UI/UX Designer"],
	["name", "•  Mayzura"], ["name", "•  Issabel"],
	["gap", ""],
	["role", "Audio"],
	["name", "•  Syafira"],
	["gap", ""], ["gap", ""],

	["section", "Third-Party Assets"],
	["role", "3D Assets & Environment"],
	["small", "School Classrooms Asset Pack  –  styloo (itch.io), CC0"],
	["small", "\"Low-Poly Basketball Court 3D Model\"  –  Xiao Jing (itch.io), CC0"],
	["small", "\"Park Bench\"  –  Víctor Hernández (Sketchfab), CC BY 4.0"],
	["small", "\"Plant\"  –  Boxroom 3D (Sketchfab), CC BY 4.0"],
	["small", "\"Tree S1\"  –  Snowism (Sketchfab), CC BY 4.0"],
	["small", "\"Fence\"  –  kaasbroodje (Sketchfab), CC BY 4.0"],
	["small", "\"Fence from The Witcher\"  –  kisell03 (Sketchfab), CC BY 4.0"],
	["small", "Window Pack  –  Unknown"],
	["gap", ""],
	["role", "Audio & Music"],
	["small", "\"Horror Loop\"  –  TinyWorlds (OpenGameArt), CC0"],
	["small", "\"4 Music Box Tracks\" (Sad Tune, Happy Polka)"],
	["small", "Aureolus_Omicron (OpenGameArt), CC0"],
	["small", "\"Scary Piano Music\"  –  freesound_community (Pixabay)"],
	["small", "Main Menu Horror Piano Loop  –  Unknown"],
	["small", "Jennifer voice lines (mostly)"],
	["small", "Super Dialogue Audio Pack  –  Dillon Becker (itch.io)"],
	["gap", ""], ["gap", ""],

	["section", "Special Thanks"],
	["role", "Supervising Teacher"],
	["name", "Pak Maul"],
	["name", "Bu Annisa Apriliyanti"],
	["gap", ""],
	["name", "SMKN 21 JAKARTA"],
	["name", "Godot Engine Indonesia Community"],
]

var _scroller: VBoxContainer
var _leaving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var vp := get_viewport_rect().size

	var atm: Control = Atmosphere.new()
	atm.set("follow_mouse", false)
	add_child(atm)

	_scroller = VBoxContainer.new()
	_scroller.add_theme_constant_override("separation", 8)
	_scroller.custom_minimum_size = Vector2(vp.x * 0.7, 0)
	_scroller.position = Vector2(vp.x * 0.15, vp.y + 20.0)
	_scroller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroller)
	for entry in LINES:
		_add_line(entry[0], entry[1])

	# Tombol kembali (skip)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 0)
	Atmosphere.style_button(back, false, 22)
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 40.0
	back.offset_top = -80.0
	back.offset_right = 240.0
	back.offset_bottom = -34.0

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)


func _add_line(kind: String, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		"big":
			l.add_theme_font_size_override("font_size", 72)
			l.add_theme_color_override("font_color", BONE)
			l.add_theme_color_override("font_outline_color", Color(0.25, 0.0, 0.02))
			l.add_theme_constant_override("outline_size", 10)
		"sub":
			l.add_theme_font_size_override("font_size", 24)
			l.add_theme_color_override("font_color", Color(0.8, 0.36, 0.36))
		"head":
			l.add_theme_font_size_override("font_size", 20)
			l.add_theme_color_override("font_color", BLOOD_BRIGHT)
			l.text = text.to_upper()
		"section":
			l.add_theme_font_size_override("font_size", 30)
			l.add_theme_color_override("font_color", BLOOD_BRIGHT)
			l.text = text.to_upper()
		"role":
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_color", Color(0.8, 0.36, 0.36))
		"name":
			l.add_theme_font_size_override("font_size", 28)
			l.add_theme_color_override("font_color", BONE)
		"thanks":
			l.add_theme_font_size_override("font_size", 40)
			l.add_theme_color_override("font_color", BONE)
		"ghost":
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 0.6))
		"small":
			l.add_theme_font_size_override("font_size", 18)
			l.add_theme_color_override("font_color", Color(0.8, 0.78, 0.74, 0.75))
		"foot":
			l.add_theme_font_size_override("font_size", 18)
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
		_:
			l.custom_minimum_size = Vector2(0, 26)
	_scroller.add_child(l)


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
