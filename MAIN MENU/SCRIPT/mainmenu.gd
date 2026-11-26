extends Control
## Main menu (scene: MainMenu.tscn). Tampilan diedit langsung di scene.
## Judul game: isi properti Text pada node "Title" di Inspector (kosong = disembunyikan).
## Warna & gaya tombol ada di MAIN MENU/THEME/menu_theme.tres.

const GAME_SCENE := "res://scenes/lantai 1.tscn"
const OPTIONS_SCENE := "res://MAIN MENU/SCENE/options.tscn"
const CREDITS_SCENE := "res://MAIN MENU/SCENE/credits.tscn"

var scene_tree: SceneTree

@onready var how_to_play_panel: Control = $HowToPlay
@onready var _title: Label = %Title
@onready var _moon_glow: Control = %MoonGlow
@onready var _buttons: Array = %Buttons.get_children()

var _flicker := 0.0
var _t := 0.0

# --- loading screen (muncul langsung saat PLAY ditekan, supaya kelihatan tombolnya sudah kepencet walau laptop lagi berat)
const MIN_LOADING_SECS := 0.7          # minimal tampil segini lama, biar nggak cuma kedip kalau loading-nya cepat
const TIPS := [
	"Collect all 7 notebooks, then find the Gate Key.",
	"Left-click picks up and opens. Right-click uses an item.",
	"Desks and cabinets can hide you from Ms. Jennifer.",
]
var _loading := false
var _overlay: Control
var _bar: ProgressBar
var _load_label: Label
var _tip_label: Label
var _load_t := 0.0
var _preparing := false     # true = file sudah dimuat, tinggal menyiapkan scene (layar bisa terlihat diam beberapa detik)


func _ready() -> void:
	scene_tree = get_tree()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.visible = _title.text.strip_edges() != ""

	# Muncul perlahan: layar fade-in, lalu item menu masuk satu per satu
	var items: Array = [_title, %Line, %Subtitle]
	for b in _buttons:
		items.append(b)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.9)
	for i in items.size():
		items[i].modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.25 + 0.09 * i)
		tw.tween_property(items[i], "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

	_buttons[0].grab_focus()


func _process(delta: float) -> void:
	_t += delta
	if _loading and _load_label != null:
		_load_t += delta
		if not _preparing:
			_load_label.text = "LOADING" + ".".repeat(int(_load_t * 3.0) % 4)
	_moon_glow.modulate.a = 0.75 + 0.25 * sin(_t * 0.9)   # cahaya bulan berdenyut pelan
	# Judul (kalau ada) berkedip tipis seperti lampu rusak
	if _title.visible:
		_flicker -= delta
		if _flicker <= 0.0:
			_flicker = randf_range(2.0, 6.0)
			var tw := create_tween()
			for i in randi_range(2, 4):
				tw.tween_property(_title, "modulate:a", randf_range(0.25, 0.6), 0.04)
				tw.tween_property(_title, "modulate:a", 1.0, 0.06)


# ------------------------------------------------------------------ tombol (disambungkan di scene)

func _on_options_pressed() -> void:
	scene_tree.change_scene_to_file(OPTIONS_SCENE)


func _on_start_button_pressed() -> void:
	if _loading:
		return
	_loading = true
	_show_loading()
	# 2 frame supaya layar loading sempat tampil dulu sebelum pekerjaan berat dimulai
	await get_tree().process_frame
	await get_tree().process_frame
	if ResourceLoader.load_threaded_request(GAME_SCENE) != OK:
		scene_tree.change_scene_to_file(GAME_SCENE)
		return
	_load_game()


# Memuat scene game di thread terpisah sambil memperbarui bar progres, lalu pindah scene.
func _load_game() -> void:
	var prog: Array = []
	while true:
		var st := ResourceLoader.load_threaded_get_status(GAME_SCENE, prog)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var target := 90.0
			if prog.size() > 0:
				target = float(prog[0]) * 90.0     # sisakan 10% untuk menyiapkan scene
			_bar.value = lerpf(_bar.value, target, 0.2)
			await get_tree().process_frame
			continue
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			break
		scene_tree.change_scene_to_file(GAME_SCENE)     # gagal dimuat di thread: pakai cara biasa
		return
	var packed := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	while _load_t < MIN_LOADING_SECS:
		await get_tree().process_frame
	# Tahap berikutnya (menyusun scene + membuat collision peta) berjalan di satu langkah dan membuat layar tampak diam beberapa detik.
	# Beri tahu pemain dulu, dan pastikan teks ini sempat tampil sebelum proses berat dimulai.
	_preparing = true
	_load_label.text = "PREPARING THE SCHOOL"
	_tip_label.text = "Almost there. The screen may pause for a few seconds, please wait..."
	_bar.value = 95.0
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	scene_tree.change_scene_to_packed(packed)


func _show_loading() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP     # klik apa pun di bawahnya diblokir
	_overlay.z_index = 100
	_overlay.modulate.a = 0.0
	add_child(_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.0, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var game_name := Label.new()
	game_name.text = "AFTER THE BELL"
	game_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_name.add_theme_font_size_override("font_size", 30)
	game_name.add_theme_color_override("font_color", Color(0.55, 0.5, 0.48))
	box.add_child(game_name)

	_load_label = Label.new()
	_load_label.text = "LOADING"
	_load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label.custom_minimum_size = Vector2(900, 0)     # lebar tetap supaya titik-titiknya tidak menggeser teks
	_load_label.add_theme_font_size_override("font_size", 50)
	_load_label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.86))
	_load_label.add_theme_color_override("font_outline_color", Color(0.25, 0.0, 0.02))
	_load_label.add_theme_constant_override("outline_size", 6)
	box.add_child(_load_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.1, 0.12)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.14, 0.04, 0.05)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)

	var tip := Label.new()
	_tip_label = tip
	tip.text = str(TIPS[randi() % TIPS.size()])
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 20)
	tip.add_theme_color_override("font_color", Color(0.8, 0.36, 0.36))
	box.add_child(tip)

	create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.15)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _on_credit_button_pressed() -> void:
	scene_tree.change_scene_to_file(CREDITS_SCENE)


func _on_quit_button_pressed() -> void:
	scene_tree.quit()


func _on_how_to_play_button_pressed() -> void:
	how_to_play_panel.call("open")


func _on_back_button_pressed() -> void:
	_buttons[1].grab_focus()
