extends Node
## CUTSCENE ENDING 1 dari 2: TERTANGKAP Ms. Jennifer ("DETENTION FOREVER").
## Versi 2: berlangsung di RUANG GURU asli di peta (lantai 1.tscn), bukan kelas buatan.
## Dipanggil game_flow.gd -> on_caught(), SETELAH animasi jumpscare selesai:
##     var cs := Node.new(); cs.set_script(CAUGHT_CUTSCENE); add_child(cs); cs.call("run"); await cs.finished
##
## Cerita (+/- 45 detik, SELURUHNYA sudut pandang orang pertama = mata player, setinggi kamera saat bermain):
##   0. Layar hitam: "Bel pulang sudah berbunyi berjam-jam yang lalu." + bunyi bel jauh.
##   1. Player berdiri di ruang guru (tinggi mata sama seperti saat main). Jennifer menjulang di depannya:
##      "Mau pulang secepat itu?" ... "Time over." ... "Pelajaran belum selesai."
##   2. Potong ke player DUDUK DI KURSI di meja ruang guru, tetap sudut pandang mata sendiri: menunduk melihat kertas REMEDIAL,
##      tangan kanan sendiri mengerjakan SOAL MATEMATIKA (ada soal RUSAK ala gameplay + soal-soal susah) baris demi baris.
##      Meja penuh tumpukan dan lembaran kertas soal. Jennifer duduk di seberang meja, menghadap player.
##   3. Tanpa potong, player pelan-pelan MENDONGAK berhadap-hadapan dengan wajah Jennifer. Wajahnya TENANG/senang sejak awal
##      cutscene (dia puas berhasil menangkap player): "See you tomorrow." Lampu berkedip dan padam, bel berbunyi keras, gelap.
##   4. Kartu ending: "ENDING 1 OF 2 / DETENTION FOREVER / The bell never rings for you."
##
## Semua posisi diambil dari data ruang guru di lantai 1.tscn (konstanta di bawah, satuan meter, koordinat dunia).
## Kalau ada yang menembus perabot, cukup ubah angka di bagian "TATA LETAK" tanpa menyentuh kode lain.
## Tinggi lantai dan permukaan meja dideteksi otomatis lewat raycast (cadangan: angka tetap).
## Tidak butuh aset baru: Jennifer memakai res://characters/jennifer.glb, bunyi bel/ketukan/kapur dibuat dari kode,
## suara "Time over." memakai file yang sudah ada. Teks subtitle ada di subtitle_data.gd (4 bahasa).
## Pemain bisa melewati dengan SPASI / ENTER / klik.

signal finished

const SUBS := preload("res://scripts/subtitle_data.gd")
## true = semua teks cutscene ini (narasi, dialog, tulisan di kertas, tombol skip) selalu Inggris. false = ikut bahasa di Options.
const FORCE_ENGLISH := true
const JEN_GLB := "res://characters/jennifer.glb"
const FACE_ANGRY := "res://characters/face_angry.png"
const AMBIENT_PATH := "res://audio/music/horror_loop.mp3"
const LIGHT_ENERGY := 2.4

# ---- TATA LETAK (RUANG GURU) ------------------------------------------------------------------
# Ruang guru: x 34.4..43.9, z 3.2..22.8 (memanjang utara-selatan). Meja rapat di sekitar (38.7, 17.5),
# meja kepala sekolah di (39.8, 8.4), rak buku di dinding selatan (z = 3.5). Lantai terbuka di antaranya.
# Format Vector2 = (x, z). Tinggi (y) dihitung otomatis dari lantai.
const FLOOR_FALLBACK := 0.31                          # tinggi lantai kalau raycast gagal
const FLOOR_PROBE := Vector2(38.0, 13.0)              # titik lantai kosong untuk mengukur tinggi lantai
const SHOT1_CAM := Vector2(38.0, 14.1)                # kamera (mata) saat berdiri di depan Jennifer, menghadap selatan
const SHOT1_JEN := Vector2(38.0, 11.9)                # Jennifer menjulang di depan kamera
# Adegan menulis: meja kecil + kursi dibuat dari kode di lantai kosong ruang guru (di antara meja kepala sekolah dan meja rapat).
# Player duduk di sisi selatan menghadap utara (+Z), Jennifer berdiri di seberang meja menghadap player (selatan).
const SEAT := Vector2(38.0, 12.12)                    # kepala/mata player saat duduk, menghadap utara (+Z)
const SEAT_EYE := 1.22                                # tinggi mata saat duduk (dari lantai)
const STAND_EYE := 1.55                               # tinggi mata saat berdiri (sama seperti kamera player waktu bermain)
const HIP_Z := 11.95                                  # posisi pinggul player di sumbu Z (badan di belakang kepala)
const DESK_XZ := Vector2(38.0, 12.8)                  # pusat meja
const DESK_SIZE := Vector2(1.5, 0.7)                  # lebar (x) dan kedalaman (z) meja
const DESK_TOP := 0.74                                # tinggi permukaan meja dari lantai
const PAPER_XZ := Vector2(38.0, 12.7)                 # pusat kertas di atas meja
const LIGHT_XZ := Vector2(38.0, 12.9)                 # lampu neon di atas meja
# Jennifer DUDUK di kursi seberang meja, menghadap player (hadap-hadapan). Model aslinya berdiri, jadi seluruh model
# diturunkan JEN_SIT_DROP supaya pinggulnya pas di dudukan kursi. Bagian bawah badannya tertutup meja + papan depan meja.
const JEN_SEAT := Vector2(38.0, 13.7)                 # pinggul Jennifer = pusat kursinya (meja ada di z 12.45..13.15)
const JEN_SIT_DROP := 0.67                            # seberapa turun model berdiri (m). Pinggul model = 0.95 x 1.3 = 1.235 m
const JEN_FACE_Y := 1.50                              # tinggi pusat WAJAH (bukan jilbab/leher) dari lantai saat DUDUK (2.16 - JEN_SIT_DROP)
const JEN_FACE_STAND := 2.16                          # tinggi pusat wajah saat BERDIRI (dipakai adegan pertama)
const JEN_FACE_FWD := 0.15                            # wajah lebih maju dari pinggul sebesar ini ke arah player
const PAPER_LOOK_Y := 0.76                            # titik di kertas yang dilihat saat menulis (tinggi dari lantai)
const LINE_H := 0.0385                                # tinggi satu baris tulisan di kertas (meter)

# Soal hukuman yang "dikerjakan" player di kertas REMEDIAL (satu baris per soal). "@broken" = soal RUSAK (tulisan acak bertumpuk,
# sama seperti soal rusak di gameplay / question_bank.gd, tidak punya jawaban). Maks 9 baris supaya muat di kertas.
const PROBLEMS := [
	"7 + 6 = 13",
	"@broken",
	"47 × 38 = 1786",
	"@broken",
	"@broken",
	"1296 ÷ 24 = 54",
	"@broken",
	"@broken",
	"(12 + 9) × (15 − 6) = 189",
]
# Bahan soal untuk lembaran kertas lepas / tumpukan di meja (cuma hiasan, dipilih acak).
const SHEET_POOL := [
	"12 × 13 = ?", "x² − 5x + 6 = 0", "441 ÷ 21 = ?", "3/4 + 5/6 = ?", "18 × 27 = ?",
	"2^5 × 3^2 = ?", "(−8) × (−7) = ?", "0.75 × 64 = ?", "4x − 9 = 27", "1001 − 478 = ?",
	"3, 9, 27, 81, ?", "15% of 480 = ?", "256 ÷ 16 + 7 × 9", "999 + 888 + 777", "(x + 3)² = 49",
	"7 × 8 − 9 × 4", "1/2 + 1/3 + 1/6", "125 × 16 = ?", "2x + 3y = 12", "5, 11, 17, 23, ?",
]

var _floor_y := FLOOR_FALLBACK

var _skip := false
var _elapsed := 0.0

# dunia
var _stage: Node3D
var _rig: Node3D
var _cam: Camera3D
var _env: Environment
var _light: OmniLight3D
var _paper: Node3D
var _board: Label3D          # tulisan hukuman di kertas
var _hand: Node3D            # (tidak dipakai lagi: tangan player sekarang bagian dari model _student)
var _furn: Node3D            # meja + kursi + player, hanya tampil di adegan menulis
var _student: Node3D         # model player duduk (kepala disembunyikan karena kamera = mata player; badan + lengan tetap kelihatan)
var _stu_arm: Node3D         # lengan kanan player yang menulis (berputar di siku)
var _stu_arm_base := Vector3.ZERO
var _props_in := 0.0         # 0 = kertas & tangan di luar layar, 1 = terlihat
var _props_tw: Tween
var _write_line := -1        # baris yang sedang ditulis (-1 = tidak menulis)
var _write_t := 0.0
var _write_interval := 1.25
var _write_sentence := ""
var _write_done := ""
var _hand_pos := Vector2(-0.2, 0.13)
var _jen: Node3D
var _jen_anim: AnimationPlayer
var _face_mat: StandardMaterial3D
var _tex_calm: Texture2D
var _tex_angry: Texture2D
var _rig_tw: Tween
var _jen_tw: Tween
var _fade_tw: Tween
var _amb: AudioStreamPlayer

# efek
var _shake := 0.0
var _flicker := 0.0
var _flick_t := 0.0
var _flick_dim := false
var _lights_out := false

# UI
var _layer: CanvasLayer
var _black: ColorRect
var _sub_label: Label
var _card_label: Label
var _hint: Label

# bunyi buatan kode
var _snd_bell: AudioStreamWAV
var _snd_tap: AudioStreamWAV
var _snd_chalk: AudioStreamWAV


# ------------------------------------------------------------------ alur utama

func run(_jen_ref: Node = null) -> void:
	GameState.set_process_unhandled_input(false)
	_build_audio()
	_build_overlay()      # layar langsung hitam penuh, menutupi sisa adegan jumpscare
	_silence_game_music()
	_hide_world_ui()
	await get_tree().physics_frame   # raycast fisika hanya aman setelah frame fisika
	_probe_heights()
	_build_stage()
	_build_camera()
	_start_ambient()

	await _wait(0.6)
	await _card("c_bell", "The final bell rang hours ago.", 3.6, true)
	await _shot_floor()
	await _shot_desk()
	await _ending_card()
	if _amb != null:
		_amb.stop()
	finished.emit()


# 1) player berdiri (mata setinggi saat bermain), Jennifer menjulang di depan
func _shot_floor() -> void:
	if _skip:
		return
	var cam_pos := _at(SHOT1_CAM, STAND_EYE)
	_place_jennifer(_at(SHOT1_JEN), cam_pos)
	_set_face(false)
	_play_anim("idle")
	_light.global_position = _at(Vector2(SHOT1_JEN.x, (SHOT1_JEN.y + SHOT1_CAM.y) * 0.5), 2.7)
	_rig.global_position = cam_pos
	var dist1 := maxf((SHOT1_CAM - SHOT1_JEN).length(), 0.3)
	var pitch1 := rad_to_deg(atan2(_floor_y + JEN_FACE_STAND - cam_pos.y, dist1))
	_rig.rotation_degrees = Vector3(pitch1 - 8.0, 0.0, 0.0)     # yaw 0 = menghadap selatan (-Z), tanpa miring
	_cam.fov = 70.0
	_flicker = 0.35
	await _fade(0.0, 1.4)

	var tw := _new_rig_tween()
	tw.tween_property(_rig, "rotation_degrees", Vector3(pitch1, 0.0, 0.0), 2.0).set_trans(Tween.TRANS_SINE)     # mendongak ke wajahnya
	tw.tween_property(_rig, "global_position", _at(SHOT1_CAM + Vector2(0.0, -0.35), STAND_EYE - 0.03), 10.0)   # tertekan pelan ke belakang

	await _say("c_leave", "Leaving so early?", 2.6)
	await _say("gave_up", "Time over.", 2.4, "gave_up")
	_tap_loop(3, 0.55)
	await _say("c_notdone", "Class is not dismissed.", 3.0)
	await _wait(0.4)
	_play(_snd_tap, 2.0)
	_shake = 0.03
	await _fade(1.0, 0.45)
	_shake = 0.0
	_kill_rig_tween()   # tween 10 dtk di atas belum selesai; kalau dibiarkan, dia menarik kamera ke dekat Jennifer di adegan berikutnya


# 2) player duduk menulis hukuman di meja ruang guru. SELURUHNYA sudut pandang mata player (kamera = kepala player):
#    menunduk melihat kertas + tangan sendiri menulis, lalu mendongak berhadap-hadapan dengan Jennifer di seberang meja.
func _shot_desk() -> void:
	if _skip:
		return
	var eye := _at(SEAT, SEAT_EYE)
	_kill_rig_tween()

	_furn.visible = true
	_student.visible = true
	_props_in = 1.0
	_write_done = ""
	_write_line = -1
	_board.text = ""
	_stu_arm.position = _stu_arm_base
	_light.global_position = _at(LIGHT_XZ, 2.6)
	_env.ambient_light_energy = 1.3
	_place_jennifer(_at(JEN_SEAT, -JEN_SIT_DROP), _at(SEAT))   # duduk di kursi seberang meja, menghadap player
	_set_face(false)
	_play_anim("idle")

	# kamera = mata player yang duduk, menghadap utara (+Z), menunduk ke kertas
	var dist_paper := maxf(PAPER_XZ.y + 0.12 - SEAT.y, 0.2)
	var pitch_down := -rad_to_deg(atan2(eye.y - (_floor_y + PAPER_LOOK_Y), dist_paper))
	var dist_jen := maxf(JEN_SEAT.y - JEN_FACE_FWD - SEAT.y, 0.3)   # jarak datar mata player -> wajah Jennifer
	var pitch_up := rad_to_deg(atan2(_floor_y + JEN_FACE_Y - eye.y, dist_jen))   # tepat ke pusat wajah
	_rig.global_position = eye
	_rig.rotation_degrees = Vector3(pitch_down, 180.0, 0.0)     # yaw 180 = menghadap utara (+Z)
	_cam.fov = 70.0
	_flicker = 0.12
	await _fade(0.0, 1.0)

	# kepala bergerak sangat pelan saat menulis (condong sedikit ke kiri-kanan mengikuti tangan)
	var sway := _new_rig_tween()
	sway.tween_property(_rig, "rotation_degrees", Vector3(pitch_down + 3.0, 180.0, 0.0), 12.0).set_trans(Tween.TRANS_SINE)
	await _say("c_remedial", "Remedial. Starting now.", 2.8)

	_approach_desk()
	_tap_loop(8, 1.0, -8.0)
	_write_board(PROBLEMS.size(), 1.0)
	await _say("c_write", "Solve them. All of them.", 3.2)
	await _wait(5.6)
	if _skip:
		return

	# ---- tanpa potong: player pelan-pelan mendongak, berhadap-hadapan dengan wajah Jennifer
	_play_anim("idle")
	_face_toward(eye)
	_env.ambient_light_energy = 0.9
	_flicker = 0.4
	var ct := _new_rig_tween()
	ct.tween_property(_rig, "rotation_degrees", Vector3(pitch_up, 180.0, 0.0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ct.tween_property(_cam, "fov", 42.0, 7.0)   # makin dekat ke wajah
	await _wait(2.8)

	# wajahnya tetap tenang/senang (sudah begitu sejak awal cutscene)
	_flicker = 0.0
	_set_face(false)
	await _say("c_see", "See you tomorrow.", 3.4)

	# lampu berkedip, padam, bel
	_flicker = 1.0
	await _wait(1.3)
	_lights_out = true
	_env.ambient_light_energy = 0.0
	if _amb != null:
		create_tween().tween_property(_amb, "volume_db", -60.0, 1.5)
	await _wait(1.1)
	_play(_snd_bell, -1.0)
	_shake = 0.012
	await _wait(2.0)
	await _fade(1.0, 0.4)
	_shake = 0.0


# Jennifer sudah duduk di seberang meja sejak awal; cukup mainkan animasi diam (paralel dengan dialog).
func _approach_desk() -> void:
	if _jen == null:
		return
	if _jen_tw != null and _jen_tw.is_valid():
		_jen_tw.kill()
	_face_toward(_at(SEAT))
	_play_anim("idle")


func _face_toward(p: Vector3) -> void:
	if _jen == null:
		return
	var d := p - _jen.global_position
	d.y = 0.0
	if d.length() > 0.01:
		_jen.rotation.y = atan2(d.x, d.z)


# 3) kartu ending
func _ending_card() -> void:
	_sub_label.visible = false
	_hint.visible = false
	_card_label.modulate.a = 0.0
	_black.color.a = 1.0

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	# Kartu ending selalu bahasa Inggris (apa pun bahasa subtitle). Lebar minimum wajib supaya teks tidak turun per huruf.
	var small := _make_label("ENDING 1 OF 2", 26, Color(0.7, 0.7, 0.68))
	var title := _make_label("DETENTION FOREVER", 76, Color(0.85, 0.1, 0.1))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var sub := _make_label("The bell never rings for you.", 30, Color(0.92, 0.9, 0.85))
	var card_w := get_viewport().get_visible_rect().size.x * 0.8
	for lab: Label in [small, title, sub]:
		lab.custom_minimum_size = Vector2(card_w, 0.0)
		lab.modulate.a = 0.0
		box.add_child(lab)

	var tw := create_tween()
	tw.tween_property(small, "modulate:a", 1.0, 0.8).set_delay(0.5)
	tw.tween_property(title, "modulate:a", 1.0, 1.2)
	tw.tween_property(sub, "modulate:a", 0.85, 1.2).set_delay(0.6)
	var hold := 2.5 if _skip else 7.0
	await get_tree().create_timer(hold).timeout
	var out := create_tween()
	out.tween_property(box, "modulate:a", 0.0, 1.0)
	await get_tree().create_timer(1.2).timeout


# ------------------------------------------------------------------ input (lewati)

func _input(event: InputEvent) -> void:
	if _skip or _elapsed < 1.0:
		return
	var go := false
	if event is InputEventKey:
		var k := event as InputEventKey
		go = k.pressed and not k.echo and (k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER)
	elif event is InputEventMouseButton:
		go = (event as InputEventMouseButton).pressed
	if go:
		_skip = true
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	_elapsed += delta
	if _cam != null and is_instance_valid(_cam):
		var s := _shake
		_cam.position = Vector3(
			sin(_elapsed * 0.9) * 0.012 + randf_range(-1.0, 1.0) * s,
			sin(_elapsed * 1.3) * 0.010 + randf_range(-1.0, 1.0) * s,
			0.0)
		_cam.rotation = Vector3(
			sin(_elapsed * 0.7) * 0.006,
			sin(_elapsed * 0.5) * 0.008,
			sin(_elapsed * 0.4) * 0.010 + randf_range(-1.0, 1.0) * s * 0.8)
	_update_writing(delta)
	if _light != null and is_instance_valid(_light):
		_flick_t -= delta
		if _flick_t <= 0.0:
			_flick_t = randf_range(0.04, 0.22)
			_flick_dim = randf() < _flicker * 0.5
		var e := LIGHT_ENERGY
		if _lights_out:
			e = 0.0
		elif _flick_dim and _flicker > 0.0:
			e = LIGHT_ENERGY * randf_range(0.05, 0.5)
		_light.light_energy = e


# ------------------------------------------------------------------ helper alur

# Teks cutscene: Inggris (fallback di kode) kalau FORCE_ENGLISH, kalau tidak ikut bahasa subtitle di Options.
func _txt(id: String, fallback: String) -> String:
	return fallback if FORCE_ENGLISH else SUBS.line(id, fallback)


# Titik di dunia dari koordinat (x, z) + tinggi di atas lantai.
func _at(xz: Vector2, up := 0.0) -> Vector3:
	return Vector3(xz.x, _floor_y + up, xz.y)


# Menunggu sekian detik, tapi langsung selesai kalau pemain menekan lewati.
func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()


func _fade(alpha: float, secs: float) -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	if _skip:
		_black.color.a = alpha
		return
	_fade_tw = create_tween()
	_fade_tw.tween_property(_black, "color:a", alpha, secs)
	await _wait(secs)
	_black.color.a = alpha


# Kartu teks di layar hitam (narasi). Selalu tampil walau subtitle dimatikan, karena ini bagian cerita.
func _card(id: String, fallback: String, secs: float, with_bell := false) -> void:
	if _skip:
		return
	_card_label.text = _txt(id, fallback)
	_card_label.modulate.a = 0.0
	if with_bell:
		_play(_snd_bell, -9.0)
	var tw := create_tween()
	tw.tween_property(_card_label, "modulate:a", 1.0, 0.9)
	await _wait(secs)
	var out := create_tween()
	out.tween_property(_card_label, "modulate:a", 0.0, 0.6)
	await _wait(0.8)


# Dialog Jennifer: subtitle di bawah layar + (opsional) suara dari file yang sudah ada.
func _say(id: String, fallback: String, secs: float, voice := "") -> void:
	if _skip:
		return
	if voice != "":
		_play_voice(voice)
	_sub_label.text = _txt(id, fallback)
	_sub_label.visible = SUBS.enabled()
	await _wait(secs)
	_sub_label.visible = false
	await _wait(0.25)


# Pemain mengerjakan satu soal per baris tiap interval detik (berjalan paralel dengan dialog). Teks dan tangan dianimasikan di _update_writing().
# Baris "@broken" = soal rusak: satu baris tulisan acak (rapi, tidak ditimpa apa pun), nggak bisa dijawab.
func _write_board(lines: int, interval: float) -> void:
	_write_interval = interval
	_write_done = ""
	for i in mini(lines, PROBLEMS.size()):
		if _skip:
			break
		var broken: bool = PROBLEMS[i] == "@broken"
		_write_sentence = QuestionBank._garble(26) if broken else String(PROBLEMS[i])
		_write_line = i
		_write_t = 0.0
		_play(_snd_chalk, -7.0)
		await _wait(interval)
		_write_done += ("\n" if i > 0 else "") + _write_sentence
	_write_line = -1
	_board.text = _write_done


# Kertas + tangan: posisi di layar, huruf muncul pelan-pelan mengikuti ujung pena, tangan bergetar halus.
func _update_writing(delta: float) -> void:
	if _paper == null or not is_instance_valid(_paper):
		return
	_paper.visible = _props_in > 0.01
	if _write_line >= 0:
		_write_t += delta
		var frac := clampf(_write_t / (_write_interval * 0.85), 0.0, 1.0)
		var n := int(frac * _write_sentence.length())
		var prefix := _write_done + ("\n" if _write_line > 0 else "")
		_board.text = prefix + _write_sentence.substr(0, n)
		var half := _write_sentence.length() * 0.0078
		_hand_pos = Vector2(
			lerpf(-half, half, frac) + sin(_elapsed * 24.0) * 0.004,
			0.15 - (float(_write_line) + 0.55) * LINE_H + cos(_elapsed * 31.0) * 0.003)
	if _hand != null:
		_hand.position = Vector3(_hand_pos.x, _hand_pos.y, 0.004)
		_hand.rotation.z = sin(_elapsed * 20.0) * 0.03 if _write_line >= 0 else 0.0
	if _stu_arm != null and is_instance_valid(_stu_arm) and _write_line >= 0:
		# tangan player menulis: bergerak dari kiri ke kanan tiap baris (ke arah -X), turun satu baris setiap selesai
		var frac2 := clampf(_write_t / (_write_interval * 0.85), 0.0, 1.0)
		_stu_arm.position = _stu_arm_base + Vector3(0.0, 0.0, -float(_write_line) * LINE_H)
		_stu_arm.rotation.y = -(frac2 - 0.5) * 0.7 + sin(_elapsed * 22.0) * 0.03


func _show_props(on: bool) -> void:
	if _props_tw != null and _props_tw.is_valid():
		_props_tw.kill()
	_props_tw = create_tween()
	_props_tw.tween_property(self, "_props_in", 1.0 if on else 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _tap_loop(count: int, gap: float, db := -4.0) -> void:
	for i in count:
		if _skip:
			return
		_play(_snd_tap, db)
		await _wait(gap)


# Matikan tween kamera yang masih berjalan (tween adegan sebelumnya tidak boleh menimpa posisi kamera adegan berikutnya).
func _kill_rig_tween() -> void:
	if _rig_tw != null and _rig_tw.is_valid():
		_rig_tw.kill()


func _new_rig_tween() -> Tween:
	if _rig_tw != null and _rig_tw.is_valid():
		_rig_tw.kill()
	_rig_tw = create_tween().set_parallel(true)
	return _rig_tw


# ------------------------------------------------------------------ Jennifer

func _place_jennifer(pos: Vector3, face_pos: Vector3) -> void:
	if _jen == null:
		return
	if _jen_tw != null and _jen_tw.is_valid():
		_jen_tw.kill()
	_jen.global_position = pos
	_face_toward(face_pos)   # depan model = +Z


func _play_anim(anim_name: String) -> void:
	if _jen_anim != null and _jen_anim.has_animation(anim_name):
		_jen_anim.play(anim_name, 0.25)


func _set_face(angry: bool) -> void:
	if _face_mat == null:
		return
	if angry and _tex_angry != null:
		_face_mat.albedo_texture = _tex_angry
	elif _tex_calm != null:
		_face_mat.albedo_texture = _tex_calm


# Meja, kursi, dan model player duduk (semua kotak/bola sederhana dari kode). Hanya tampil di adegan menulis.
func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, 0.8)
	parent.add_child(mi)
	mi.global_position = pos
	mi.rotation_degrees = rot


func _ball(parent: Node3D, radius: float, pos: Vector3, color: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _mat(color, 0.75)
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = scl
	return mi


func _build_furniture() -> void:
	_furn = Node3D.new()
	_furn.name = "DeskSet"
	_furn.visible = false
	_stage.add_child(_furn)
	var wood := Color(0.36, 0.23, 0.13)
	var dark := Color(0.16, 0.12, 0.09)
	var f := _floor_y
	# meja: papan atas + 4 kaki
	_box(_furn, Vector3(DESK_SIZE.x, 0.05, DESK_SIZE.y), Vector3(DESK_XZ.x, f + DESK_TOP - 0.025, DESK_XZ.y), wood)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(_furn, Vector3(0.06, DESK_TOP - 0.05, 0.06),
				Vector3(DESK_XZ.x + sx * (DESK_SIZE.x * 0.5 - 0.06), f + (DESK_TOP - 0.05) * 0.5, DESK_XZ.y + sz * (DESK_SIZE.y * 0.5 - 0.06)), dark)
	# kursi: dudukan + sandaran + 4 kaki
	var cx := SEAT.x
	var cz := HIP_Z + 0.02
	_box(_furn, Vector3(0.46, 0.04, 0.46), Vector3(cx, f + 0.45, cz + 0.05), dark)
	_box(_furn, Vector3(0.46, 0.50, 0.04), Vector3(cx, f + 0.72, cz - 0.18), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(_furn, Vector3(0.04, 0.43, 0.04), Vector3(cx + sx * 0.20, f + 0.215, cz + 0.05 + sz * 0.20), dark)
	# papan depan meja di sisi Jennifer: menutup kaki/pinggulnya dari pandangan player
	_box(_furn, Vector3(DESK_SIZE.x, DESK_TOP - 0.05, 0.03), Vector3(DESK_XZ.x, f + (DESK_TOP - 0.05) * 0.5, DESK_XZ.y + DESK_SIZE.y * 0.5 - 0.02), dark)
	# kursi Jennifer (menghadap selatan, sandaran di sisi utara = belakang Jennifer)
	var jx := JEN_SEAT.x
	var jz := JEN_SEAT.y
	_box(_furn, Vector3(0.50, 0.04, 0.50), Vector3(jx, f + 0.45, jz), dark)
	_box(_furn, Vector3(0.50, 0.55, 0.04), Vector3(jx, f + 0.74, jz + 0.24), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(_furn, Vector3(0.04, 0.43, 0.04), Vector3(jx + sx * 0.21, f + 0.215, jz + sz * 0.21), dark)
	_build_student(f)
	_build_paper_piles()


# Satu lembar kertas soal tergeletak di meja (kuad + teks kecil). y_up = tinggi dari lantai, yaw = putaran di atas meja (derajat).
func _sheet(xz: Vector2, y_up: float, yaw: float, size: Vector2, text: String) -> void:
	var s := Node3D.new()
	_furn.add_child(s)
	s.global_position = _at(xz, y_up)
	s.rotation_degrees = Vector3(-90.0, 180.0 + yaw, 0.0)     # sama seperti kertas utama: sisi atas kertas menjauh dari player
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	quad.mesh = qm
	var pm := _mat(Color(0.93, 0.91, 0.83), 0.95)
	pm.emission_enabled = true
	pm.emission = Color(0.30, 0.30, 0.26)
	pm.emission_energy_multiplier = 0.45
	quad.material_override = pm
	s.add_child(quad)
	if text != "":
		var lab := Label3D.new()
		lab.text = text
		lab.font_size = 24
		lab.pixel_size = 0.0009
		lab.outline_size = 0
		lab.shaded = false
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		lab.modulate = Color(0.08, 0.08, 0.2, 0.9)
		lab.position = Vector3(0.0, size.y * 0.5 - 0.02, 0.001)
		s.add_child(lab)


# Teks hiasan untuk selembar kertas: beberapa soal acak, kadang diselipi satu baris soal rusak.
func _sheet_text(rng: RandomNumberGenerator, lines: int) -> String:
	var out := PackedStringArray()
	for i in lines:
		if rng.randf() < 0.45:     # hampir separuh baris di tiap lembar adalah soal rusak
			out.append(QuestionBank._garble(rng.randi_range(18, 24)))
		else:
			out.append(String(SHEET_POOL[rng.randi() % SHEET_POOL.size()]))
	return "\n".join(out)


# Tumpukan kertas: balok putih + beberapa lembar miring di atasnya supaya tampak berantakan.
func _stack(xz: Vector2, w: float, d: float, sheets: int, yaw: float, rng: RandomNumberGenerator) -> void:
	var h := 0.004 * float(sheets)
	_box(_furn, Vector3(w, h, d), Vector3(xz.x, _floor_y + DESK_TOP + h * 0.5, xz.y), Color(0.80, 0.78, 0.70), Vector3(0.0, yaw, 0.0))
	for k in 3:
		_sheet(xz + Vector2(rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02)), DESK_TOP + h + 0.0015 * float(3 - k),
				yaw + rng.randf_range(-22.0, 22.0), Vector2(w + 0.02, d + 0.02), _sheet_text(rng, 6) if k == 2 else "")


# Meja penuh kertas: tumpukan di kiri/kanan/seberang meja, lembaran lepas berserakan, dan beberapa lembar tipis di bawah kertas utama.
func _build_paper_piles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# lembar-lembar di bawah kertas utama (tepinya mengintip keluar)
	for i in 3:
		_sheet(PAPER_XZ + Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.02, 0.03)), DESK_TOP + 0.0008 * float(i + 1),
				[7.0, -9.0, 14.0][i], Vector2(0.66, 0.48), "")   # tanpa teks: cuma tepinya yang mengintip, supaya tulisan di kertas utama bersih
	# tumpukan (kiri/kanan player dan di seberang meja)
	_stack(Vector2(37.45, 12.60), 0.26, 0.19, 26, 6.0, rng)
	_stack(Vector2(38.55, 12.62), 0.24, 0.18, 18, -8.0, rng)
	_stack(Vector2(37.50, 13.04), 0.26, 0.19, 12, 12.0, rng)
	_stack(Vector2(38.52, 13.04), 0.25, 0.19, 22, -14.0, rng)
	# lembar lepas berserakan (di samping kertas utama, tidak menutupi tulisan)
	_sheet(Vector2(37.50, 12.88), DESK_TOP + 0.0015, 20.0, Vector2(0.28, 0.20), _sheet_text(rng, 6))
	_sheet(Vector2(38.55, 12.90), DESK_TOP + 0.0020, -25.0, Vector2(0.28, 0.20), _sheet_text(rng, 6))


# Siswa (player) duduk: baju putih + celana abu-abu, badan agak condong ke meja, kepala menunduk, tangan kanan menulis.
func _build_student(f: float) -> void:
	_student = Node3D.new()
	_student.name = "Student"
	_furn.add_child(_student)
	var shirt := Color(0.88, 0.88, 0.85)
	var pants := Color(0.33, 0.34, 0.38)
	var skin := Color(0.86, 0.66, 0.52)
	var hair := Color(0.05, 0.04, 0.04)
	var cx := SEAT.x
	var z0 := HIP_Z
	# kaki: paha di atas kursi, betis ke lantai, sepatu
	_box(_student, Vector3(0.36, 0.18, 0.22), Vector3(cx, f + 0.58, z0), pants)
	for sx in [-1.0, 1.0]:
		_box(_student, Vector3(0.16, 0.16, 0.44), Vector3(cx + sx * 0.10, f + 0.57, z0 + 0.22), pants)
		_box(_student, Vector3(0.13, 0.46, 0.13), Vector3(cx + sx * 0.10, f + 0.23, z0 + 0.40), pants)
		_box(_student, Vector3(0.14, 0.07, 0.26), Vector3(cx + sx * 0.10, f + 0.035, z0 + 0.46), dark_shoe())
	# badan + kepala (condong ke depan)
	_box(_student, Vector3(0.38, 0.52, 0.22), Vector3(cx, f + 0.93, z0 + 0.04), shirt, Vector3(12.0, 0.0, 0.0))
	# kepala + rambut disembunyikan: kamera ada di dalam kepala (sudut pandang orang pertama)
	_ball(_student, 0.115, Vector3(cx, f + 1.31, SEAT.y), skin).visible = false
	_ball(_student, 0.125, Vector3(cx, f + 1.335, SEAT.y - 0.025), hair, Vector3(1.0, 0.9, 1.0)).visible = false
	# lengan kiri: bertumpu di meja, tangan terbuka rata di tepi kertas
	var sh_l := Vector3(cx + 0.22, f + 1.10, z0 + 0.10)
	var el_l := Vector3(cx + 0.30, f + 0.86, z0 + 0.30)
	var wr_l := Vector3(cx + 0.24, f + DESK_TOP + 0.024, 12.50)
	_limb(_student, sh_l, el_l, 0.036, shirt, 0.034)
	_lball(_student, 0.034, el_l, shirt)
	_forearm(_student, el_l, wr_l, shirt, skin)
	_make_hand(_student, wr_l, (wr_l - el_l).normalized(), false, false)
	# lengan kanan (sisi -X): lengan atas diam, lengan bawah + tangan berputar di siku untuk menulis
	var sh_r := Vector3(cx - 0.22, f + 1.10, z0 + 0.10)
	var el_r := Vector3(cx - 0.28, f + 0.86, z0 + 0.30)
	var tip_r := Vector3(cx - 0.10, f + DESK_TOP + 0.004, 12.84)     # ujung pena menyentuh kertas di sini
	var pen_tip_local := Vector3(-0.045, -0.018, -0.15)              # posisi ujung pena di kerangka tangan (harus sama dengan _make_hand)
	var dir_r := (tip_r - el_r).normalized()
	var wr_r := tip_r - Basis.looking_at(dir_r, Vector3.UP) * pen_tip_local
	_limb(_student, sh_r, el_r, 0.036, shirt, 0.034)
	_stu_arm = Node3D.new()
	_student.add_child(_stu_arm)
	_stu_arm.position = el_r
	_stu_arm_base = el_r
	var rel := wr_r - el_r
	_lball(_stu_arm, 0.034, Vector3.ZERO, shirt)
	_forearm(_stu_arm, Vector3.ZERO, rel, shirt, skin)
	_make_hand(_stu_arm, rel, dir_r, true, true)


# Kotak/bola lokal (mengikuti induknya, beda dengan _box/_ball yang memakai posisi dunia).
func _lbox(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, 0.7)
	parent.add_child(mi)
	mi.position = pos


func _lball(parent: Node3D, radius: float, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = _mat(color, 0.7)
	parent.add_child(mi)
	mi.position = pos


# Lengan bawah: lengan baju seragam yang meruncing, kancing manset putih, lalu pergelangan kulit.
func _forearm(parent: Node3D, el: Vector3, wrist: Vector3, shirt: Color, skin: Color) -> void:
	var d := (wrist - el).normalized()
	var cuff_end := wrist - d * 0.035
	_limb(parent, el, cuff_end - d * 0.022, 0.034, shirt, 0.028)
	_limb(parent, cuff_end - d * 0.024, cuff_end, 0.031, Color(0.95, 0.95, 0.93))
	_limb(parent, cuff_end - d * 0.004, wrist, 0.019, skin, 0.021)


# Tangan dengan telapak, 4 jari (2 ruas) dan ibu jari. Kerangka lokal: -Z = arah jari, +Y = punggung tangan.
# grip_pen = true: jari melengkung memegang pena (tangan kanan menulis). false = terbuka santai di atas meja.
func _make_hand(parent: Node3D, pos: Vector3, dir: Vector3, right_hand: bool, grip_pen: bool) -> void:
	var skin := Color(0.86, 0.66, 0.52)
	var m := 1.0 if right_hand else -1.0      # kiri/kanan: ibu jari ada di sisi berlawanan
	var h := Node3D.new()
	parent.add_child(h)
	h.position = pos
	h.basis = Basis.looking_at(dir, Vector3.UP)
	_lball(h, 0.022, Vector3.ZERO, skin)
	_lbox(h, Vector3(0.072, 0.02, 0.085), Vector3(0.0, 0.0, -0.0425), skin)
	var xs := [-0.027, -0.009, 0.009, 0.027]
	var lens := [1.0, 1.12, 1.0, 0.8]
	for i in 4:
		var x: float = float(xs[i]) * m
		var L: float = lens[i]
		var curl := 0.25
		if grip_pen:
			curl = 1.0 if i == 0 else 1.6      # telunjuk di pena, jari lain menekuk ke dalam
		var a := Vector3(x, 0.0, -0.085)
		var b := a + Vector3(0.0, -0.006 * curl, -0.034 * L * (1.0 - 0.25 * curl))
		var c := b + Vector3(0.0, -0.016 * curl, -0.026 * L * (1.0 - 0.3 * curl))
		_limb(h, a, b, 0.0085, skin, 0.0078)
		_limb(h, b, c, 0.0078, skin, 0.0068)
		_lball(h, 0.0085, a, skin)
		_lball(h, 0.0078, b, skin)
		_lball(h, 0.0068, c, skin)
	# ibu jari
	var t0 := Vector3(-0.034 * m, -0.002, -0.015)
	var t1 := Vector3(-0.046 * m, -0.006, -0.050)
	var t2 := Vector3(-0.036 * m, -0.012 if grip_pen else -0.004, -0.078)
	_limb(h, t0, t1, 0.0105, skin, 0.0095)
	_limb(h, t1, t2, 0.0095, skin, 0.0085)
	_lball(h, 0.0105, t0, skin)
	_lball(h, 0.0095, t1, skin)
	_lball(h, 0.0085, t2, skin)
	if grip_pen:
		# pena dijepit ibu jari + telunjuk, ujungnya (-0.045, -0.018, -0.15) menyentuh kertas
		var back := Vector3(0.0, 0.035, 0.04)
		var tip := Vector3(-0.045, -0.018, -0.15)
		var toward_back := (back - tip).normalized()
		_limb(h, back, tip + toward_back * 0.014, 0.0045, Color(0.08, 0.10, 0.35))
		_limb(h, tip + toward_back * 0.014, tip, 0.0045, Color(0.05, 0.05, 0.05), 0.0012)


func dark_shoe() -> Color:
	return Color(0.08, 0.07, 0.07)


func _build_jennifer() -> void:
	if not ResourceLoader.exists(JEN_GLB):
		push_warning("caught_cutscene: %s tidak ditemukan, cutscene tanpa Jennifer." % JEN_GLB)
		return
	var scene := load(JEN_GLB) as PackedScene
	if scene == null:
		return
	_jen = scene.instantiate() as Node3D
	_jen.scale = Vector3.ONE * 1.3     # sama dengan model_scale di teacher.gd
	_stage.add_child(_jen)
	_jen.global_position = _at(JEN_SEAT, -JEN_SIT_DROP)
	_jen_anim = _jen.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _jen_anim != null:
		for n in ["idle", "walk", "angry_idle"]:
			if _jen_anim.has_animation(n):
				_jen_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var face := _jen.find_child("Face", true, false) as MeshInstance3D
	if face != null and face.get_surface_override_material_count() > 0:
		var base := face.get_active_material(0)
		if base is StandardMaterial3D:
			_face_mat = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
			face.set_surface_override_material(0, _face_mat)
			_tex_calm = _face_mat.albedo_texture
	if ResourceLoader.exists(FACE_ANGRY):
		_tex_angry = load(FACE_ANGRY) as Texture2D


# ------------------------------------------------------------------ panggung (ruang guru asli)

func _mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _ray_down(x: float, z: float, from_y: float, to_y: float) -> Dictionary:
	var space := get_viewport().find_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, to_y, z))
	q.collide_with_areas = false
	return space.intersect_ray(q)


# Ukur tinggi lantai ruang guru dari collision peta. Gagal = pakai angka cadangan.
# Diambil dari BEBERAPA titik, lalu dipilih yang paling rendah: kalau satu titik kebetulan kena meja/rak, tinggi lantai tidak ikut salah.
func _probe_heights() -> void:
	var lowest := INF
	for dx in [-0.8, 0.0, 0.8]:
		for dz in [-0.8, 0.0, 0.8]:
			var hit := _ray_down(FLOOR_PROBE.x + dx, FLOOR_PROBE.y + dz, 2.4, -0.5)
			if not hit.is_empty():
				lowest = minf(lowest, (hit["position"] as Vector3).y)
	if lowest < INF:
		_floor_y = lowest
	print("caught_cutscene: tinggi lantai y=%.2f" % _floor_y)


func _build_stage() -> void:
	_stage = Node3D.new()
	_stage.name = "CaughtCutsceneStage"
	get_tree().current_scene.add_child(_stage)

	# matahari / lampu arah bawaan peta dimatikan supaya ruangan benar-benar gelap (cuma lampu neon cutscene)
	for n in get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false):
		(n as Node3D).visible = false

	# lampu neon pucat
	_light = OmniLight3D.new()
	_light.omni_range = 14.0
	_light.light_color = Color(0.82, 1.0, 0.88)
	_light.light_energy = LIGHT_ENERGY
	_stage.add_child(_light)
	_light.global_position = _at(LIGHT_XZ, 2.7)

	_build_furniture()
	_build_jennifer()


# Kertas hukuman + tangan player: tergeletak di atas MEJA (dunia 3D), kamera duduk di belakangnya melihat ke bawah.
func _build_paper() -> void:
	_paper = Node3D.new()
	_stage.add_child(_paper)
	_paper.global_position = _at(PAPER_XZ, DESK_TOP + 0.004)
	# rebah di meja: sisi atas kertas menjauh dari player (utara), sisi kanan kertas = sisi kanan player
	_paper.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	_paper.visible = false
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.64, 0.46)
	quad.mesh = qm
	var pm := _mat(Color(0.93, 0.91, 0.83), 0.95)
	pm.emission_enabled = true
	pm.emission = Color(0.30, 0.30, 0.26)
	pm.emission_energy_multiplier = 0.6
	quad.material_override = pm
	_paper.add_child(quad)
	var title := Label3D.new()
	title.text = "REMEDIAL"
	title.font_size = 44
	title.pixel_size = 0.0012
	title.outline_size = 0
	title.shaded = false
	title.modulate = Color(0.75, 0.08, 0.06)
	title.position = Vector3(0.0, 0.195, 0.003)
	_paper.add_child(title)
	_board = Label3D.new()
	_board.text = ""
	_board.font_size = 32
	_board.pixel_size = 0.0010
	_board.outline_size = 0
	_board.shaded = false
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_board.modulate = Color(0.08, 0.08, 0.2)
	_board.position = Vector3(0.0, 0.15, 0.003)
	_paper.add_child(_board)


# Batang silinder dari titik a ke titik b (dipakai untuk pena, jari, lengan).
func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color, radius_b := -1.0) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius if radius_b < 0.0 else radius_b     # ujung b boleh lebih kecil (lengan meruncing)
	cyl.bottom_radius = radius
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 8
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = _mat(color, 0.7)
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0:
		mi.basis = Basis(Vector3.RIGHT, PI)


# Tangan kanan player memegang pena, dilihat dari mata sendiri: asal (0,0,0) = ujung pena di kertas.
# Pena mengarah ke kanan-bawah dan mendekati kamera; lengan baju seragam putih keluar dari bawah-kanan layar.
func _build_hand(parent: Node3D) -> Node3D:
	var hand := Node3D.new()
	parent.add_child(hand)
	var skin := Color(0.86, 0.66, 0.52)
	var d := Vector3(0.45, -0.60, 0.65).normalized()     # arah pena dari ujung ke pangkal
	var side := d.cross(Vector3(0.0, 0.0, 1.0)).normalized()
	var up_n := side.cross(d).normalized()
	var palm := d * 0.20 + up_n * 0.02
	_limb(hand, Vector3.ZERO, d * 0.18, 0.0045, Color(0.08, 0.10, 0.35))                   # pena
	_limb(hand, Vector3.ZERO, d * 0.014, 0.0022, Color(0.05, 0.05, 0.05))                  # ujung pena
	_limb(hand, d * 0.06 + side * 0.016, palm + side * 0.018, 0.0085, skin)                # telunjuk
	_limb(hand, d * 0.055 - side * 0.016, palm - side * 0.018, 0.009, skin)                # ibu jari
	_limb(hand, d * 0.085 + side * 0.03, palm + side * 0.034, 0.0085, skin)                # jari lain melengkung
	var palm_mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	palm_mi.mesh = sm
	palm_mi.material_override = _mat(skin, 0.7)
	palm_mi.position = palm
	palm_mi.scale = Vector3(1.1, 0.8, 1.3)
	hand.add_child(palm_mi)
	var arm := Vector3(0.55, -0.55, 0.55).normalized()
	_limb(hand, palm, palm + arm * 0.08, 0.026, skin)                                      # pergelangan
	_limb(hand, palm + arm * 0.08, palm + arm * 0.55, 0.042, Color(0.92, 0.92, 0.90))      # lengan baju seragam putih
	return hand


func _build_camera() -> void:
	_rig = Node3D.new()
	_stage.add_child(_rig)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.16, 0.20, 0.18)
	_env.ambient_light_energy = 0.8
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.03, 0.05, 0.04)
	_env.fog_density = 0.04
	_cam = Camera3D.new()
	_cam.environment = _env     # lingkungan khusus cutscene, menimpa WorldEnvironment peta
	_cam.fov = 70.0
	_cam.near = 0.05
	_rig.add_child(_cam)
	_rig.global_position = _at(SHOT1_CAM, STAND_EYE)
	_cam.make_current()
	_build_paper()


# ------------------------------------------------------------------ UI

func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 160     # di atas lapisan jumpscare (150)
	add_child(_layer)

	# vignette gelap di pinggir layar
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.85))
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
	vignette.anchor_right = 1.0
	vignette.anchor_bottom = 1.0
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(vignette)

	# bar sinematik atas dan bawah
	var top := ColorRect.new()
	top.color = Color.BLACK
	top.anchor_right = 1.0
	top.anchor_bottom = 0.11
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	bottom.anchor_top = 0.89
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bottom)

	# subtitle dialog (di atas bar bawah)
	_sub_label = _make_label("", 32, Color(1, 1, 1))
	_sub_label.anchor_left = 0.1
	_sub_label.anchor_right = 0.9
	_sub_label.anchor_top = 0.77
	_sub_label.anchor_bottom = 0.88
	_sub_label.add_theme_constant_override("outline_size", 8)
	_sub_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_sub_label.visible = false
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_sub_label)

	# layar hitam untuk fade (mulai penuh hitam), di bawah kartu narasi
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.anchor_right = 1.0
	_black.anchor_bottom = 1.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)

	_card_label = _make_label("", 40, Color(0.88, 0.86, 0.80))
	_card_label.anchor_left = 0.12
	_card_label.anchor_right = 0.88
	_card_label.anchor_bottom = 1.0
	_card_label.modulate.a = 0.0
	_card_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_card_label)

	_hint = Label.new()
	_hint.text = _txt("c_skip", "Press SPACE to skip")
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.modulate = Color(1, 1, 1, 0.45)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -330.0
	_hint.offset_top = -40.0
	_hint.offset_right = -20.0
	_hint.offset_bottom = -10.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_hint)


# ------------------------------------------------------------------ audio

func _bus_name() -> String:
	return "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"


# Musik gameplay (kejar/tegang) dipelankan lalu dibuang supaya cutscene hening.
func _silence_game_music() -> void:
	var host := get_parent()
	if host == null:
		return
	var md := host.get_node_or_null("MusicDirector")
	if md == null:
		return
	md.set_process(false)
	for c in md.get_children():
		if c is AudioStreamPlayer:
			create_tween().tween_property(c, "volume_db", -60.0, 1.2)


# HUD (inventory, prompt, papan soal, dll.) dan potongan kunci yang bersinar disembunyikan selama cutscene.
func _hide_world_ui() -> void:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl != null and cl != _layer and cl.layer < 160:
			cl.visible = false
	var host := get_parent()
	if host != null:
		for c in host.get_children():
			if c is Node3D:
				(c as Node3D).visible = false    # potongan kunci (anak GameFlow)


func _start_ambient() -> void:
	if not ResourceLoader.exists(AMBIENT_PATH):
		return
	var st := load(AMBIENT_PATH) as AudioStream
	if st == null:
		return
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / 2   # 16-bit mono, sama seperti music_director.gd
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_amb = AudioStreamPlayer.new()
	_amb.stream = st
	_amb.bus = _bus_name()
	_amb.volume_db = -50.0
	add_child(_amb)
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", -16.0, 2.5)


func _play(stream: AudioStream, db := 0.0) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# Suara Jennifer dari file yang sudah ada: res://audio/voice_cc0/jennifer_<id>.(ogg|wav|mp3). Tidak ada file = diam.
func _play_voice(id: String) -> void:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/voice_cc0/jennifer_%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			var st := load(path) as AudioStream
			if st != null:
				_play(st, -1.0)
				return


func _build_audio() -> void:
	_snd_bell = _make_bell()
	_snd_tap = _make_tap()
	_snd_chalk = _make_chalk()


func _wav(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav


# Bel sekolah: nada logam bertumpuk dengan getaran cepat, memudar pelan.
func _make_bell() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 3.4)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var env := minf(1.0, t / 0.004) * exp(-t * 1.0)
		var trem := 0.72 + 0.28 * sin(t * TAU * 15.0)
		var s := sin(TAU * 1180.0 * t) * 0.5 + sin(TAU * 1771.0 * t) * 0.3 \
			+ sin(TAU * 2430.0 * t) * 0.2 + sin(TAU * 590.0 * t) * 0.25
		s = s * env * trem * 0.65
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(bytes, rate)


# Ketukan penggaris kayu: "tok" pendek.
func _make_tap() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.2)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var t := float(i) / rate
		var env := minf(1.0, t / 0.002) * exp(-t * 34.0)
		var s := (sin(TAU * 210.0 * t) * 0.8 + sin(TAU * 520.0 * t) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.25) * env
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(bytes, rate)


# Pena menggores kertas: derau kasar yang naik-turun seperti goresan.
func _make_chalk() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.1
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var prev := 0.0
	for i in count:
		var t := float(i) / rate
		var n := rng.randf_range(-1.0, 1.0)
		var hp := n - prev      # tapis nada rendah: tinggal desis kasar
		prev = n
		var stroke := 0.5 + 0.5 * sin(t * TAU * 3.2)
		var env := minf(1.0, t / 0.05) * clampf((dur - t) / 0.25, 0.0, 1.0) * stroke
		bytes.encode_s16(i * 2, int(clampf(hp * 0.45 * env, -1.0, 1.0) * 32767.0))
	return _wav(bytes, rate)
