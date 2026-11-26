extends Node
## CUTSCENE ENDING 2 dari 2: BERHASIL KABUR ("SCHOOL'S OUT").
## Dipanggil game_flow.gd -> on_gate_unlock(gate), tepat saat player memakai Kunci Gerbang (semua buku sudah terkumpul):
##     var cs := Node.new(); cs.set_script(ESCAPE_CUTSCENE); add_child(cs); cs.call("run", gate); await cs.finished
##
## Cerita (+/- 65 detik). Sudut pandang player SELALU orang pertama (kamera = mata player), diselingi potongan ke Jennifer.
##   0. Layar hitam: "Tujuh buku. Satu kunci. Satu gerbang." + detak jantung.
##   1. Di depan gerbang yang digembok. Tangan player gemetar memegang kunci. Meleset dua kali (klik logam), langkah kaki
##      Jennifer makin dekat. Player menoleh: Jennifer muncul di kegelapan halaman, mata menyala, "Target engaged."
##   2. Kunci masuk, KLIK, gembok jatuh berdentang, daun gerbang menjeblak terbuka (ke arah luar).
##   3. LARI. Kamera berguncang, napas memburu, langkah makin cepat, langit mulai terang (fajar). Player menoleh ke belakang:
##      Jennifer berlari mengejar, berteriak, lalu BERHENTI MENDADAK tepat di garis gerbang. Dia tidak bisa keluar.
##   4. Player berhenti, membungkuk, terengah-engah, lalu berbalik: Jennifer kecil di gerbang. "Time over."
##   5. Potong ke Jennifer (sisi luar gerbang, sinar fajar di wajahnya): berteriak, menghantam penggaris ke lantai, mengacak
##      kepala, lalu mendadak dingin: "Tomorrow. Seven o'clock sharp."
##   6. Player menengadah ke matahari terbit: "...I made it." Lonceng hangat berbunyi, layar memutih, lalu kartu ending:
##      "ENDING 2 OF 2 / SCHOOL'S OUT / The bell finally rang for you."
##
## Semua posisi dihitung dari node SchoolGate di peta (arah dalam/luar, lebar, tinggi), jadi kalau gerbangmu dipindah/diputar,
## cutscene ikut menyesuaikan. Tidak butuh aset baru: Jennifer memakai res://characters/jennifer.glb, suaranya memakai file
## di res://audio/voice_cc0 (saw_you, gave_up, rage, calm_down), bunyi lain (detak jantung, langkah, kunci, gembok, derit
## gerbang, napas, lonceng) dibuat dari kode. Pemain bisa melewati dengan SPASI / ENTER / klik.
##
## Kalau daun gerbang ngayun ke arah yang salah di cutscene, ubah GATE_SWING_OUT di bawah.

signal finished

const SUBS := preload("res://scripts/subtitle_data.gd")
## true = semua teks cutscene ini selalu Inggris. false = ikut bahasa subtitle di Options.
const FORCE_ENGLISH := true
## true = daun gerbang membuka ke LUAR (searah arah kabur) selama cutscene. Kalau kelihatan terbalik, ubah ke false.
const GATE_SWING_OUT := true
const JEN_GLB := "res://characters/jennifer.glb"
const FACE_ANGRY := "res://characters/face_angry.png"
const AMBIENT_PATH := "res://audio/music/horror_loop.mp3"

# ---- PENGATURAN (satuan meter; koordinat gerbang: x = kanan, z = + sisi DALAM sekolah, - sisi LUAR)
const EYE := 1.62                       # tinggi mata player saat berdiri/lari
const LOCK_Y_RATIO := 0.55              # tinggi gembok dibanding tinggi gerbang (sama dengan school_gate.gd)
const JEN_FAR_Z := 13.0                 # Jennifer muncul sejauh ini di dalam halaman (dikurangi otomatis kalau ada tembok)
const JEN_STOP_Z := 1.1                 # Jennifer berhenti di sini (tepat di dalam garis gerbang)
const RUN_MAX := 24.0                   # jarak lari maksimal ke luar gerbang
const RUN_SPEED := 5.5                  # kecepatan rata-rata lari (m/detik)

# warna langit: malam -> fajar
const NIGHT_TOP := Color(0.015, 0.025, 0.07)
const NIGHT_HOR := Color(0.05, 0.07, 0.15)
const DAWN_TOP := Color(0.30, 0.46, 0.78)
const DAWN_HOR := Color(1.0, 0.62, 0.36)
const JEN_COL := Color(1.0, 0.78, 0.66)
const ME_COL := Color(0.78, 0.90, 1.0)
const LAMP_ENERGY := 1.9
const RUN_EYE := 1.46                   # tinggi mata saat berlari (sedikit membungkuk)
const GROUND_STEP := 0.75               # jarak antar titik ukur tinggi tanah di jalur lari
const MAX_STEP_UP := 0.35               # tanah boleh naik segini per titik (trotoar/tangga kecil); lebih tinggi dianggap benda (bangku, tiang)
const MAX_STEP_DOWN := 1.0

# efek garis kecepatan di pinggir layar saat berlari
const SPEED_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float t = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float r = length(uv);
	float a = atan(uv.y, uv.x);
	float streak = hash(floor(a * 60.0) + floor(t * 12.0));
	float line = smoothstep(0.82, 1.0, streak) * smoothstep(0.25, 0.65, r);
	COLOR = vec4(1.0, 0.95, 0.9, line * intensity * 0.35);
}
"""

# posisi tangan (relatif kamera). Origin tangan = ujung kunci.
const HAND_LOW := Vector3(0.20, -0.32, -0.38)
const HAND_READY := Vector3(0.06, -0.02, -0.56)

var _gate: Node3D
var _gw := 7.1
var _gh := 4.0
var _fy := 0.0
var _run_dist := RUN_MAX
var _in_free := JEN_FAR_Z

var _skip := false
var _elapsed := 0.0

# dunia
var _stage: Node3D
var _rig: Node3D
var _cam: Camera3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _lamp: OmniLight3D
var _warm: OmniLight3D
var _jlight: OmniLight3D
var _hand: Node3D
var _key: Node3D
var _jen: Node3D
var _jen_anim: AnimationPlayer
var _jen_tw: Tween
var _face_mat: StandardMaterial3D
var _tex_calm: Texture2D
var _tex_angry: Texture2D
var _fade_tw: Tween
var _amb: AudioStreamPlayer

# kamera (diatur lewat variabel ini, diterapkan tiap frame di _process)
var _cpos := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _fov := 70.0
var _shake := 0.0
var _bob := 0.0
var _bob_hz := 1.45
var _bob_ph := 0.0
var _bob_count := 0
var _breath_amp := 0.0
var _tremor := 0.0
var _hand_base := HAND_LOW
var _eye_h := EYE                      # tinggi mata di atas tanah saat lari (diubah pelan-pelan)
var _ground := PackedFloat32Array()    # tinggi tanah sepanjang jalur lari (diukur sebelum cutscene mulai)
var _impact := 0.0                     # hentakan langkah, 1 = baru menapak, meluruh cepat
var _foot_side := 1.0
var _speed_fx := 0.0
var _fx_rect: ColorRect
var _fx_mat: ShaderMaterial
var _arms: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _feet: Node3D                      # kaki + sepatu player (kelihatan saat membungkuk melihat ke bawah)
var _feet_on := false
var _blob: MeshInstance3D              # bayangan bulat lembut di bawah Jennifer (menempelkan dia ke tanah)
var _free_yaw := 0.0                   # arah pandang adegan terakhir (dipilih otomatis ke arah yang lapang)
var _free_pitch := 11.0
var _free_walk := 3.0

# bunyi berulang
var _hb_on := false
var _hb_gap := 0.95
var _hb_db := -8.0
var _hb_t := 0.0
var _steps_on := false
var _jstep_on := false
var _jstep_t := 0.0
var _virt_dist := 30.0
var _flicker := 0.3
var _flick_t := 0.0
var _flick_dim := false

# UI
var _layer: CanvasLayer
var _black: ColorRect
var _white: ColorRect
var _sub_label: Label
var _card_label: Label
var _hint: Label

# bunyi buatan kode
var _snd_heart: AudioStreamWAV
var _snd_step: AudioStreamWAV
var _snd_clink: AudioStreamWAV
var _snd_click: AudioStreamWAV
var _snd_clang: AudioStreamWAV
var _snd_creak: AudioStreamWAV
var _snd_breath: AudioStreamWAV
var _snd_chime: AudioStreamWAV
var _snd_bell: AudioStreamWAV
var _snd_tap: AudioStreamWAV


# ------------------------------------------------------------------ alur utama

func run(gate: Node3D) -> void:
	_gate = gate
	if gate == null:
		finished.emit()
		return
	_gw = float(gate.get("gate_width"))
	_gh = float(gate.get("gate_height"))
	GameState.set_process_unhandled_input(false)
	_build_audio()
	_build_overlay()      # layar langsung hitam penuh
	_silence_game_music()
	_hide_world_ui()
	_freeze_actors()
	await get_tree().physics_frame   # raycast fisika hanya aman setelah frame fisika
	_probe_floor()
	_probe_paths()
	_probe_ground()
	_probe_look()
	_build_world()
	_build_street()
	_build_jennifer()
	_build_hand()
	_build_arms()
	_build_feet()
	_build_blob()
	_start_ambient()
	_aim(_gp(0.55, EYE, 1.9), _gp(0.0, _gh * LOCK_Y_RATIO, 0.09))

	await _wait(0.6)
	await _card("e_card", "Seven notebooks. One key. One gate.", 3.6)
	await _shot_lock()
	await _shot_run()
	await _shot_breath()
	await _shot_jennifer()
	await _shot_free()
	await _ending_card()
	if _amb != null:
		_amb.stop()
	finished.emit()


# 1) di depan gerbang: tangan gemetar, kunci meleset, Jennifer mendekat, KLIK, gerbang terbuka
func _shot_lock() -> void:
	if _skip:
		return
	var lock_p := _gp(0.0, _gh * LOCK_Y_RATIO, 0.09)
	var start := _gp(0.55, EYE, 1.9)
	var near_p := _gp(0.12, _gh * LOCK_Y_RATIO - 0.34, 0.66)
	_aim(start, lock_p)
	_fov = 68.0
	_flicker = 0.35
	_hand.visible = true
	_hand_base = HAND_LOW
	_tremor = 0.004
	_hb_on = true
	_hb_gap = 0.95
	_hb_db = -8.0
	await _fade(0.0, 1.2)

	# melangkah ke gerbang
	var walk := create_tween()
	walk.tween_method(func(k: float) -> void: _aim(start.lerp(near_p, k), lock_p), 0.0, 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	_say_async("e_hurry", "Come on... come on...", 2.2, "", ME_COL)
	await _wait(2.4)
	_hand_to(HAND_READY, 0.8)
	_tremor = 0.007
	await _wait(0.9)

	# meleset #1
	_hand_to(HAND_READY + Vector3(0.05, -0.05, 0.0), 0.22)
	await _wait(0.25)
	_play(_snd_clink, -3.0)
	_pulse(0.006, 0.25)
	_hand_to(HAND_READY + Vector3(0.0, 0.01, 0.0), 0.4)
	_virt_dist = 30.0
	create_tween().tween_property(self, "_virt_dist", 17.0, 5.0)
	_jstep_on = true
	create_tween().tween_property(self, "_hb_gap", 0.62, 3.0)
	await _wait(0.8)
	await _say("where", "Where?", 1.8, "where", JEN_COL, -8.0)

	# meleset #2, makin panik
	_tremor = 0.012
	_hand_to(HAND_READY + Vector3(-0.06, 0.05, 0.0), 0.2)
	await _wait(0.23)
	_play(_snd_clink, -2.0)
	_pulse(0.008, 0.3)
	_hand_to(HAND_READY, 0.35)
	await _wait(0.6)

	# menoleh ke belakang: Jennifer di kegelapan halaman
	var jz := minf(JEN_FAR_Z, _in_free)
	_place_jen(1.0, jz, 0.0, 0.0)
	_jen.visible = true
	_set_face(true)
	_play_anim("angry_idle")
	_hand_to(HAND_LOW, 0.4)
	var look := _aim_angles(near_p, _gp(1.0, 1.55, jz))
	_hb_gap = 0.45
	_look_to(look.x, look.y, 0.45, Tween.TRANS_EXPO, Tween.EASE_OUT)
	await _wait(0.55)
	_say_async("saw_you", "Target engaged.", 2.0, "saw_you", JEN_COL, -4.0)
	_pulse(0.004, 1.0)
	await _wait(1.0)
	_jen_to(1.0, jz - 2.6, 2.4, "walk")     # melangkah pelan, mengintimidasi
	await _wait(1.1)
	var back := _aim_angles(near_p, _gp(0.0, _gh * LOCK_Y_RATIO, 0.09))
	_look_to(back.x, back.y, 0.4, Tween.TRANS_EXPO, Tween.EASE_OUT)
	await _wait(0.4)
	_hand_to(HAND_READY, 0.3)
	await _wait(0.35)
	if _skip:
		return

	# kunci masuk, KLIK
	_tremor = 0.0
	_hand_to(Vector3(0.0, 0.0, -0.60), 0.35)
	await _wait(0.4)
	_play(_snd_clink, -6.0)
	await _wait(0.35)
	create_tween().tween_property(_key, "rotation:z", deg_to_rad(90.0), 0.25)
	await _wait(0.22)
	_play(_snd_click, 0.0)
	_pulse(0.01, 0.3)
	await _wait(0.4)

	# gembok jatuh, gerbang menjeblak
	_lock_drop()
	_hand_to(HAND_LOW, 0.5)
	_gate_open()
	_jen_to(0.8, JEN_STOP_Z, 2.6, "run")     # Jennifer berlari saat gerbang terbuka
	_jstep_on = true
	await _wait(1.0)


# 2) LARI keluar gerbang, langit terang, noleh ke belakang: Jennifer berhenti di garis gerbang
func _shot_run() -> void:
	if _skip:
		return
	var z0 := 0.66
	var z1 := -_run_dist
	var dur := maxf(_run_dist / RUN_SPEED, 5.2)
	# posisi awal kamera (relatif gerbang) supaya peralihan ke gerakan lari mulus, tidak meloncat
	var x0 := (_cpos - _gp(0.0, 0.0, 0.0)).dot(_gate.global_transform.basis.orthonormalized().x)
	var y0 := _cpos.y
	var fwd := _aim_angles(_gp(0.0, EYE, 0.6), _gp(0.0, EYE, -10.0))
	_hand.visible = false
	_hb_gap = 0.34
	_hb_db = -5.0
	_steps_on = true
	_bob_hz = 1.5
	_look_to(fwd.x, fwd.y, 0.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	var bt := create_tween().set_parallel(true)
	bt.tween_property(self, "_bob", 1.0, 0.9)
	bt.tween_property(self, "_fov", 88.0, 2.4).set_trans(Tween.TRANS_SINE)
	bt.tween_property(self, "_eye_h", RUN_EYE, 0.8).set_trans(Tween.TRANS_SINE)
	bt.tween_property(self, "_speed_fx", 1.0, 1.2)
	var mv := create_tween()
	mv.tween_method(_run_step.bind(z0, z1, x0, y0), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dawn(dur + 4.0)
	_shake = 0.004

	# menoleh ke belakang saat berlari: Jennifer menerjang, berteriak, lalu BERHENTI MENDADAK di garis gerbang
	await _wait(0.9)
	if _skip:
		return
	var look_back := _aim_angles(_cpos, _gp(0.0, 1.5, JEN_STOP_Z + 1.0))
	_look_to(look_back.x, look_back.y, 0.5, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_say_async("e_back", "GET BACK HERE!", 2.2, "rage", JEN_COL, -3.0)
	_pulse(0.012, 0.8)
	await _wait(0.8)
	_play(_snd_tap, 4.0)     # Jennifer mengerem di garis gerbang
	_pulse(0.012, 0.4)
	_jstep_on = false
	await _wait(1.3)
	_look_to(fwd.x, fwd.y, 0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await _wait(maxf(dur - 0.9 - 0.8 - 1.3, 0.3))
	if mv.is_valid() and mv.is_running():
		mv.kill()
	_run_step(1.0, z0, z1, 0.0, _cpos.y)
	var calm := create_tween().set_parallel(true)
	calm.tween_property(self, "_speed_fx", 0.0, 0.8)
	calm.tween_property(self, "_eye_h", EYE, 1.0)


# Satu langkah gerak lari: posisi di sepanjang jalur + tinggi mengikuti tanah (dari _ground). Di awal lari dicampur
# dengan posisi kamera sebelumnya (x0, y0) selama ~0,6 detik supaya tidak ada lompatan.
func _run_step(k: float, z0: float, z1: float, x0: float, y0: float) -> void:
	var z := lerpf(z0, z1, k)
	var blend := clampf(k * 8.0, 0.0, 1.0)
	_cpos = _gp(lerpf(x0, 0.0, blend), 0.0, z)
	_cpos.y = lerpf(y0, _ground_at(z) + _eye_h, blend)


# 3) berhenti, membungkuk terengah-engah, berbalik: Jennifer kecil di gerbang
func _shot_breath() -> void:
	if _skip:
		return
	_steps_on = false
	_jstep_on = false
	var bt := create_tween().set_parallel(true)
	bt.tween_property(self, "_bob", 0.0, 0.7)
	bt.tween_property(self, "_fov", 72.0, 1.4)
	# membungkuk, tangan di lutut: kamera turun dan maju sedikit, menunduk melihat sepatu sendiri di tanah
	var yr0 := deg_to_rad(_yaw)
	var lean := Vector3(-sin(yr0), 0.0, -cos(yr0)) * 0.12
	var crouch_pos := _cpos + lean + Vector3(0.0, -0.5, 0.0)
	bt.tween_property(self, "_pitch", 52.0, 0.9).set_trans(Tween.TRANS_SINE)
	bt.tween_property(self, "_cpos", crouch_pos, 0.9).set_trans(Tween.TRANS_SINE)
	_feet_on = true
	create_tween().tween_property(self, "_hb_gap", 0.8, 3.0)
	_breath_amp = 1.0
	_shake = 0.0
	_play(_snd_breath, -3.0)
	await _wait(1.5)
	_play(_snd_breath, -4.0)
	await _wait(1.4)
	if _skip:
		return

	# tegak lagi dan berbalik menghadap gerbang
	var stand_pos := crouch_pos - lean + Vector3(0.0, 0.5, 0.0)
	var gate_look := _aim_angles(stand_pos, _gp(0.0, 1.5, JEN_STOP_Z))
	var up := create_tween().set_parallel(true)
	up.tween_property(self, "_cpos", stand_pos, 1.2).set_trans(Tween.TRANS_SINE)
	up.tween_property(self, "_pitch", gate_look.x, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.tween_property(self, "_yaw", _yaw_near(gate_look.y), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.tween_property(self, "_fov", 52.0, 3.0)
	_breath_amp = 0.5
	await _wait(1.6)
	await _say("gave_up", "Time over.", 2.4, "gave_up", JEN_COL, -4.0)


# 4) potong ke Jennifer: marah, menghantam penggaris, lalu mendadak dingin
func _shot_jennifer() -> void:
	if _skip:
		return
	await _fade(1.0, 0.25)
	_feet_on = false
	_breath_amp = 0.8       # kamera "dipegang tangan": bernapas pelan, tidak meluncur kaku
	_shake = 0.0015
	_hb_on = false
	_jen.visible = true
	_place_jen(0.0, JEN_STOP_Z, 0.0, -6.0)
	_set_face(true)
	_play_anim("angry_idle")
	_jlight.light_energy = 0.6
	var cam_a := _gp(0.9, 1.3, -1.8)
	var cam_b := _gp(0.45, 1.45, -0.7)
	var face_p := _gp(0.0, 1.95, JEN_STOP_Z)
	_aim(cam_a, face_p)
	_roll = 0.0
	_fov = 56.0
	var push := create_tween()
	push.tween_method(func(k: float) -> void: _aim(cam_a.lerp(cam_b, k), face_p), 0.0, 1.0, 7.5).set_trans(Tween.TRANS_SINE)
	await _fade(0.0, 0.4)
	await _wait(0.8)

	# terengah, lalu meledak
	_play_anim("scream")
	_play_voice("rage", -1.0)
	_sub_show("[Screams]", JEN_COL)
	_jitter(2.4)
	await _wait(0.5)
	for i in 3:
		_play(_snd_tap, 5.0)
		_pulse(0.02, 0.35)
		await _wait(0.55)
	_sub_hide()
	await _wait(0.3)

	# lemas, mengerang kesal, lalu dingin
	_play_anim("angry_idle")
	_play_voice("calm_down", -1.0)
	await _wait(1.0)
	_set_face(false)
	await _say("e_tomorrow", "Goodbye.", 3.0, "e_tomorrow", JEN_COL)
	await _wait(0.5)
	push.kill()
	_breath_amp = 0.0
	_shake = 0.0
	await _fade(1.0, 0.3)


# 5) player menengadah ke matahari terbit: lega
func _shot_free() -> void:
	if _skip:
		return
	_hand.visible = false
	_jen.visible = false
	var p := _gp(0.0, 0.0, -_run_dist)
	p.y = _ground_at(-_run_dist) + EYE
	_cpos = p
	_yaw = _free_yaw
	_pitch = 4.0
	_fov = 70.0
	_bob = 0.0
	_breath_amp = 0.35
	_flicker = 0.0
	_shake = 0.0
	await _fade(0.0, 0.8)
	_say_async("e_free", "...I made it. I'm actually out.", 3.4, "", ME_COL)
	var sky := create_tween().set_parallel(true)
	sky.tween_property(self, "_pitch", _free_pitch, 3.0).set_trans(Tween.TRANS_SINE)
	sky.tween_property(self, "_fov", 62.0, 4.5).set_trans(Tween.TRANS_SINE)
	await _wait(1.2)
	_play(_snd_chime, -4.0)
	if _amb != null:
		create_tween().tween_property(_amb, "volume_db", -60.0, 2.0)
	await _wait(1.8)
	# melangkah pelan menjauh dari sekolah, silau
	_steps_on = true
	_bob_hz = 0.95
	create_tween().tween_property(self, "_bob", 0.55, 0.8)
	var walk_from := _cpos
	var walk_to := _cpos + Vector3(-sin(deg_to_rad(_free_yaw)), 0.0, -cos(deg_to_rad(_free_yaw))) * _free_walk
	var wt := create_tween()
	wt.tween_method(func(k: float) -> void: _cpos = walk_from.lerp(walk_to, k), 0.0, 1.0, 3.2)
	await _wait(1.6)
	await _fade_white(1.0, 1.6)
	_steps_on = false
	_play(_snd_bell, -2.0)
	await _wait(1.0)


# 6) kartu ending
func _ending_card() -> void:
	_sub_label.visible = false
	_hint.visible = false
	_card_label.modulate.a = 0.0
	_hb_on = false
	_steps_on = false
	_jstep_on = false
	_black.color.a = 1.0
	if _skip:
		_white.color.a = 0.0

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var small := _make_label(_txt("e_end2", "ENDING 2 OF 2"), 26, Color(0.7, 0.7, 0.68))
	var title := _make_label(_txt("e_end_title", "SCHOOL'S OUT"), 76, Color(0.96, 0.78, 0.32))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var sub := _make_label(_txt("e_end_sub", "The bell finally rang for you."), 30, Color(0.92, 0.9, 0.85))
	var card_w := get_viewport().get_visible_rect().size.x * 0.8
	for lab: Label in [small, title, sub]:
		lab.custom_minimum_size = Vector2(card_w, 0.0)
		lab.modulate.a = 0.0
		box.add_child(lab)

	# putih memudar jadi hitam, kartu muncul
	create_tween().tween_property(_white, "color:a", 0.0, 1.2)
	var tw := create_tween()
	tw.tween_property(small, "modulate:a", 1.0, 0.8).set_delay(0.9)
	tw.tween_property(title, "modulate:a", 1.0, 1.2)
	tw.tween_property(sub, "modulate:a", 0.85, 1.2).set_delay(0.6)
	var hold := 2.5 if _skip else 7.5
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
	if _rig != null and is_instance_valid(_rig) and _cam != null:
		_rig.global_position = _cpos
		_rig.basis = Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), deg_to_rad(_roll)))
		_cam.fov = _fov
		var bob_y := 0.0
		var bob_x := 0.0
		var bob_r := 0.0
		if _bob > 0.0:
			_bob_ph += delta * _bob_hz * TAU
			bob_y = absf(sin(_bob_ph)) * 0.075 * _bob
			bob_x = sin(_bob_ph) * 0.035 * _bob
			bob_r = sin(_bob_ph) * 0.016 * _bob
			var count := int(floor(_bob_ph / PI))
			if count != _bob_count:
				_bob_count = count
				_impact = 1.0                 # kaki menapak: kamera menghentak turun sedikit
				_foot_side = -_foot_side
				if _steps_on:
					_play(_snd_step, -9.0 + 3.0 * _bob)
		var br := sin(_elapsed * 3.3) * _breath_amp
		var s := _shake
		var hit := _impact * _bob
		_impact = move_toward(_impact, 0.0, delta * 6.0)
		_cam.position = Vector3(
			sin(_elapsed * 0.9) * 0.01 + bob_x + randf_range(-1.0, 1.0) * s,
			sin(_elapsed * 1.3) * 0.008 + bob_y - hit * 0.055 + br * 0.035 + randf_range(-1.0, 1.0) * s,
			0.0)
		_cam.rotation = Vector3(
			sin(_elapsed * 0.7) * 0.006 + br * 0.012 - hit * 0.03,
			sin(_elapsed * 0.5) * 0.008 + _foot_side * hit * 0.012,
			sin(_elapsed * 0.4) * 0.01 + bob_r + _foot_side * hit * 0.02 + randf_range(-1.0, 1.0) * s * 0.8)
		# tangan berayun bergantian mengikuti langkah, kelihatan di bawah layar
		if _arms != null:
			_arms.visible = _bob > 0.25
			if _arms.visible:
				var sw := sin(_bob_ph * 0.5) * 0.5 * _bob
				_arm_l.rotation.x = sw
				_arm_r.rotation.x = -sw
		if _blob != null:
			_blob.visible = _jen != null and _jen.visible
			if _blob.visible:
				_blob.global_position = _jen.global_position + Vector3(0.0, 0.03, 0.0)
		if _feet != null:
			_feet.visible = _feet_on
			if _feet_on:
				var yr := deg_to_rad(_yaw)
				var fwd := Vector3(-sin(yr), 0.0, -cos(yr))
				var rel_z := (_cpos - _gp(0.0, 0.0, 0.0)).dot(_gate.global_transform.basis.orthonormalized().z)
				_feet.global_position = Vector3(_cpos.x, _ground_at(rel_z), _cpos.z) + fwd * 0.34
				_feet.rotation.y = yr
		if _fx_rect != null:
			_fx_rect.visible = _speed_fx > 0.01
			if _fx_rect.visible:
				_fx_mat.set_shader_parameter("intensity", _speed_fx)
				_fx_mat.set_shader_parameter("t", _elapsed)
	if _hand != null and is_instance_valid(_hand) and _hand.visible:
		_hand.position = _hand_base + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _tremor
	if _hb_on:
		_hb_t -= delta
		if _hb_t <= 0.0:
			_hb_t = _hb_gap
			_play(_snd_heart, _hb_db)
	if _jstep_on:
		_jstep_t -= delta
		if _jstep_t <= 0.0:
			_jstep_t = 0.3
			_play(_snd_step, clampf(-5.0 - _jen_dist() * 0.8, -40.0, -5.0))
	if _lamp != null and is_instance_valid(_lamp):
		_flick_t -= delta
		if _flick_t <= 0.0:
			_flick_t = randf_range(0.04, 0.22)
			_flick_dim = randf() < _flicker * 0.5
		var e := LAMP_ENERGY
		if _flick_dim and _flicker > 0.0:
			e = LAMP_ENERGY * randf_range(0.05, 0.5)
		_lamp.light_energy = e


# ------------------------------------------------------------------ helper alur & kamera

# Titik di dunia dari koordinat gerbang: x = kanan, y = tinggi dari lantai, z = + sisi DALAM sekolah, - sisi LUAR.
func _gp(x: float, y: float, z: float) -> Vector3:
	var b := _gate.global_transform.basis.orthonormalized()
	var o := _gate.global_position
	return Vector3(o.x, _fy, o.z) + b.x * x + Vector3.UP * y + b.z * z


func _aim(from: Vector3, to: Vector3) -> void:
	_cpos = from
	var a := _aim_angles(from, to)
	_pitch = a.x
	_yaw = _yaw_near(a.y)


# (pitch, yaw) dalam derajat untuk kamera di "from" yang melihat ke "to".
func _aim_angles(from: Vector3, to: Vector3) -> Vector2:
	var d := to - from
	var yaw := rad_to_deg(atan2(-d.x, -d.z))
	var pitch := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	return Vector2(pitch, yaw)


func _yaw_near(target: float) -> float:
	return _yaw + wrapf(target - _yaw, -180.0, 180.0)


func _look_to(pitch: float, yaw: float, secs: float, trans := Tween.TRANS_SINE, easing := Tween.EASE_IN_OUT) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_pitch", pitch, secs).set_trans(trans).set_ease(easing)
	tw.tween_property(self, "_yaw", _yaw_near(yaw), secs).set_trans(trans).set_ease(easing)


func _hand_to(pos: Vector3, secs: float) -> void:
	create_tween().tween_property(self, "_hand_base", pos, secs).set_trans(Tween.TRANS_SINE)


func _pulse(amount: float, secs: float) -> void:
	_shake = amount
	create_tween().tween_property(self, "_shake", 0.0, secs)


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


func _fade_white(alpha: float, secs: float) -> void:
	if _skip:
		_white.color.a = alpha
		return
	create_tween().tween_property(_white, "color:a", alpha, secs)
	await _wait(secs)
	_white.color.a = alpha


# Teks cutscene: Inggris (fallback di kode) kalau FORCE_ENGLISH, kalau tidak ikut bahasa subtitle di Options.
func _txt(id: String, fallback: String) -> String:
	return fallback if FORCE_ENGLISH else SUBS.line(id, fallback)


# Kartu teks di layar hitam (narasi). Selalu tampil walau subtitle dimatikan, karena ini bagian cerita.
func _card(id: String, fallback: String, secs: float) -> void:
	if _skip:
		return
	_card_label.text = _txt(id, fallback)
	_card_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_card_label, "modulate:a", 1.0, 0.9)
	await _wait(secs)
	var out := create_tween()
	out.tween_property(_card_label, "modulate:a", 0.0, 0.6)
	await _wait(0.8)


func _sub_show(text: String, col: Color) -> void:
	_sub_label.text = text
	_sub_label.add_theme_color_override("font_color", col)
	_sub_label.visible = SUBS.enabled()


func _sub_hide() -> void:
	_sub_label.visible = false


# Dialog: subtitle di bawah layar + (opsional) suara dari file yang sudah ada.
func _say(id: String, fallback: String, secs: float, voice := "", col := Color.WHITE, db := -1.0) -> void:
	if _skip:
		return
	if voice != "":
		_play_voice(voice, db)
	_sub_show(_txt(id, fallback), col)
	await _wait(secs)
	_sub_hide()
	await _wait(0.2)


# Sama seperti _say tapi alur utama tidak menunggu.
func _say_async(id: String, fallback: String, secs: float, voice := "", col := Color.WHITE, db := -1.0) -> void:
	_say(id, fallback, secs, voice, col, db)


# ------------------------------------------------------------------ gerbang, gembok, Jennifer

func _lock_drop() -> void:
	var p := _gp(0.0, _gh * LOCK_Y_RATIO, 0.09)
	var real: Variant = _gate.get("_lock")
	if is_instance_valid(real) and real is Node3D:
		p = (real as Node3D).global_position
		(real as Node3D).visible = false
	var copy := Node3D.new()
	_stage.add_child(copy)
	copy.global_position = p
	_box(copy, Vector3(0.22, 0.26, 0.1), Vector3.ZERO, Color(0.9, 0.75, 0.15))
	_box(copy, Vector3(0.1, 0.16, 0.06), Vector3(0, 0.2, 0), Color(0.55, 0.55, 0.6))
	var inside := _gp(0.0, 0.0, 1.0) - _gp(0.0, 0.0, 0.0)
	var land := Vector3(p.x, _fy + 0.13, p.z) + inside * 0.25
	var tw := create_tween().set_parallel(true)
	tw.tween_property(copy, "global_position", land, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(copy, "rotation_degrees:z", 70.0, 0.8)
	get_tree().create_timer(0.38).timeout.connect(func() -> void: _play(_snd_clang, -1.0))


func _gate_open() -> void:
	if GATE_SWING_OUT:
		_gate.set("swing_sign", -1.0)
	_gate.call("open")
	_play(_snd_creak, -4.0)
	_pulse(0.006, 1.4)


func _build_jennifer() -> void:
	if not ResourceLoader.exists(JEN_GLB):
		push_warning("escape_cutscene: %s tidak ditemukan, cutscene tanpa Jennifer." % JEN_GLB)
		_jen = Node3D.new()      # pengganti kosong supaya skrip lain tidak error
		_stage.add_child(_jen)
		_jen.visible = false
		_jlight = OmniLight3D.new()
		_jen.add_child(_jlight)
		return
	var scene := load(JEN_GLB) as PackedScene
	_jen = scene.instantiate() as Node3D
	_jen.scale = Vector3.ONE * 1.3     # sama dengan model_scale di teacher.gd
	_stage.add_child(_jen)
	_jen.visible = false
	_jen_anim = _jen.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _jen_anim != null:
		for n in ["idle", "walk", "run", "angry_idle", "scream"]:
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
	# lampu kecil yang ikut Jennifer supaya sosoknya terbaca di kegelapan
	_jlight = OmniLight3D.new()
	_jlight.omni_range = 7.0
	_jlight.light_color = Color(1.0, 0.85, 0.85)
	_jlight.light_energy = 1.3
	_jlight.position = Vector3(0.0, 2.2, 0.8)
	_jen.add_child(_jlight)


# Letakkan Jennifer di koordinat gerbang (x, z) dan hadapkan ke titik (fx, fz).
func _place_jen(x: float, z: float, fx: float, fz: float) -> void:
	if _jen == null:
		return
	if _jen_tw != null and _jen_tw.is_valid():
		_jen_tw.kill()
	_jen.global_position = _gp(x, 0.0, z)
	_face_toward(_gp(fx, 0.0, fz))


# Jennifer bergerak ke (x, z) dalam sekian detik sambil memainkan animasi.
func _jen_to(x: float, z: float, secs: float, anim: String) -> void:
	if _jen == null:
		return
	if _jen_tw != null and _jen_tw.is_valid():
		_jen_tw.kill()
	var dest := _gp(x, 0.0, z)
	_face_toward(dest)
	_play_anim(anim)
	_jen_tw = create_tween()
	_jen_tw.tween_property(_jen, "global_position", dest, secs)
	if anim == "run":
		_jen_tw.tween_callback(_play_anim.bind("angry_idle"))
		_jen_tw.tween_callback(_face_toward.bind(_gp(0.0, 0.0, -10.0)))


func _face_toward(p: Vector3) -> void:
	if _jen == null:
		return
	var d := p - _jen.global_position
	d.y = 0.0
	if d.length() > 0.01:
		_jen.rotation.y = atan2(d.x, d.z)    # depan model = +Z


func _jen_dist() -> float:
	if _jen != null and _jen.visible:
		return _jen.global_position.distance_to(_cpos)
	return _virt_dist


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


# Jennifer gemetar marah selama sekian detik.
func _jitter(secs: float) -> void:
	if _jen == null:
		return
	var tw := create_tween()
	var steps := int(secs / 0.05)
	for i in steps:
		tw.tween_property(_jen, "rotation:z", deg_to_rad(randf_range(-3.0, 3.0)), 0.05)
	tw.tween_property(_jen, "rotation:z", 0.0, 0.1)


# ------------------------------------------------------------------ dunia

func _ray_down(x: float, z: float, from_y: float, to_y: float) -> Dictionary:
	var space := get_viewport().find_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, to_y, z))
	q.collide_with_areas = false
	return space.intersect_ray(q)


# Tinggi lantai di depan gerbang: diambil dari beberapa titik, dipilih yang paling rendah.
func _probe_floor() -> void:
	var o := _gate.global_position
	var b := _gate.global_transform.basis.orthonormalized()
	_fy = o.y
	var lowest := INF
	for lx: float in [-1.0, 0.0, 1.0]:
		for lz: float in [2.0, 3.5]:
			var p := o + b.x * lx + b.z * lz
			var hit := _ray_down(p.x, p.z, o.y + 2.4, o.y - 0.8)
			if not hit.is_empty():
				lowest = minf(lowest, (hit["position"] as Vector3).y)
	if lowest < INF:
		_fy = lowest
	print("escape_cutscene: tinggi lantai y=%.2f" % _fy)


# Seberapa jauh jalur lari ke luar gerbang dan jalur Jennifer di dalam halaman bebas rintangan.
func _probe_paths() -> void:
	var space := get_viewport().find_world_3d().direct_space_state
	_run_dist = RUN_MAX
	var out_from := _gp(0.0, 1.2, -0.8)
	var q := PhysicsRayQueryParameters3D.create(out_from, _gp(0.0, 1.2, -(RUN_MAX + 6.0)))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_run_dist = clampf(out_from.distance_to(hit["position"] as Vector3) + 0.8 - 2.5, 6.0, RUN_MAX)
	_in_free = JEN_FAR_Z
	var in_from := _gp(0.0, 1.0, 1.6)
	var q2 := PhysicsRayQueryParameters3D.create(in_from, _gp(0.0, 1.0, JEN_FAR_Z + 4.0))
	q2.collide_with_areas = false
	var hit2 := space.intersect_ray(q2)
	if not hit2.is_empty():
		_in_free = clampf(in_from.distance_to(hit2["position"] as Vector3) + 1.6 - 1.5, 5.0, JEN_FAR_Z)
	print("escape_cutscene: jarak lari=%.1f m, jalur Jennifer=%.1f m" % [_run_dist, _in_free])


# Mengukur tinggi tanah di sepanjang jalur lari SEBELUM cutscene mulai (jadi tidak ada raycast saat jalan).
# Sinar hanya ditembak dari 1 m di atas lantai gerbang (atap/dahan tidak ikut), permukaan yang naik > MAX_STEP_UP dianggap benda
# (bangku, tiang) dan diabaikan, lalu dirata-rata supaya kamera tidak tersentak.
func _probe_ground() -> void:
	_ground = PackedFloat32Array()
	var n := int(ceil((_run_dist + 2.0) / GROUND_STEP)) + 1
	var raw: Array[float] = []
	var prev := _fy
	for i in n:
		var z := 1.0 - float(i) * GROUND_STEP
		var p := _gp(0.0, 0.0, z)
		var hit := _ray_down(p.x, p.z, _fy + 1.0, _fy - 1.2)
		var h := prev
		if not hit.is_empty():
			var y := (hit["position"] as Vector3).y
			if y <= prev + MAX_STEP_UP and y >= prev - MAX_STEP_DOWN:
				h = y
		raw.append(h)
		prev = h
	for i in n:
		var a := raw[maxi(i - 1, 0)]
		var b := raw[i]
		var c := raw[mini(i + 1, n - 1)]
		_ground.append((a + b + c) / 3.0)
	print("escape_cutscene: tanah jalur lari y=%.2f .. %.2f (lantai gerbang %.2f)" % [raw.min(), raw.max(), _fy])


# Memilih arah pandang adegan terakhir: arah yang paling lapang (bukan tembok/ujung jalan) dan tidak menghadap balik ke sekolah.
# Kalau semua arah sempit, kamera menengadah ke langit di atas tembok.
func _probe_look() -> void:
	var space := get_viewport().find_world_3d().direct_space_state
	var p := _gp(0.0, 0.0, -_run_dist)
	p.y = _ground_at(-_run_dist) + 1.4
	var out := _gp(0.0, 0.0, -1.0) - _gp(0.0, 0.0, 0.0)
	var best := -INF
	var best_dist := 0.0
	var best_yaw := rad_to_deg(atan2(-out.x, -out.z))
	for i in 16:
		var dir := out.rotated(Vector3.UP, TAU * float(i) / 16.0)
		var q := PhysicsRayQueryParameters3D.create(p, p + dir * 60.0)
		q.collide_with_areas = false
		var hit := space.intersect_ray(q)
		var d := 60.0
		if not hit.is_empty():
			d = p.distance_to(hit["position"] as Vector3)
		var score := minf(d, 40.0) + 10.0 * maxf(dir.dot(out), 0.0)
		if dir.dot(out) < -0.3:
			score -= 100.0
		if score > best:
			best = score
			best_dist = d
			best_yaw = rad_to_deg(atan2(-dir.x, -dir.z))
	_free_yaw = best_yaw
	_free_walk = clampf(best_dist - 1.8, 0.4, 3.0)
	_free_pitch = 11.0 if best_dist >= 14.0 else 24.0
	print("escape_cutscene: arah akhir yaw=%.0f, ruang lapang=%.1f m" % [_free_yaw, best_dist])


# Tinggi tanah di koordinat gerbang z (diinterpolasi dari hasil ukur).
func _ground_at(z: float) -> float:
	if _ground.is_empty():
		return _fy
	var f := clampf((1.0 - z) / GROUND_STEP, 0.0, float(_ground.size() - 1))
	var i := int(floor(f))
	var j := mini(i + 1, _ground.size() - 1)
	return lerpf(_ground[i], _ground[j], f - float(i))


# Pemain & guru asli dibekukan dan disembunyikan supaya tidak mengganggu (dan tidak menangkap player di tengah cutscene).
func _freeze_actors() -> void:
	for t in get_tree().get_nodes_in_group("teacher"):
		t.set_process(false)
		t.set_physics_process(false)
		for a in t.find_children("*", "AudioStreamPlayer3D", true, false):
			(a as AudioStreamPlayer3D).stop()
		for a2 in t.find_children("*", "AudioStreamPlayer", true, false):
			(a2 as AudioStreamPlayer).stop()
		if t is Node3D:
			(t as Node3D).visible = false
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		p.set_process(false)
		p.set_physics_process(false)


func _mat(color: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, 0.6, 0.3)
	mi.position = pos
	parent.add_child(mi)


func _build_world() -> void:
	_stage = Node3D.new()
	_stage.name = "EscapeCutsceneStage"
	get_tree().current_scene.add_child(_stage)

	# matahari / lampu arah bawaan peta dimatikan: cutscene punya langit & cahayanya sendiri
	for n in get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false):
		(n as Node3D).visible = false

	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = NIGHT_TOP
	_sky_mat.sky_horizon_color = NIGHT_HOR
	_sky_mat.ground_horizon_color = NIGHT_HOR
	_sky_mat.ground_bottom_color = Color(0.01, 0.012, 0.02)
	_sky_mat.sun_angle_max = 28.0
	_sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.13, 0.17, 0.27)
	_env.ambient_light_energy = 0.9
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.04, 0.06, 0.1)
	_env.fog_density = 0.012

	# matahari terbit di LUAR gerbang, sinarnya menembak ke dalam sekolah (menerangi wajah Jennifer dari depan)
	var inward := _gp(0.0, 0.0, 1.0) - _gp(0.0, 0.0, 0.0)
	var dir := (inward * cos(deg_to_rad(12.0)) + Vector3.DOWN * sin(deg_to_rad(12.0))).normalized()
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(0.55, 0.65, 1.0)
	_sun.light_energy = 0.05
	_sun.shadow_enabled = true      # bayangan nyata dari matahari fajar: Jennifer & pagar punya bayangan di tanah
	_sun.directional_shadow_max_distance = 45.0
	_stage.add_child(_sun)
	_sun.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _gp(0.0, 10.0, 0.0))

	# lampu neon dingin di dalam sekolah, tepat di atas gerbang
	_lamp = OmniLight3D.new()
	_lamp.omni_range = 14.0
	_lamp.light_color = Color(0.75, 0.9, 1.0)
	_lamp.light_energy = LAMP_ENERGY
	_stage.add_child(_lamp)
	_lamp.global_position = _gp(0.0, _gh + 0.8, 2.2)

	# lampu hangat di luar yang menyala pelan-pelan (rasa lega)
	_warm = OmniLight3D.new()
	_warm.omni_range = 16.0
	_warm.light_color = Color(1.0, 0.75, 0.45)
	_warm.light_energy = 0.0
	_stage.add_child(_warm)
	_warm.global_position = _gp(0.0, 3.4, -4.0)

	_rig = Node3D.new()
	_stage.add_child(_rig)
	_cam = Camera3D.new()
	_cam.environment = _env     # lingkungan khusus cutscene, menimpa WorldEnvironment peta
	_cam.fov = 70.0
	_cam.near = 0.04
	_cam.far = 500.0
	_rig.add_child(_cam)
	_cam.make_current()


# Langit berganti dari malam ke fajar, cahaya matahari dan lampu hangat naik, kabut memudar (rasa lega).
func _dawn(secs: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sky_mat, "sky_top_color", DAWN_TOP, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sky_mat, "sky_horizon_color", DAWN_HOR, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sky_mat, "ground_horizon_color", DAWN_HOR.darkened(0.35), secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sky_mat, "ground_bottom_color", Color(0.12, 0.09, 0.08), secs)
	tw.tween_property(_env, "ambient_light_color", Color(0.62, 0.55, 0.52), secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_env, "fog_light_color", Color(0.85, 0.6, 0.45), secs)
	tw.tween_property(_env, "fog_density", 0.004, secs)
	tw.tween_property(_sun, "light_color", Color(1.0, 0.72, 0.45), secs)
	tw.tween_property(_sun, "light_energy", 1.4, secs).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_warm, "light_energy", 1.6, secs)
	tw.tween_property(self, "_flicker", 0.0, secs * 0.5)


# Tangan kanan player memegang kunci, dilihat dari mata sendiri. Origin (0,0,0) = ujung kunci, kunci menghadap -Z (menjauh dari kamera).
func _build_hand() -> void:
	_hand = Node3D.new()
	_hand.position = HAND_LOW
	_cam.add_child(_hand)
	_hand_base = HAND_LOW
	var skin := Color(0.86, 0.66, 0.52)
	var brass := Color(0.88, 0.70, 0.22)
	_key = Node3D.new()
	_hand.add_child(_key)
	_limb(_key, Vector3.ZERO, Vector3(0.0, 0.0, 0.09), 0.0055, brass)                    # batang kunci
	for i in 3:
		_limb(_key, Vector3(0.0, 0.0, 0.012 + i * 0.016), Vector3(0.0, -0.014, 0.012 + i * 0.016), 0.0045, brass)   # gigi kunci
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.010
	tm.outer_radius = 0.024
	ring.mesh = tm
	ring.material_override = _mat(brass, 0.35, 0.8)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.position = Vector3(0.0, 0.0, 0.115)
	_key.add_child(ring)
	var palm := Vector3(0.0, -0.012, 0.19)
	var fist := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	fist.mesh = sm
	fist.material_override = _mat(skin, 0.7)
	fist.position = palm
	fist.scale = Vector3(1.0, 0.9, 1.35)
	_hand.add_child(fist)
	_limb(_hand, palm + Vector3(0.012, 0.012, -0.045), Vector3(0.0, 0.0, 0.125), 0.0085, skin)       # jari menjepit kunci
	_limb(_hand, palm + Vector3(-0.015, 0.012, -0.04), Vector3(0.0, 0.0, 0.14), 0.009, skin)         # ibu jari
	var wrist := palm + Vector3(0.015, -0.01, 0.06)
	var sleeve_end := Vector3(0.10, -0.19, 0.64)
	_limb(_hand, palm, wrist, 0.026, skin)                                                          # pergelangan
	_limb(_hand, wrist, sleeve_end, 0.043, Color(0.92, 0.92, 0.90))                                  # lengan baju seragam putih
	_hand.visible = false


# Jalan di luar gerbang, dibuat dari kode dan hanya ada di cutscene ini (peta aslimu tidak diubah). Lantai peta berhenti tidak jauh dari gerbang,
# jadi tanpa ini player berlari di atas kekosongan. Jalan dipasang 3 cm DI BAWAH lantai terakhir: di tempat lantai peta masih ada
# jalan ini tertutup, di tempat lantai peta habis jalan ini yang kelihatan, tanpa celah. Di kejauhan ada trotoar, marka, tiang lampu,
# pohon, dan siluet gedung yang memudar di kabut fajar. Koordinat lokal: x = kanan, -z = ke arah luar.
func _build_street() -> void:
	var y := _fy
	if not _ground.is_empty():
		y = _ground[_ground.size() - 1]
	var st := Node3D.new()
	st.name = "Street"
	_stage.add_child(st)
	st.global_transform = Transform3D(_gate.global_transform.basis.orthonormalized(), Vector3(_gate.global_position.x, y - 0.03, _gate.global_position.z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	# tanah luas di bawah semuanya (rumput/tanah gelap) supaya tepi dunia tidak kelihatan
	_slab(st, Vector3(500.0, 0.2, 420.0), Vector3(0.0, -0.13, -190.0), Color(0.16, 0.15, 0.12))
	# aspal + trotoar kiri-kanan
	_slab(st, Vector3(14.0, 0.2, 260.0), Vector3(0.0, -0.1, -130.5), Color(0.15, 0.15, 0.17))
	for sx: float in [-1.0, 1.0]:
		_slab(st, Vector3(3.2, 0.2, 252.0), Vector3(sx * 8.6, 0.05, -134.0), Color(0.46, 0.43, 0.40))
	# marka jalan putus-putus di tengah + garis tepi
	for i in 40:
		_slab(st, Vector3(0.16, 0.02, 2.4), Vector3(0.0, 0.005, -4.0 - float(i) * 6.0), Color(0.92, 0.86, 0.55))
	for sx: float in [-1.0, 1.0]:
		_slab(st, Vector3(0.12, 0.02, 252.0), Vector3(sx * 6.5, 0.005, -134.0), Color(0.8, 0.8, 0.78))
	# tiang lampu jalan + pohon di tepi trotoar
	for i in 10:
		var z := -14.0 - float(i) * 20.0
		for sx: float in [-1.0, 1.0]:
			var pole := Node3D.new()
			st.add_child(pole)
			pole.position = Vector3(sx * 9.6, 0.0, z - (6.0 if sx > 0.0 else 0.0))
			_slab(pole, Vector3(0.14, 5.4, 0.14), Vector3(0.0, 2.7, 0.0), Color(0.12, 0.12, 0.13))
			_slab(pole, Vector3(0.9, 0.12, 0.3), Vector3(-sx * 0.4, 5.4, 0.0), Color(0.12, 0.12, 0.13))
			if i < 3:
				var lamp := OmniLight3D.new()
				lamp.omni_range = 11.0
				lamp.light_color = Color(1.0, 0.78, 0.5)
				lamp.light_energy = 1.1
				lamp.position = Vector3(-sx * 0.7, 5.1, 0.0)
				pole.add_child(lamp)
	for i in 14:
		for sx: float in [-1.0, 1.0]:
			var tz := -8.0 - float(i) * 13.0 - rng.randf_range(0.0, 5.0)
			var tree := Node3D.new()
			st.add_child(tree)
			tree.position = Vector3(sx * rng.randf_range(11.0, 12.5), 0.0, tz)
			_slab(tree, Vector3(0.35, 3.0, 0.35), Vector3(0.0, 1.5, 0.0), Color(0.2, 0.14, 0.1))
			var crown := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r := rng.randf_range(1.8, 2.6)
			sm.radius = r
			sm.height = r * 1.7
			crown.mesh = sm
			crown.material_override = _mat(Color(0.08, 0.17, 0.1).lerp(Color(0.16, 0.2, 0.08), rng.randf()), 0.95)
			crown.position = Vector3(0.0, 3.6 + r * 0.5, 0.0)
			tree.add_child(crown)
	# siluet gedung di kejauhan (kiri-kanan jalan), makin jauh makin tinggi, memudar di kabut
	for i in 16:
		for sx: float in [-1.0, 1.0]:
			var w := rng.randf_range(9.0, 16.0)
			var d := rng.randf_range(10.0, 18.0)
			var h := rng.randf_range(7.0, 12.0) + float(i) * 0.9
			var bz := -26.0 - float(i) * 15.0 - rng.randf_range(0.0, 6.0)
			var bx := sx * (20.0 + d * 0.5 + rng.randf_range(0.0, 8.0))
			var tint := rng.randf_range(0.8, 1.2)
			_slab(st, Vector3(d, h, w), Vector3(bx, h * 0.5, bz), Color(0.2, 0.17, 0.2) * tint)
			if rng.randf() < 0.5:     # beberapa jendela menyala hangat
				for k in 3:
					_slab(st, Vector3(0.1, 0.9, 1.2), Vector3(bx - sx * (d * 0.5 + 0.02), 2.0 + float(k) * 2.4, bz + rng.randf_range(-w * 0.3, w * 0.3)), Color(1.0, 0.75, 0.4))


# Balok tanpa kilap (aspal, tembok, tiang) untuk jalan di luar gerbang.
func _slab(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, 0.95)
	mi.position = pos
	parent.add_child(mi)


# Kaki player (celana abu-abu + sepatu hitam) yang menapak di tanah. Hanya kelihatan saat kamera menunduk (membungkuk terengah-engah).
func _build_feet() -> void:
	_feet = Node3D.new()
	_feet.visible = false
	_stage.add_child(_feet)
	var pants := Color(0.33, 0.34, 0.38)
	var shoe := Color(0.07, 0.06, 0.06)
	for sx: float in [-1.0, 1.0]:
		_box(_feet, Vector3(0.11, 0.07, 0.27), Vector3(sx * 0.11, 0.035, -0.06), shoe)
		_limb(_feet, Vector3(sx * 0.11, 0.08, 0.06), Vector3(sx * 0.12, 0.95, 0.42), 0.075, pants)


# Bayangan bulat lembut di tanah di bawah Jennifer, supaya dia kelihatan berpijak (bukan melayang).
func _build_blob() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	q.orientation = PlaneMesh.FACE_Y
	_blob = MeshInstance3D.new()
	_blob.mesh = q
	_blob.material_override = m
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob.visible = false
	_stage.add_child(_blob)


# Dua lengan player (lengan baju putih + kepalan) di bawah layar, berayun bergantian saat berlari.
func _build_arms() -> void:
	_arms = Node3D.new()
	_arms.visible = false
	_cam.add_child(_arms)
	_arm_l = _make_arm(-1.0)
	_arm_r = _make_arm(1.0)


func _make_arm(side: float) -> Node3D:
	var arm := Node3D.new()
	arm.position = Vector3(side * 0.23, -0.30, 0.02)     # siku
	_arms.add_child(arm)
	var skin := Color(0.86, 0.66, 0.52)
	var sleeve := Color(0.92, 0.92, 0.90)
	_limb(arm, Vector3.ZERO, Vector3(-side * 0.03, 0.06, -0.30), 0.042, sleeve)       # lengan bawah, ditekuk ke depan
	_limb(arm, Vector3.ZERO, Vector3(side * 0.04, -0.12, 0.5), 0.05, sleeve)          # lengan atas ke belakang
	var fist := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.09
	fist.mesh = sm
	fist.material_override = _mat(skin, 0.7)
	fist.position = Vector3(-side * 0.035, 0.075, -0.34)
	arm.add_child(fist)
	return arm


# Batang silinder dari titik a ke titik b (dipakai untuk kunci, jari, lengan).
func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
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
	_layer.layer = 160     # di atas HUD dan lapisan lain
	add_child(_layer)

	# vignette gelap di pinggir layar
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.8))
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

	# garis kecepatan di pinggir layar (hanya tampil saat berlari)
	_fx_rect = ColorRect.new()
	_fx_rect.color = Color.WHITE
	_fx_rect.anchor_right = 1.0
	_fx_rect.anchor_bottom = 1.0
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SPEED_SHADER
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = sh
	_fx_rect.material = _fx_mat
	_fx_rect.visible = false
	_layer.add_child(_fx_rect)

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

	# layar hitam untuk fade (mulai penuh hitam), lalu layar putih untuk silau matahari
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.anchor_right = 1.0
	_black.anchor_bottom = 1.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	_white = ColorRect.new()
	_white.color = Color(1, 0.97, 0.9, 0)
	_white.anchor_right = 1.0
	_white.anchor_bottom = 1.0
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_white)

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


func _start_ambient() -> void:
	if not ResourceLoader.exists(AMBIENT_PATH):
		return
	var st := load(AMBIENT_PATH) as AudioStream
	if st == null:
		return
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_amb = AudioStreamPlayer.new()
	_amb.stream = st
	_amb.bus = _bus_name()
	_amb.volume_db = -50.0
	add_child(_amb)
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", -17.0, 2.5)


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
func _play_voice(id: String, db := -1.0) -> void:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/voice_cc0/jennifer_%s.%s" % [id, ext]
		var st: AudioStream = null
		if ResourceLoader.exists(path):
			st = load(path) as AudioStream
		elif ext == "ogg" and FileAccess.file_exists(path):
			st = AudioStreamOggVorbis.load_from_file(path)   # belum ke-import: baca file langsung
		if st != null:
			_play(st, db)
			return


func _build_audio() -> void:
	_snd_heart = _make_heart()
	_snd_step = _make_step()
	_snd_clink = _make_clink()
	_snd_click = _make_click()
	_snd_clang = _make_clang()
	_snd_creak = _make_creak()
	_snd_breath = _make_breath()
	_snd_chime = _make_chime([659.0, 784.0, 1047.0, 1319.0], 0.34, 5.0)
	_snd_bell = _make_chime([523.0, 523.0], 1.1, 4.5)
	_snd_tap = _make_tap()


func _wav(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav


func _put(bytes: PackedByteArray, i: int, s: float) -> void:
	bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))


# Detak jantung: "dug-dug" rendah.
func _make_heart() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.55)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var s := exp(-t * 22.0) * sin(TAU * 58.0 * t)
		var t2 := t - 0.19
		if t2 > 0.0:
			s += exp(-t2 * 26.0) * sin(TAU * 50.0 * t2) * 0.75
		_put(bytes, i, s * minf(1.0, t / 0.004) * 0.9)
	return _wav(bytes, rate)


# Langkah kaki di aspal: derau teredam + dentum rendah.
func _make_step() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.14)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var prev := 0.0
	for i in count:
		var t := float(i) / rate
		prev += (rng.randf_range(-1.0, 1.0) - prev) * 0.25
		var s := (prev * 1.6 + sin(TAU * 90.0 * t) * 0.5) * exp(-t * 38.0)
		_put(bytes, i, s * minf(1.0, t / 0.002))
	return _wav(bytes, rate)


# Kunci beradu dengan logam: "tink" tinggi.
func _make_clink() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.28)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var s := (sin(TAU * 2300.0 * t) * 0.5 + sin(TAU * 3100.0 * t) * 0.35 + sin(TAU * 4700.0 * t) * 0.2) * exp(-t * 26.0)
		_put(bytes, i, s * minf(1.0, t / 0.0015) * 0.7)
	return _wav(bytes, rate)


# Gembok terbuka: "tik... KLAK".
func _make_click() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.3)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in count:
		var t := float(i) / rate
		var s := 0.0
		s += (rng.randf_range(-1.0, 1.0) * 0.6 + sin(TAU * 1800.0 * t) * 0.4) * exp(-t * 120.0) * 0.6
		var t2 := t - 0.11
		if t2 > 0.0:
			s += (rng.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 900.0 * t2) * 0.6 + sin(TAU * 2600.0 * t2) * 0.3) * exp(-t2 * 55.0)
		_put(bytes, i, s)
	return _wav(bytes, rate)


# Gembok jatuh ke aspal: dentang logam.
func _make_clang() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 1.0)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in count:
		var t := float(i) / rate
		var s := sin(TAU * 620.0 * t) * 0.5 * exp(-t * 5.0) + sin(TAU * 1130.0 * t) * 0.4 * exp(-t * 7.0) \
			+ sin(TAU * 1790.0 * t) * 0.3 * exp(-t * 9.0) + sin(TAU * 2650.0 * t) * 0.2 * exp(-t * 12.0)
		s += rng.randf_range(-1.0, 1.0) * 0.4 * exp(-t * 60.0)
		_put(bytes, i, s * minf(1.0, t / 0.001) * 0.7)
	return _wav(bytes, rate)


# Derit engsel gerbang besi.
func _make_creak() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.7
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ph := 0.0
	var prev := 0.0
	for i in count:
		var t := float(i) / rate
		var f := 95.0 + 40.0 * sin(t * 7.0) + t * 30.0
		ph += f / rate
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		prev += ((saw * 0.5 + rng.randf_range(-1.0, 1.0) * 0.12) - prev) * 0.35
		var env := pow(sin(PI * t / dur), 0.6) * 0.8
		_put(bytes, i, prev * env)
	return _wav(bytes, rate)


# Napas terengah: desis naik lalu turun.
func _make_breath() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.3
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var prev := 0.0
	for i in count:
		var t := float(i) / rate
		prev += (rng.randf_range(-1.0, 1.0) - prev) * 0.18
		var env := pow(sin(PI * t / dur), 2.0) * (0.75 + 0.25 * sin(t * TAU * 5.0))
		_put(bytes, i, prev * env * 0.9)
	return _wav(bytes, rate)


# Ketukan penggaris kayu yang dihantam ke lantai.
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
		_put(bytes, i, s)
	return _wav(bytes, rate)


# Lonceng hangat: tiap nada = nada dasar + dua harmonik yang memudar pelan. Dipakai untuk rasa lega dan bel terakhir.
func _make_chime(freqs: Array, gap: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var s := 0.0
		for k in freqs.size():
			var tn := t - gap * k
			if tn <= 0.0:
				continue
			var f := float(freqs[k])
			s += (sin(TAU * f * tn) * 0.5 + sin(TAU * f * 2.0 * tn) * 0.22 * exp(-tn * 1.2) + sin(TAU * f * 3.01 * tn) * 0.1 * exp(-tn * 2.4)) \
				* exp(-tn * 0.9) * minf(1.0, tn / 0.004)
		_put(bytes, i, s * 0.42)
	return _wav(bytes, rate)
