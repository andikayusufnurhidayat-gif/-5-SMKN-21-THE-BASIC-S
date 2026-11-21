extends Node
## Autoload (nama: AudioManager). Mengurus:
##  - lagu menu "Wednesday the 9th" (HANYA diputar di scene menu; saat gameplay musiknya diurus music_director.gd)
##  - pengaturan dari menu Options, disimpan otomatis ke user://settings.cfg:
##    volume master & musik, sensitivitas mouse, layar penuh, VSync, batas FPS, kualitas grafis, tampilan FPS, efek menu.
## Semua pengaturan ini ringan (tidak menambah beban ke laptop).

const MENU_SCENES := ["MainMenu.tscn", "options.tscn", "credits.tscn"]
const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_SCALES := [0.67, 0.85, 1.0]   # Rendah / Sedang / Tinggi (skala render 3D)
const FPS_LIMITS := [30, 60, 0]             # 0 = tanpa batas

var volume := 1.0            # master (0..1)
var music_volume := 1.0      # musik (0..1)
var mouse_sens := 1.0        # pengali sensitivitas mouse (1.0 = bawaan)
var fullscreen := false
var vsync := true
var fps_limit_index := 2
var quality := 2
var show_fps := false
var menu_effects := true     # kabut & debu di menu

var music_player: AudioStreamPlayer

var _fps_label: Label
var _fps_t := 0.0


func _ready() -> void:
	_setup_music_bus()
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	music_player.stream = preload("res://audio/WednesdayThe9th_loop.wav")
	_build_fps_label()

	var has_file := load_settings()
	set_volume(volume)
	set_music_volume(music_volume)
	if has_file:
		apply_display()   # tanpa file = pakai bawaan project, nggak diutak-atik


func _setup_music_bus() -> void:
	if AudioServer.get_bus_index("Music") != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Music")
	AudioServer.set_bus_send(i, "Master")


func _build_fps_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.visible = false
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps_label.add_theme_constant_override("outline_size", 5)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fps_label)
	_fps_label.position = Vector2(12, 8)


# ------------------------------------------------------------------ setter (dipanggil menu Options)

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_set_bus("Master", volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus("Music", music_volume)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func set_vsync(on: bool) -> void:
	vsync = on
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)


func set_fps_limit(index: int) -> void:
	fps_limit_index = clampi(index, 0, FPS_LIMITS.size() - 1)
	Engine.max_fps = FPS_LIMITS[fps_limit_index]


func set_quality(index: int) -> void:
	quality = clampi(index, 0, QUALITY_SCALES.size() - 1)
	get_tree().root.scaling_3d_scale = QUALITY_SCALES[quality]


func set_show_fps(on: bool) -> void:
	show_fps = on
	_fps_label.visible = on


func apply_display() -> void:
	set_fullscreen(fullscreen)
	set_vsync(vsync)
	set_fps_limit(fps_limit_index)
	set_quality(quality)
	set_show_fps(show_fps)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.0)


# ------------------------------------------------------------------ simpan / muat

func load_settings() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return false
	volume = cfg.get_value("audio", "master", volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	mouse_sens = cfg.get_value("control", "mouse_sens", mouse_sens)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	vsync = cfg.get_value("display", "vsync", vsync)
	fps_limit_index = cfg.get_value("display", "fps_limit", fps_limit_index)
	quality = cfg.get_value("display", "quality", quality)
	show_fps = cfg.get_value("display", "show_fps", show_fps)
	menu_effects = cfg.get_value("display", "menu_effects", menu_effects)
	return true


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("control", "mouse_sens", mouse_sens)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "fps_limit", fps_limit_index)
	cfg.set_value("display", "quality", quality)
	cfg.set_value("display", "show_fps", show_fps)
	cfg.set_value("display", "menu_effects", menu_effects)
	cfg.save(SETTINGS_PATH)


func reset_settings() -> void:
	volume = 1.0
	music_volume = 1.0
	mouse_sens = 1.0
	fullscreen = false
	vsync = true
	fps_limit_index = 2
	quality = 2
	show_fps = false
	menu_effects = true
	set_volume(volume)
	set_music_volume(music_volume)
	apply_display()
	save_settings()


# ------------------------------------------------------------------ musik menu & FPS

func _in_menu() -> bool:
	var scene := get_tree().current_scene
	return scene != null and MENU_SCENES.has(scene.scene_file_path.get_file())


func _process(delta: float) -> void:
	if _in_menu():
		if not music_player.playing:
			music_player.play()
	elif music_player.playing:
		music_player.stop()

	if show_fps:
		_fps_t -= delta
		if _fps_t <= 0.0:
			_fps_t = 0.5
			_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
