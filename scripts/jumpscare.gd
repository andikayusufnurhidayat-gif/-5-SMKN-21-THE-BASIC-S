extends Node
## Animasi ditangkap Jennifer. Dibuat game_flow.gd: js.call("run", jennifer), lalu tunggu sinyal finished.
##
## Urutan: kamera dipotong ke depan wajah Jennifer yang menerkam (tangan terangkat, mulut menganga, mata melotot),
## kilatan putih, teriakan keras, kamera menerjang maju dua kali sambil bergoyang, vignette merah berdenyut,
## lalu potong ke hitam dengan tulisan kecil. Teriakan dibuat dari kode; kalau mau suara asli, taruh file di
## res://audio/jennifer_scream.ogg (atau .wav / .mp3) dan otomatis dipakai.

signal finished

const SCREAM_PATHS := ["res://audio/jennifer_scream.ogg", "res://audio/jennifer_scream.wav", "res://audio/jennifer_scream.mp3"]

var _cam: Camera3D
var _head := Vector3.ZERO
var _shake := 0.0
var _t := 0.0
var _audio: AudioStreamPlayer
var _flash: ColorRect
var _red: ColorRect
var _black: ColorRect
var _label: Label
var _layer: CanvasLayer


func run(jen: Node3D) -> void:
	if jen == null:
		jen = get_tree().get_first_node_in_group("teacher") as Node3D
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if jen == null or player == null:
		finished.emit()
		return
	player.set_physics_process(false)
	player.set_process(false)
	GameState.set_process_unhandled_input(false)

	var to_player := player.global_position - jen.global_position
	to_player.y = 0.0
	if to_player.length() < 0.05:
		to_player = Vector3(0, 0, 1)
	to_player = to_player.normalized()
	jen.call("jumpscare_pose", to_player)
	_head = jen.call("head_position")

	_build_overlay()
	_cam = Camera3D.new()
	get_tree().current_scene.add_child(_cam)
	_cam.fov = 60.0
	_cam.global_position = _head + to_player * 3.4 + Vector3(0, -0.25, 0)
	_cam.make_current()
	_audio = AudioStreamPlayer.new()
	_audio.stream = _scream_stream()
	_audio.volume_db = 3.0
	add_child(_audio)
	set_process(true)

	# potong! kilatan putih + teriakan + terkaman pertama
	_audio.play()
	_flash.color = Color(1, 1, 1, 1)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.3)
	create_tween().tween_property(_red, "color:a", 0.3, 0.5)
	_shake = 0.05
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_cam, "global_position", _head + to_player * 0.85 + Vector3(0, -0.12, 0), 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cam, "fov", 88.0, 0.28)
	await get_tree().create_timer(1.0).timeout

	# terkaman kedua, makin dekat dan makin liar
	_shake = 0.1
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_cam, "global_position", _head + to_player * 0.5 + Vector3(0, -0.1, 0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(_cam, "fov", 108.0, 0.55)
	await get_tree().create_timer(0.7).timeout

	# potong ke hitam
	_audio.stop()
	_shake = 0.0
	_black.color.a = 1.0
	_label.visible = true
	create_tween().tween_property(_label, "modulate:a", 1.0, 0.8)
	await get_tree().create_timer(2.2).timeout
	finished.emit()


func _process(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	_t += delta
	_cam.look_at(_head + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake, Vector3.UP)
	_cam.rotation.z = randf_range(-1.0, 1.0) * _shake * 1.5
	if _red != null and _black.color.a < 0.5:
		_red.color.a = clampf(0.28 + sin(_t * 18.0) * 0.1, 0.0, 1.0)


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 150
	add_child(_layer)

	# vignette gelap di pinggir layar
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512
	gt.height = 512
	var vignette := TextureRect.new()
	vignette.texture = gt
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(vignette)

	_red = ColorRect.new()
	_red.color = Color(0.6, 0.0, 0.0, 0.0)
	_red.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_red)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_flash)

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_black)

	_label = Label.new()
	_label.text = "TERTANGKAP\nIbu Jennifer menemukanmu."
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.modulate = Color(0.85, 0.1, 0.1, 0.0)
	_label.visible = false
	_layer.add_child(_label)


func _scream_stream() -> AudioStream:
	for path in SCREAM_PATHS:
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			if s != null:
				return s
	# teriakan sintetis: dentuman rendah + jeritan naik nada yang pecah
	var rate := 22050
	var dur := 1.7
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var p1 := 0.0
	var p2 := 0.0
	for i in count:
		var t := float(i) / rate
		var env := minf(1.0, t / 0.012) * clampf((dur - t) / 0.5, 0.0, 1.0) * (0.78 + 0.22 * sin(t * TAU * 9.0))
		var f := 520.0 + 430.0 * (1.0 - exp(-t * 3.0)) + 70.0 * sin(t * TAU * 7.0)
		p1 += TAU * f / rate
		p2 += TAU * f * 1.51 / rate
		var s := sin(p1) * 0.5 + sin(p1 * 2.0) * 0.3 + sin(p2) * 0.25 + rng.randf_range(-1.0, 1.0) * 0.35
		s = tanh(s * 2.2) * 0.85 * env
		s += sin(TAU * 55.0 * t) * exp(-t * 14.0) * 0.9
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
