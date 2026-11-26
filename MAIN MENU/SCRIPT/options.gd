extends Control
## Menu Options (scene: options.tscn). Tampilan diedit di scene; script ini cuma menghubungkan ke AudioManager.
## Semua pengaturan disimpan otomatis ke user://settings.cfg. Isinya ringan, aman buat laptop spek rendah.

const CycleButton := preload("res://MAIN MENU/SCRIPT/cycle_button.gd")
const MENU_SCENE := "res://MAIN MENU/SCENE/MainMenu.tscn"

## Dipakai saat options dibuka dari pause menu: Back menutup panel ini, tidak pindah ke main menu.
signal closed(reopen: bool)
var embedded: bool = false

@onready var _atm: Control = $Atmosphere

@onready var _fullscreen: CycleButton = %FullscreenCycle
@onready var _quality: CycleButton = %QualityCycle
@onready var _fps_limit: CycleButton = %FpsLimitCycle
@onready var _vsync: CycleButton = %VsyncCycle
@onready var _show_fps: CycleButton = %ShowFpsCycle
@onready var _effects: CycleButton = %EffectsCycle
@onready var _sub_on: CycleButton = %SubOnCycle
@onready var _sub_lang: CycleButton = %SubLangCycle


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_setup_slider(%MasterSlider, %MasterPct, AudioManager.volume * 100.0,
		func(v: float): AudioManager.set_volume(v / 100.0))
	_setup_slider(%MusicSlider, %MusicPct, AudioManager.music_volume * 100.0,
		func(v: float): AudioManager.set_music_volume(v / 100.0))
	_setup_slider(%SensSlider, %SensPct, AudioManager.mouse_sens * 100.0,
		func(v: float): AudioManager.mouse_sens = v / 100.0)

	_fullscreen.set_index(1 if AudioManager.fullscreen else 0)
	_fullscreen.changed.connect(func(i: int): AudioManager.set_fullscreen(i == 1))
	_quality.set_index(AudioManager.quality)
	_quality.changed.connect(func(i: int): AudioManager.set_quality(i))
	_fps_limit.set_index(AudioManager.fps_limit_index)
	_fps_limit.changed.connect(func(i: int): AudioManager.set_fps_limit(i))
	_vsync.set_index(1 if AudioManager.vsync else 0)
	_vsync.changed.connect(func(i: int): AudioManager.set_vsync(i == 1))
	_show_fps.set_index(1 if AudioManager.show_fps else 0)
	_show_fps.changed.connect(func(i: int): AudioManager.set_show_fps(i == 1))
	_effects.set_index(1 if AudioManager.menu_effects else 0)
	_effects.changed.connect(_on_effects_changed)
	_sub_on.set_index(1 if AudioManager.subtitles_on else 0)
	_sub_on.changed.connect(func(i: int): AudioManager.subtitles_on = (i == 1))
	_sub_lang.set_index(AudioManager.subtitle_lang)
	_sub_lang.changed.connect(func(i: int): AudioManager.subtitle_lang = i)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	%MasterSlider.grab_focus()


func _exit_tree() -> void:
	AudioManager.save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _setup_slider(s: HSlider, pct: Label, value: float, on_change: Callable) -> void:
	s.value_changed.connect(_on_slider_changed.bind(pct, on_change))
	s.value = value
	pct.text = "%d%%" % int(value)


func _on_slider_changed(v: float, pct: Label, on_change: Callable) -> void:
	pct.text = "%d%%" % int(v)
	on_change.call(v)


func _on_effects_changed(i: int) -> void:
	AudioManager.menu_effects = (i == 1)
	_atm.set_effects(i == 1)


# ------------------------------------------------------------------ tombol (disambungkan di scene)

func close(reopen: bool = false) -> void:
	AudioManager.save_settings()
	closed.emit(reopen)
	queue_free()


func _on_back_pressed() -> void:
	if embedded:
		close()
		return
	AudioManager.save_settings()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_reset_pressed() -> void:
	AudioManager.reset_settings()
	if embedded:
		close(true)  # buka ulang supaya semua slider/tombol menampilkan nilai default
		return
	get_tree().reload_current_scene()
