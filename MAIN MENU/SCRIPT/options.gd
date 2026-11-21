extends Control
## Menu Options. Semua tampilan ada di options.tscn (bisa diedit di editor).
## Script ini cuma menghubungkan slider/tombol ke AudioManager. Pengaturan disimpan lewat
## AudioManager (user://settings.cfg). Isinya sengaja yang ringan-ringan supaya aman buat laptop spek rendah.

const MENU_SCENE := "res://MAIN MENU/SCENE/MainMenu.tscn"

@onready var _atm: Control = %Atmosphere
@onready var _scroll: ScrollContainer = %Scroll


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Ukuran daftar menyesuaikan layar
	var vp := get_viewport_rect().size
	_scroll.custom_minimum_size = Vector2(minf(820.0, vp.x - 200.0), clampf(vp.y - 250.0, 220.0, 520.0))

	_setup_slider(%MasterSlider, %MasterPct, AudioManager.volume * 100.0,
		func(v: float): AudioManager.set_volume(v / 100.0))
	_setup_slider(%MusicSlider, %MusicPct, AudioManager.music_volume * 100.0,
		func(v: float): AudioManager.set_music_volume(v / 100.0))
	_setup_slider(%SensSlider, %SensPct, AudioManager.mouse_sens * 100.0,
		func(v: float): AudioManager.mouse_sens = v / 100.0)

	_setup_cycle(%ModeBtn, 1 if AudioManager.fullscreen else 0,
		func(i: int): AudioManager.set_fullscreen(i == 1))
	_setup_cycle(%QualityBtn, AudioManager.quality,
		func(i: int): AudioManager.set_quality(i))
	_setup_cycle(%FpsBtn, AudioManager.fps_limit_index,
		func(i: int): AudioManager.set_fps_limit(i))
	_setup_cycle(%VsyncBtn, 1 if AudioManager.vsync else 0,
		func(i: int): AudioManager.set_vsync(i == 1))
	_setup_cycle(%ShowFpsBtn, 1 if AudioManager.show_fps else 0,
		func(i: int): AudioManager.set_show_fps(i == 1))
	_setup_cycle(%EffectsBtn, 1 if AudioManager.menu_effects else 0,
		_set_menu_effects)

	%BtnBack.pressed.connect(_on_back_pressed)
	%BtnReset.pressed.connect(_on_reset_pressed)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	%MasterSlider.grab_focus()


func _exit_tree() -> void:
	AudioManager.save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


# ------------------------------------------------------------------ hubungkan kontrol

func _setup_slider(s: HSlider, pct: Label, value: float, on_change: Callable) -> void:
	s.set_value_no_signal(value)
	pct.text = "%d%%" % int(value)
	s.value_changed.connect(_on_slider_changed.bind(pct, on_change))


func _on_slider_changed(v: float, pct: Label, on_change: Callable) -> void:
	pct.text = "%d%%" % int(v)
	on_change.call(v)


func _setup_cycle(b: Button, index: int, on_change: Callable) -> void:
	b.call("set_index", index)
	b.connect("changed", on_change)


func _set_menu_effects(i: int) -> void:
	AudioManager.menu_effects = (i == 1)
	_atm.set_effects(i == 1)


# ------------------------------------------------------------------ tombol

func _on_back_pressed() -> void:
	AudioManager.save_settings()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_reset_pressed() -> void:
	AudioManager.reset_settings()
	get_tree().reload_current_scene()
