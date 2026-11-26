extends Node
## Cutscene pembuka "AFTER THE BELL" di lantai 1. Dibuat otomatis oleh game_flow.gd (nggak perlu dipasang manual).
##
## Urutan (sekitar 55 detik, bisa dilewati dengan SPASI atau ENTER):
##   1. Layar hitam: chat dari temanmu (buku catatannya ketinggalan di sekolah).
##   2. Gerbang sekolah dari luar, kamera naik melewati gerbang lalu terbang di atas SELURUH peta lantai 1
##      (label ruangan muncul), kemudian meluncur turun sampai tepat di posisi mata player di lapangan.
##   3. Bu Jennifer berdiri membelakangi, celingak-celinguk, menoleh, melambai, dan menyapa
##      (suara + subtitle sama dengan intro lama, diambil dari intro_lines di game_flow.gd).
##   4. Wajahnya berubah, judul muncul, potong ke hitam, lalu game dimulai.
##
## Semua titik kamera DIHITUNG dari node di scene (SchoolGate, Player, Jennifer, kelas*, ruang guru, Ruang Lab,
## Toilet, BasketballCourt), jadi kalau petamu diubah, cutscene ikut menyesuaikan.
##
## Cara pakai (sudah dipasang di game_flow.gd):
##   cover(root, jennifer)                  -> layar langsung hitam (dipanggil paling awal)
##   run(jennifer, intro_lines, detik)      -> mulai, lalu tunggu sinyal "finished"

signal finished

# ==================================================================== TEKS & PENGATURAN (edit di sini)
const TITLE_TEXT := "AFTER\nTHE BELL"
const TITLE_SUB := "SMKN 21 JAKARTA"
const SUBS := preload("res://scripts/subtitle_data.gd")

## Bahasa teks cutscene (chat, narasi, label peta). "en" = selalu Inggris. Kosongkan ("") kalau mau mengikuti bahasa di Options.
const FORCE_LANG := "en"

## ---- Semua teks cutscene ada di sini, 4 bahasa (ikut pilihan bahasa di Options, sama seperti subtitle Bu Jennifer).
## Kalau mau ubah kalimat, edit di tabel ini. Jangan pakai emoji (font bawaan Godot nggak punya glyph-nya). Pakai T_T dan sejenisnya.
const TXT := {
	"contact":  {"en": "Careless One", "id": "Si Ceroboh", "pt": "O Descuidado", "zh": "粗心鬼"},
	"clock":    {"en": "19:47", "id": "19.47", "pt": "19:47", "zh": "19:47"},
	"typing":   {"en": "typing...", "id": "mengetik...", "pt": "digitando...", "zh": "正在输入..."},
	"online":   {"en": "online", "id": "online", "pt": "online", "zh": "在线"},
	"type_hint": {"en": "Type a message", "id": "Ketik pesan", "pt": "Digite uma mensagem", "zh": "输入消息"},
	"skip":     {"en": "[SPACE]  Skip", "id": "[SPASI]  Lewati", "pt": "[ESPAÇO]  Pular", "zh": "[空格]  跳过"},
	"room_class":    {"en": "CLASS", "id": "KELAS", "pt": "SALA", "zh": "教室"},
	"room_teachers": {"en": "TEACHERS' ROOM", "id": "RUANG GURU", "pt": "SALA DOS PROFESSORES", "zh": "教师办公室"},
	"room_lab":      {"en": "LAB ROOM", "id": "RUANG LAB", "pt": "LABORATÓRIO", "zh": "实验室"},
	"room_toilet":   {"en": "TOILET", "id": "TOILET", "pt": "BANHEIRO", "zh": "厕所"},
	"court":    {"en": "COURT", "id": "LAPANGAN", "pt": "QUADRA", "zh": "球场"},
	"gate":     {"en": "GATE", "id": "GERBANG", "pt": "PORTÃO", "zh": "校门"},
	"you":      {"en": "YOU", "id": "KAMU", "pt": "VOCÊ", "zh": "你"},
}

## Chat di awal. Pengirim + lama "mengetik" + lama dibaca (detik); teksnya per bahasa ada di CHAT_TEXT (urutannya sama).
const CHAT_META := [
	["them", 0.6, 0.9], ["them", 0.8, 1.5], ["me", 0.4, 1.0], ["them", 0.8, 1.3],
	["them", 0.7, 1.2], ["me", 0.3, 0.8], ["them", 0.8, 1.6],
]
const CHAT_TEXT := {
	"en": ["HEY. you're still awake right??", "I left my notebooks at school. all of them, 7 books T_T", "...right now? it's so late",
		"yes right now!! they're due tomorrow. I'll buy you iced tea", "oh and be careful of Ms. Jennifer", "why?", "just don't run into her. bye!"],
	"id": ["WOI. kamu masih melek kan??", "buku catatanku ketinggalan di sekolah. semuanya, 7 buku T_T", "...sekarang? ini udah malam banget",
		"iya sekarang!! besok dikumpulin. nanti kutraktir es teh", "oh iya, hati-hati sama Bu Jennifer", "kenapa?", "pokoknya jangan sampai ketemu dia. dadah!"],
	"pt": ["EI. você ainda está acordado, né??", "esqueci meus cadernos na escola. todos, 7 cadernos T_T", "...agora? já está tão tarde",
		"sim, agora!! é pra amanhã. eu te pago um chá gelado", "ah, e cuidado com a professora Jennifer", "por quê?", "só não dê de cara com ela. tchau!"],
	"zh": ["喂。你还没睡吧？？", "我把笔记本落在学校了。全部，7本 T_T", "……现在？都这么晚了",
		"对，现在！！明天就要交了。我请你喝冰茶", "对了，小心詹妮弗老师", "为什么？", "反正别被她撞见。拜拜！"],
}

## Narasi tiap shot. Waktu: [mulai di detik ke-, tampil berapa detik]; teks per bahasa ada di NARR_TEXT (urutannya sama).
const NARR_TIMES := {
	"gate": [[0.7, 2.6], [3.5, 3.0]],
	"aerial": [[0.6, 4.6], [5.8, 4.2]],
	"descent": [[0.3, 2.4], [2.9, 3.0]],
}
const NARR_TEXT := {
	"en": {"gate": ["SMKN 21 Jakarta. It is %s.", "The final bell rang a long time ago."],
		"aerial": ["Your friend's seven notebooks were left inside,\nscattered across the school.", "Find them all, then leave through the gate."],
		"descent": ["The school is quiet...", "...but you are not alone."]},
	"id": {"gate": ["SMKN 21 Jakarta. Pukul %s.", "Bel pulang sudah berbunyi sejak lama."],
		"aerial": ["Tujuh buku catatan temanmu tertinggal di dalam,\ntersebar di seluruh sekolah.", "Temukan semuanya, lalu keluar lewat gerbang."],
		"descent": ["Sekolah ini sunyi...", "...tapi kamu tidak sendirian."]},
	"pt": {"gate": ["SMKN 21 Jacarta. São %s.", "O último sinal tocou há muito tempo."],
		"aerial": ["Os sete cadernos do seu amigo ficaram lá dentro,\nespalhados pela escola.", "Encontre todos e saia pelo portão."],
		"descent": ["A escola está em silêncio...", "...mas você não está sozinho."]},
	"zh": {"gate": ["SMKN 21 雅加达。现在是%s。", "放学铃声早就响过了。"],
		"aerial": ["你朋友的七本笔记本落在了学校里，\n散落在各个角落。", "找到它们，然后从大门离开。"],
		"descent": ["学校一片寂静……", "……但你并不孤单。"]},
}

var chat_lines: Array = []
var lines_gate: Array = []
var lines_aerial: Array = []
var lines_descent: Array = []


func _init() -> void:
	_load_texts()


## Teks umum sesuai bahasa pilihan pemain (Options > subtitle language).
func _lang() -> String:
	return FORCE_LANG if FORCE_LANG != "" else SUBS.lang_code()


func _t(key: String) -> String:
	var d: Dictionary = TXT[key]
	return str(d.get(_lang(), d["en"]))


func _load_texts() -> void:
	var lc: String = _lang()
	var msgs: Array = CHAT_TEXT.get(lc, CHAT_TEXT["en"])
	chat_lines = []
	for i in CHAT_META.size():
		chat_lines.append([CHAT_META[i][0], msgs[i], CHAT_META[i][1], CHAT_META[i][2]])
	var narr: Dictionary = NARR_TEXT.get(lc, NARR_TEXT["en"])
	var clock := _t("clock")
	lines_gate = _build_narr("gate", narr, clock)
	lines_aerial = _build_narr("aerial", narr, clock)
	lines_descent = _build_narr("descent", narr, clock)


func _build_narr(key: String, narr: Dictionary, clock: String) -> Array:
	var out: Array = []
	var times: Array = NARR_TIMES[key]
	var texts: Array = narr[key]
	for i in times.size():
		out.append([times[i][0], times[i][1], str(texts[i]).replace("%s", clock)])
	return out

# palet sama dengan main menu
const BONE := Color(0.93, 0.91, 0.86)
const BLOOD := Color(0.92, 0.18, 0.18)
const NARRATOR := Color(0.88, 0.92, 1.0)
const JENNIFER_COLOR := Color(1.0, 0.82, 0.7)
const NIGHT_TINT := Color(0.03, 0.05, 0.14, 0.30)
const PIANO_PATH := "res://audio/musicbox3_sad_tune.ogg"   # musik cutscene pembuka (kotak musik Sad Tune)
const SKIP_GRACE := 1.0       ## detik pertama nggak bisa di-skip (supaya klik ganda dari menu nggak langsung melewati)
const MAX_SECONDS := 150.0    ## pengaman: kalau cutscene macet selama ini, otomatis selesai
const MAX_VISIBLE_MSGS := 6
## Scene lantai 1 nggak punya lampu / WorldEnvironment sama sekali (dan project.godot juga nggak punya environment bawaan),
## jadi selama cutscene dipasang cahaya bulan + ambient biru SEMENTARA supaya peta kelihatan. Dihapus lagi sebelum game mulai,
## jadi tampilan gameplay-mu nggak berubah. Otomatis nggak dipasang kalau scene-mu nanti sudah punya lampu / environment sendiri.
const USE_NIGHT_LIGHT := true

# ==================================================================== STATE
var _root: Node
var _player: CharacterBody3D
var _pcam: Camera3D
var _jen: CharacterBody3D
var _jen_model: Node3D
var _jen_anim: AnimationPlayer
var _jen_layer := 1
var _jen_mask := 3
var _cam: Camera3D
var _night_env: WorldEnvironment
var _moon: DirectionalLight3D
var _vp := Vector2(1920, 1080)

var _intro_lines := PackedStringArray()
var _line_secs := 2.8

var _clock := 0.0
var _skipping := false
var _skip_t := 0.0
var _ended := false
var _frozen := false
var _reveal_ready := false

# kamera
var _shot_on := false
var _shot_t := 0.0
var _shot_len := 1.0
var _shot_mode := 0          # 0 linear, 1 halus, 2 melambat di akhir
var _sway := 0.0
var _a := Vector3.ZERO
var _c := Vector3.ZERO
var _b := Vector3.ZERO
var _la := Vector3.ZERO
var _lb := Vector3.ZERO
var _fa := 60.0
var _fb := 60.0

# titik penting dari peta
var _gate := Vector3(45, 0, 44)
var _out := Vector3(1, 0, 0)       ## arah KELUAR gerbang
var _center := Vector3.ZERO
var _radius := 50.0
var _eye := Vector3.ZERO
var _head := Vector3.ZERO
var _jen_pos := Vector3.ZERO
var _face_ang := 0.0
var _pfov := 75.0

# UI
var _layers: Array[CanvasLayer] = []
var _layer_fx: CanvasLayer
var _layer_bars: CanvasLayer
var _layer_black: CanvasLayer
var _layer_top: CanvasLayer
var _tint: ColorRect
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _bar_h := 100.0
var _sub: Label
var _sub_id := 0
var _black: ColorRect
var _flash: ColorRect
var _hint: Label
var _title_box: Control
var _phone: Control
var _phone_w := 400.0
var _msgs: VBoxContainer
var _status: Label
var _places: Array = []
var _places_alpha := 0.0

# audio
var _piano: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _sfx_list: Array[AudioStreamPlayer] = []
var _snd_ding_a: AudioStreamWAV
var _snd_ding_b: AudioStreamWAV
var _snd_boom: AudioStreamWAV
var _snd_riser: AudioStreamWAV
var _snd_wind: AudioStreamWAV


# ==================================================================== ENTRY
## Dipanggil game_flow.gd paling awal: layar langsung hitam supaya pemain nggak sempat melihat dunia.
func cover(scene_root: Node, jen: Node) -> void:
	_force_subtitle_lang()
	_load_texts()   # jaga-jaga kalau _init belum jalan saat script dipasang lewat set_script
	_root = scene_root
	_jen = jen as CharacterBody3D
	_build_overlay()
	_black.color.a = 1.0
	if _jen != null:
		# Jennifer dibekukan dan "dihilangkan" dari tabrakan dulu, biar player yang jatuh dari atas nggak mendarat di kepalanya.
		_jen_layer = _jen.collision_layer
		_jen_mask = _jen.collision_mask
		_jen.collision_layer = 0
		_jen.collision_mask = 0
		_jen.set_physics_process(false)


func run(jen: Node, lines: PackedStringArray, line_seconds: float) -> void:
	_force_subtitle_lang()
	_load_texts()
	await get_tree().process_frame   # penting: supaya sinyal finished nggak keburu keluar sebelum ditunggu game_flow
	_intro_lines = lines
	_line_secs = line_seconds
	if jen != null and _jen == null:
		_jen = jen as CharacterBody3D
	if _root == null:
		_root = get_tree().current_scene
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	await _prepare()
	if not _skipping:
		await _play()
	await _finish()


## Subtitle Jennifer di cutscene pembuka (sapaan "Ready?" + intro1..3) selalu Inggris, sama seperti suaranya.
## Setelah cutscene selesai dikembalikan ke bahasa pilihan di Options (lihat _restore_subtitle_lang).
func _force_subtitle_lang() -> void:
	if FORCE_LANG != "":
		SUBS.forced_lang = FORCE_LANG


func _restore_subtitle_lang() -> void:
	SUBS.forced_lang = ""


func _exit_tree() -> void:
	_restore_subtitle_lang()


func _prepare() -> void:
	# tunggu player mendarat (maks 1,6 detik). Layar masih hitam jadi nggak kelihatan.
	var waited := 0.0
	while _player != null and not _player.is_on_floor() and waited < 1.6:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	_freeze_world()
	_build_sounds()
	await _stage_jennifer()
	_plan()


# ==================================================================== DUNIA: BEKUKAN / PULIHKAN
func _freeze_world() -> void:
	_frozen = true
	if _player != null:
		_player.set_physics_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)
		_pcam = _player.get_node_or_null("Camera3D") as Camera3D
		for n in ["Camera3D", "PlayerActions"]:
			var node := _player.get_node_or_null(str(n))
			if node != null:
				node.set_process(false)
				node.set_process_input(false)
				node.set_process_unhandled_input(false)
	if _pcam != null:
		_pfov = _pcam.fov
	GameState.set_process_unhandled_input(false)
	var hud := _root.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false


func _unfreeze_world() -> void:
	if not _frozen:
		return
	_frozen = false
	if _player != null and is_instance_valid(_player):
		_player.set_physics_process(true)
		_player.set_process_input(true)
		_player.set_process_unhandled_input(true)
		for n in ["Camera3D", "PlayerActions"]:
			var node := _player.get_node_or_null(str(n))
			if node != null:
				node.set_process(true)
				node.set_process_input(true)
				node.set_process_unhandled_input(true)
	GameState.set_process_unhandled_input(true)


func _reset_jennifer() -> void:
	if _jen == null or not is_instance_valid(_jen):
		return
	var voice := _jen.get("_voice") as AudioStreamPlayer3D
	if voice != null:
		voice.stop()
	_jen.collision_layer = _jen_layer
	_jen.collision_mask = _jen_mask
	_jen.velocity = Vector3.ZERO
	_jen.set("_greet_left", 0.0)
	_jen.set("_mood_cur", "calm")
	if _jen.has_method("_set_mood"):
		_jen.call("_set_mood", "calm")
	_play_anim("idle", 0.2)
	_jen.set("_anim_name", "idle")
	_jen.set_physics_process(true)


func _play_anim(anim_name: String, blend := 0.2) -> void:
	if _jen_anim != null and is_instance_valid(_jen_anim) and _jen_anim.has_animation(anim_name):
		_jen_anim.play(anim_name, blend)


# ==================================================================== STAGING JENNIFER
func _floor_at(space: PhysicsDirectSpaceState3D, p: Vector3, from_y: float, depth: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, from_y, p.z), Vector3(p.x, from_y - depth, p.z))
	q.collide_with_areas = false
	if _player != null:
		var ex: Array[RID] = [_player.get_rid()]
		q.exclude = ex
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y


func _free_box(space: PhysicsDirectSpaceState3D, center: Vector3, size: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collide_with_areas = false
	return space.intersect_shape(q, 1).is_empty()


## Jennifer di scene aslinya berdiri di titik (0,0,0), persis di tempat player muncul. Di sini dia dipindah ke
## depan player (6 sampai 10 meter, di tempat yang kosong) dan dibuat membelakangi. Posisi ini juga jadi posisi awalnya di game.
func _stage_jennifer() -> void:
	if _jen == null or _player == null:
		return
	_jen_model = _jen.get("_model") as Node3D
	_jen_anim = _jen.get("_anim") as AnimationPlayer
	await get_tree().physics_frame
	var space := get_viewport().find_world_3d().direct_space_state
	var pp := _player.global_position
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
	var pfloor := _floor_at(space, pp, pp.y, 4.0)
	if is_nan(pfloor):
		pfloor = pp.y - 1.0
	var best := Vector3.INF
	var dists: Array[float] = [7.0, 8.5, 6.0, 10.0]
	var angs: Array[float] = [0.0, 20.0, -20.0, 40.0, -40.0]
	for dist in dists:
		for ang in angs:
			var spot := pp + fwd.rotated(Vector3.UP, deg_to_rad(ang)) * dist
			var fy := _floor_at(space, spot, pfloor + 2.5, 5.0)
			if is_nan(fy) or absf(fy - pfloor) > 0.45:
				continue
			if not _free_box(space, Vector3(spot.x, fy + 1.15, spot.z), Vector3(1.1, 2.1, 1.1)):
				continue
			best = Vector3(spot.x, fy, spot.z)
			break
		if best != Vector3.INF:
			break
	if best == Vector3.INF:
		best = Vector3(pp.x + fwd.x * 7.0, pfloor, pp.z + fwd.z * 7.0)
	_jen.global_position = best
	_jen.velocity = Vector3.ZERO
	_jen.set("_patrol_target", best)
	_jen.set("_target", best)
	_jen.set("_last_pos", best)
	_jen_pos = best
	var d := pp - best
	d.y = 0.0
	_face_ang = atan2(d.x, d.z)
	if _jen_model != null:
		_jen_model.rotation.y = _face_ang + PI   # membelakangi player
	_play_anim("idle", 0.0)


# ==================================================================== RENCANA KAMERA DARI PETA
func _is_room(node_name: String) -> bool:
	var lower := node_name.to_lower()
	for pfx in ["kelas", "ruang guru", "ruang lab", "toilet"]:
		if lower.begins_with(str(pfx)):
			return true
	return false


func _pretty(node_name: String) -> String:
	var s := node_name.strip_edges().to_upper()
	# Nama node di scene tetap Indonesia (dipakai pencarian); yang tampil di layar mengikuti bahasa pilihan.
	if s.begins_with("RUANG GURU"):
		s = _t("room_teachers") + s.substr(10)
	elif s.begins_with("RUANG LAB"):
		s = _t("room_lab") + s.substr(9)
	elif s.begins_with("KELAS"):
		s = _t("room_class") + " " + s.substr(5).strip_edges()
	elif s.begins_with("TOILET"):
		s = _t("room_toilet") + s.substr(6)
	return s


func _find_node(wanted: String) -> Node3D:
	var n := _root.get_node_or_null(wanted) as Node3D
	if n != null:
		return n
	for ch in _root.get_children():
		if str(ch.name).to_lower() == wanted.to_lower() and ch is Node3D:
			return ch as Node3D
	return null


func _plan() -> void:
	var gate_node := _find_node("SchoolGate")
	if gate_node != null:
		_gate = gate_node.global_position
		var o := -gate_node.global_transform.basis.z   # sisi LUAR gerbang = -Z lokal (lihat school_gate.gd)
		o.y = 0.0
		if o.length() > 0.01:
			_out = o.normalized()
	# pusat & ukuran sekolah dari posisi semua ruangan + gerbang
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var count := 0
	var pts: Array[Vector3] = [_gate]
	for ch in _root.get_children():
		var n3 := ch as Node3D
		if n3 != null and _is_room(str(ch.name)):
			pts.append(n3.global_position)
			count += 1
	for p in pts:
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.z)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.z)
	if count < 2:
		lo = Vector2(-40, -45)
		hi = Vector2(45, 55)
	var floor_y := _jen_pos.y
	_center = Vector3((lo.x + hi.x) * 0.5, floor_y, (lo.y + hi.y) * 0.5)
	_radius = maxf(hi.x - lo.x, hi.y - lo.y) * 0.5 + 6.0
	_gate.y = floor_y
	# mata player & kepala Jennifer
	_eye = _pcam.global_position if _pcam != null else (_player.global_position if _player != null else _center)
	_head = _jen_pos + Vector3.UP * 2.1
	if _jen != null and _jen.has_method("head_position"):
		_head = _jen.call("head_position")
	_build_places()


func _build_places() -> void:
	for p in _places:
		var old: Label = p["label"]
		old.queue_free()
	_places.clear()
	var fs := int(_vp.y * 0.02)
	for ch in _root.get_children():
		var n3 := ch as Node3D
		if n3 != null and _is_room(str(ch.name)):
			_add_place(_pretty(str(ch.name)), n3.global_position + Vector3.UP * 4.0, BONE, fs)
	var court := _find_node("BasketballCourt")
	if court != null:
		_add_place(_t("court"), court.global_position + Vector3.UP * 4.0, BONE, int(fs * 1.15))
	_add_place(_t("gate"), _gate + Vector3.UP * 5.0, BLOOD, int(fs * 1.25))
	if _player != null:
		_add_place(_t("you"), _player.global_position + Vector3.UP * 3.0, Color(1.0, 0.85, 0.3), int(fs * 1.25))


func _add_place(text: String, pos: Vector3, color: Color, size: int) -> void:
	var l := _mk_label(_layer_fx, text, size, color)
	l.visible = false
	_places.append({"label": l, "pos": pos})


# ==================================================================== CAHAYA MALAM SEMENTARA
func _scene_has_lighting() -> bool:
	if get_viewport().find_world_3d().environment != null:
		return true
	for cls in ["WorldEnvironment", "DirectionalLight3D"]:
		if not _root.find_children("*", str(cls), true, false).is_empty():
			return true
	return false


func _add_night_light() -> void:
	if _scene_has_lighting():
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.43, 0.68)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.14)
	env.fog_density = 0.003
	_night_env = WorldEnvironment.new()
	_night_env.environment = env
	_root.add_child(_night_env)
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.6, 0.7, 1.0)
	_moon.light_energy = 0.6
	_moon.shadow_enabled = false
	_moon.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	_root.add_child(_moon)


func _remove_night_light() -> void:
	if _night_env != null and is_instance_valid(_night_env):
		_night_env.queue_free()
	if _moon != null and is_instance_valid(_moon):
		_moon.queue_free()
	_night_env = null
	_moon = null


# ==================================================================== URUTAN UTAMA
func _play() -> void:
	_start_music()
	await _chat_play()
	if _skipping:
		return
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_root.add_child(_cam)
	_cam.make_current()
	if USE_NIGHT_LIGHT:
		_add_night_light()
	var up := Vector3.UP

	# ---------- 1. gerbang dari luar ----------
	var s1a := _gate + _out * 17.0 + up * 1.7
	var s1b := _gate + _out * 10.5 + up * 1.7
	var look1 := _gate + up * 2.6
	_start_shot(s1a, s1a.lerp(s1b, 0.5), s1b, look1, look1, 58.0, 54.0, 7.0, 2, 0.04)
	_update_camera(0.0)
	_show_bars(true)
	create_tween().tween_property(_tint, "modulate:a", 1.0, 1.2)
	create_tween().tween_property(_black, "color:a", 0.0, 1.4)
	_start_wind()
	_lines(lines_gate)
	await _shot_done()
	if _skipping:
		return

	# ---------- 2. naik melewati gerbang, terbang di atas sekolah ----------
	var h := _radius * 1.05
	var s2c := _gate + _out * 3.0 + up * (_radius * 0.6)
	var s2b := _center + _out * (_radius * 0.5) + up * h
	_start_shot(s1b, s2c, s2b, look1, _center, 54.0, 64.0, 10.5, 1, 0.0)
	_lines(lines_aerial)
	_show_places(3.0, 5.4)
	await _shot_done()
	if _skipping:
		return

	# ---------- 3. meluncur turun ke mata player ----------
	var s3c := s2b.lerp(_eye, 0.5) + up * (h * 0.15)
	_start_shot(s2b, s3c, _eye, _center, _head, 64.0, _pfov, 6.4, 1, 0.0)
	create_tween().tween_property(_tint, "modulate:a", 0.5, 5.0)
	_lines(lines_descent)
	await _shot_done()
	if _skipping:
		return

	# ---------- 4. Bu Jennifer ----------
	_reveal_ready = true
	var dir := (_head - _eye).normalized()
	_start_shot(_eye, _eye + dir * 0.5, _eye + dir, _head, _head, _pfov, _pfov, 24.0, 0, 0.012)
	await _reveal()
	if _skipping:
		return
	await _sting()


func _reveal() -> void:
	await _wait(0.9)
	if _skipping:
		return
	_play_anim("look_around", 0.3)
	await _wait(2.0)
	if _skipping:
		return
	if _jen_model != null:
		var tw := create_tween()
		tw.tween_property(_jen_model, "rotation:y", _face_ang, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(1.5)
	if _skipping:
		return
	_play_anim("idle", 0.3)
	await _wait(0.4)
	if _jen != null and _jen.has_method("greet"):
		_jen.call("greet", false)
	for i in _intro_lines.size():
		if _skipping:
			return
		_say(SUBS.line("intro%d" % (i + 1), _intro_lines[i]), _line_secs + 1.0, JENNIFER_COLOR)
		if _jen != null and _jen.has_method("speak"):
			_jen.call("speak", "intro%d" % (i + 1))
		if i == _intro_lines.size() - 1:
			_sfx(_snd_riser, -14.0)
		await _wait(_line_secs + 1.4)
	await _wait(0.3)


func _sting() -> void:
	if _skipping:
		return
	create_tween().tween_property(_sub, "modulate:a", 0.0, 0.2)
	await _wait(0.6)   # jeda sunyi
	if _skipping:
		return
	# wajah berubah + kamera menerjang + dentuman + judul
	_sfx(_snd_boom, -2.0)
	_flash.color = Color(1, 1, 1, 0.85)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)
	if _jen != null:
		_jen.set("_mood_cur", "angry")
		if _jen.has_method("_set_mood"):
			_jen.call("_set_mood", "angry")
		_play_anim("angry_idle", 0.05)
	var cur := _cam.global_position
	var look := _head
	var toward := (look - cur).normalized()
	_start_shot(cur, cur + toward * 0.7, cur + toward * 1.4, look, look, _cam.fov, 40.0, 0.35, 1, 0.03)
	_show_title()
	_music_fade(2.6)
	await _wait(2.8)
	if _skipping:
		return
	create_tween().tween_property(_black, "color:a", 1.0, 0.25)
	await _wait(0.7)


# ==================================================================== CHAT HP
func _chat_play() -> void:
	create_tween().tween_property(_phone, "modulate:a", 1.0, 0.5)
	await _wait(0.9)
	for m in chat_lines:
		if _skipping:
			return
		var me: bool = str(m[0]) == "me"
		if not me:
			_status.text = _t("typing")
		await _wait(float(m[2]))
		_status.text = _t("online")
		_add_bubble(me, str(m[1]))
		_sfx(_snd_ding_b if me else _snd_ding_a, -10.0)
		await _wait(float(m[3]))
	await _wait(0.4)
	create_tween().tween_property(_phone, "modulate:a", 0.0, 0.5)
	await _wait(0.7)


func _add_bubble(me: bool, text: String) -> void:
	var fs := int(_vp.y * 0.021)
	var maxw := _phone_w * 0.64
	var font := ThemeDB.fallback_font
	var est := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 1.1 + 6.0
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if me else BoxContainer.ALIGNMENT_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bub := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.0, 0.36, 0.30) if me else Color(0.16, 0.18, 0.21)
	st.set_corner_radius_all(int(fs * 0.7))
	st.content_margin_left = fs * 0.7
	st.content_margin_right = fs * 0.7
	st.content_margin_top = fs * 0.45
	st.content_margin_bottom = fs * 0.45
	bub.add_theme_stylebox_override("panel", st)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(minf(est, maxw), 0.0)
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", Color(0.93, 0.95, 0.96))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bub.add_child(lbl)
	row.add_child(bub)
	_msgs.add_child(row)
	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.2)
	while _msgs.get_child_count() > MAX_VISIBLE_MSGS:
		var old := _msgs.get_child(0)
		_msgs.remove_child(old)
		old.queue_free()


# ==================================================================== AKHIR
func _finish() -> void:
	if _ended:
		return
	_ended = true
	set_process_input(false)
	_black.color.a = 1.0   # kalau di-skip, langsung tutup layar
	_layer_fx.visible = false
	_layer_bars.visible = false
	_layer_top.visible = false
	_stop_audio()
	_remove_night_light()
	_reset_jennifer()
	if _reveal_ready and _player != null and _pcam != null:
		# player menghadap Jennifer, persis seperti kamera cutscene
		var d := _jen_pos - _player.global_position
		d.y = 0.0
		if d.length() > 0.01:
			_player.rotation.y = atan2(-d.x, -d.z)
		var dir := (_head - _eye).normalized()
		_pcam.rotation.x = clampf(asin(clampf(dir.y, -1.0, 1.0)), -1.2, 1.2)
	if _pcam != null:
		_pcam.make_current()
		if _cam != null and is_instance_valid(_cam):
			_cam.queue_free()
	var hud := _root.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = true
	await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 0.0, 0.8)
	await tw.finished
	_unfreeze_world()
	for l in _layers:
		if is_instance_valid(l):
			l.queue_free()
	_layers.clear()
	set_process(false)
	_restore_subtitle_lang()
	finished.emit()


func _stop_audio() -> void:
	for p in _sfx_list:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	_sfx_list.clear()
	for p in [_piano, _wind]:
		if p != null and is_instance_valid(p):
			(p as AudioStreamPlayer).stop()
			(p as AudioStreamPlayer).queue_free()


# ==================================================================== LOOP, INPUT, PAUSE
func _process(delta: float) -> void:
	_clock += delta
	if _ended:
		return
	if _clock > MAX_SECONDS:
		_skipping = true
	if _skipping:
		_skip_t += delta
		if _skip_t > 1.5:
			_finish()   # pengaman kalau urutan utama macet
	elif _hint != null and _clock > SKIP_GRACE and _hint.modulate.a < 0.6:
		_hint.modulate.a = minf(_hint.modulate.a + delta, 0.6)
	_update_camera(delta)
	_update_labels()


func _input(event: InputEvent) -> void:
	if _ended or _skipping or _clock < SKIP_GRACE:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_skipping = true
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# saat game di-pause (ESC), sembunyikan overlay supaya menu pause kelihatan
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		for l in _layers:
			if is_instance_valid(l):
				l.visible = (what == NOTIFICATION_UNPAUSED)


func _wait(seconds: float) -> void:
	var end := _clock + seconds
	while _clock < end and not _skipping and not _ended:
		await get_tree().process_frame


func _shot_done() -> void:
	while _shot_t < _shot_len and not _skipping and not _ended:
		await get_tree().process_frame


# ==================================================================== KAMERA
func _bez(a: Vector3, c: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


func _start_shot(a: Vector3, c: Vector3, b: Vector3, la: Vector3, lb: Vector3, fa: float, fb: float, secs: float, mode: int, sway := 0.0) -> void:
	_a = a
	_c = c
	_b = b
	_la = la
	_lb = lb
	_fa = fa
	_fb = fb
	_shot_len = maxf(secs, 0.05)
	_shot_t = 0.0
	_shot_mode = mode
	_sway = sway
	_shot_on = true


func _update_camera(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam) or not _shot_on:
		return
	_shot_t += delta
	var u := clampf(_shot_t / _shot_len, 0.0, 1.0)
	var e := u
	match _shot_mode:
		1:
			e = u * u * (3.0 - 2.0 * u)
		2:
			e = 1.0 - (1.0 - u) * (1.0 - u)
	var pos := _bez(_a, _c, _b, e)
	var look := _la.lerp(_lb, e)
	pos += Vector3(sin(_clock * 0.7), sin(_clock * 1.1 + 1.0), sin(_clock * 0.9 + 2.0)) * _sway
	_cam.global_position = pos
	if pos.distance_to(look) > 0.05:
		_cam.look_at(look, Vector3.UP)
	_cam.fov = lerpf(_fa, _fb, e)


func _update_labels() -> void:
	var on := _cam != null and is_instance_valid(_cam) and _places_alpha > 0.01
	for p in _places:
		var lbl: Label = p["label"]
		if not is_instance_valid(lbl):
			continue
		if not on:
			lbl.visible = false
			continue
		var wp: Vector3 = p["pos"]
		if _cam.is_position_behind(wp):
			lbl.visible = false
			continue
		var sp := _cam.unproject_position(wp)
		if sp.x < 0.0 or sp.y < 0.0 or sp.x > _vp.x or sp.y > _vp.y:
			lbl.visible = false
			continue
		lbl.visible = true
		lbl.position = sp - lbl.get_minimum_size() * 0.5
		lbl.modulate.a = _places_alpha


func _show_places(delay: float, hold: float) -> void:
	await _wait(delay)
	if _skipping:
		return
	create_tween().tween_property(self, "_places_alpha", 0.9, 1.0)
	await _wait(hold)
	create_tween().tween_property(self, "_places_alpha", 0.0, 0.8)


# ==================================================================== SUBTITLE
func _lines(list: Array) -> void:
	var base := _clock
	for it in list:
		var at := base + float(it[0])
		while _clock < at and not _skipping and not _ended:
			await get_tree().process_frame
		if _skipping or _ended:
			return
		_say(str(it[2]), float(it[1]), NARRATOR)


func _say(text: String, seconds: float, color := NARRATOR) -> void:
	_sub_id += 1
	var my := _sub_id
	_sub.text = text
	_sub.add_theme_color_override("font_color", color)
	_sub.visible_ratio = 0.0
	_sub.modulate.a = 1.0
	create_tween().tween_property(_sub, "visible_ratio", 1.0, clampf(text.length() * 0.03, 0.4, 1.6))
	await _wait(seconds)
	if my == _sub_id and not _ended:
		create_tween().tween_property(_sub, "modulate:a", 0.0, 0.35)


func _show_bars(on: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", _bar_h if on else 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bar_bot, "offset_top", -_bar_h if on else 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _show_title() -> void:
	_title_box.modulate.a = 1.0
	_title_box.pivot_offset = _title_box.get_combined_minimum_size() * 0.5
	_title_box.scale = Vector2(1.35, 1.35)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title_box, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


# ==================================================================== UI
func _new_layer(n: int) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = n
	add_child(l)
	_layers.append(l)
	return l


func _full_rect(parent: Node, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _mk_label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(2, int(size * 0.12)))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_overlay() -> void:
	_vp = get_viewport().get_visible_rect().size
	_layer_fx = _new_layer(50)
	_layer_bars = _new_layer(52)
	_layer_black = _new_layer(54)
	_layer_top = _new_layer(56)

	# --- fx: tint malam + vignette ---
	_tint = _full_rect(_layer_fx, NIGHT_TINT)
	_tint.modulate.a = 0.0
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
	var vig := TextureRect.new()
	vig.texture = gt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_fx.add_child(vig)

	# --- bar sinematik + subtitle ---
	_bar_h = _vp.y * 0.115
	_bar_top = _full_rect(_layer_bars, Color.BLACK)
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 0.0
	_bar_bot = _full_rect(_layer_bars, Color.BLACK)
	_bar_bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bot.offset_top = 0.0
	_sub = _mk_label(_layer_bars, "", int(_vp.y * 0.032), NARRATOR)
	_sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sub.offset_left = _vp.x * 0.1
	_sub.offset_right = -_vp.x * 0.1
	_sub.offset_top = -_bar_h
	_sub.offset_bottom = 0.0
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.visible_ratio = 0.0

	# --- hitam penutup ---
	_black = _full_rect(_layer_black, Color.BLACK)

	# --- paling atas: chat, judul, kilat, tombol skip ---
	_build_phone()
	_build_title()
	_flash = _full_rect(_layer_top, Color(1, 1, 1, 0))
	_hint = _mk_label(_layer_top, _t("skip"), int(_vp.y * 0.02), BONE)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -_vp.x * 0.25
	_hint.offset_right = -_vp.x * 0.02
	_hint.offset_top = -_vp.y * 0.06
	_hint.offset_bottom = -_vp.y * 0.02
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.modulate.a = 0.0


func _build_title() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_top.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(_vp.y * 0.012))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0.0
	center.add_child(box)
	_title_box = box
	var t := Label.new()
	t.text = TITLE_TEXT
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", int(_vp.y * 0.13))
	t.add_theme_color_override("font_color", BONE)
	t.add_theme_color_override("font_shadow_color", Color(0.8, 0, 0.05, 0.45))
	t.add_theme_color_override("font_outline_color", Color(0.25, 0, 0.02, 1.0))
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.add_theme_constant_override("outline_size", 8)
	t.add_theme_constant_override("line_spacing", -6)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)
	var line := ColorRect.new()
	line.color = BLOOD
	line.custom_minimum_size = Vector2(_vp.x * 0.12, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	var s := Label.new()
	s.text = TITLE_SUB
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", int(_vp.y * 0.026))
	s.add_theme_color_override("font_color", BLOOD)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(s)


func _build_phone() -> void:
	var fs := int(_vp.y * 0.021)
	var h := _vp.y * 0.80
	_phone_w = minf(h * 0.52, _vp.x * 0.9)
	var rad := int(_phone_w * 0.07)
	_phone = CenterContainer.new()
	_phone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.modulate.a = 0.0
	_layer_top.add_child(_phone)

	var body := PanelContainer.new()
	body.custom_minimum_size = Vector2(_phone_w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08)
	sb.set_corner_radius_all(rad)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.22, 0.24, 0.28)
	body.add_theme_stylebox_override("panel", sb)
	_phone.add_child(body)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	body.add_child(col)

	# header kontak
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.06, 0.26, 0.23)
	hs.corner_radius_top_left = rad
	hs.corner_radius_top_right = rad
	hs.content_margin_left = fs * 1.2
	hs.content_margin_right = fs * 1.2
	hs.content_margin_top = fs * 1.0
	hs.content_margin_bottom = fs * 0.9
	head.add_theme_stylebox_override("panel", hs)
	col.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	head.add_child(hv)
	var top_row := HBoxContainer.new()
	hv.add_child(top_row)
	var name_lbl := Label.new()
	name_lbl.text = _t("contact")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", int(fs * 1.15))
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 0.97))
	top_row.add_child(name_lbl)
	var clock := Label.new()
	clock.text = _t("clock")
	clock.add_theme_font_size_override("font_size", int(fs * 0.85))
	clock.add_theme_color_override("font_color", Color(0.7, 0.85, 0.82))
	top_row.add_child(clock)
	_status = Label.new()
	_status.text = _t("online")
	_status.add_theme_font_size_override("font_size", int(fs * 0.8))
	_status.add_theme_color_override("font_color", Color(0.7, 0.85, 0.82))
	hv.add_child(_status)

	# area pesan (rata bawah)
	var area := MarginContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("margin_left", int(_phone_w * 0.04))
	area.add_theme_constant_override("margin_right", int(_phone_w * 0.04))
	area.add_theme_constant_override("margin_top", int(fs * 0.6))
	area.add_theme_constant_override("margin_bottom", int(fs * 0.6))
	col.add_child(area)
	_msgs = VBoxContainer.new()
	_msgs.alignment = BoxContainer.ALIGNMENT_END
	_msgs.add_theme_constant_override("separation", int(fs * 0.5))
	_msgs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_msgs)

	# kolom ketik palsu
	var inp := PanelContainer.new()
	var ins := StyleBoxFlat.new()
	ins.bg_color = Color(0.1, 0.11, 0.13)
	ins.corner_radius_bottom_left = rad
	ins.corner_radius_bottom_right = rad
	ins.content_margin_left = fs * 1.2
	ins.content_margin_right = fs * 1.2
	ins.content_margin_top = fs * 0.9
	ins.content_margin_bottom = fs * 0.9
	inp.add_theme_stylebox_override("panel", ins)
	col.add_child(inp)
	var hint := Label.new()
	hint.text = _t("type_hint")
	hint.add_theme_font_size_override("font_size", int(fs * 0.85))
	hint.add_theme_color_override("font_color", Color(0.45, 0.48, 0.52))
	inp.add_child(hint)


# ==================================================================== AUDIO
func _mk_player(stream: AudioStream, db: float, bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	if AudioServer.get_bus_index(bus_name) != -1:
		p.bus = bus_name
	add_child(p)
	return p


func _sfx(stream: AudioStream, db: float) -> void:
	if stream == null:
		return
	var p := _mk_player(stream, db, "Master")
	_sfx_list.append(p)
	p.play()


func _start_music() -> void:
	if not ResourceLoader.exists(PIANO_PATH):
		return
	var st := load(PIANO_PATH) as AudioStream
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		st = st.duplicate() as AudioStream   # salinan, supaya setting loop nggak mengubah lagu menu
		(st as AudioStreamOggVorbis).loop = true
	_piano = _mk_player(st, -50.0, "Music")
	_piano.play()
	create_tween().tween_property(_piano, "volume_db", -13.0, 3.0)


func _start_wind() -> void:
	if _snd_wind == null:
		return
	_wind = _mk_player(_snd_wind, -60.0, "Music")
	_wind.play()
	create_tween().tween_property(_wind, "volume_db", -20.0, 2.5)


func _music_fade(seconds: float) -> void:
	for p in [_piano, _wind]:
		if p != null and is_instance_valid(p):
			create_tween().tween_property(p, "volume_db", -60.0, seconds)


func _wav(bytes: PackedByteArray, rate: int, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = bytes.size() / 2
	return w


func _build_sounds() -> void:
	_snd_ding_a = _make_ding(880.0, 1320.0)
	_snd_ding_b = _make_ding(660.0, 990.0)
	_snd_boom = _make_boom()
	_snd_riser = _make_riser()
	_snd_wind = _make_wind()


func _make_ding(f1: float, f2: float) -> AudioStreamWAV:
	var rate := 16000
	var n := int(rate * 0.5)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var e1 := minf(1.0, t / 0.004) * exp(-t * 10.0)
		var e2 := 0.0
		if t > 0.09:
			e2 = minf(1.0, (t - 0.09) / 0.004) * exp(-(t - 0.09) * 8.0)
		var s := (sin(TAU * f1 * t) * e1 + sin(TAU * f2 * t) * e2) * 0.45
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(bytes, rate)


func _make_boom() -> AudioStreamWAV:
	var rate := 16000
	var dur := 1.8
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in n:
		var t := float(i) / rate
		var s := sin(TAU * 46.0 * t) * exp(-t * 2.8)
		s += sin(TAU * 92.0 * t) * exp(-t * 5.0) * 0.5
		s += rng.randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.6
		s = tanh(s * 1.6) * 0.9 * minf(1.0, t / 0.003)
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(bytes, rate)


func _make_riser() -> AudioStreamWAV:
	var rate := 12000
	var dur := 4.4
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var k := t / dur
		ph += TAU * (70.0 + 380.0 * k * k) / rate
		var amp := k * k
		var s := (sin(ph) * 0.55 + sin(ph * 1.5) * 0.25 + rng.randf_range(-1.0, 1.0) * 0.18) * amp
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(bytes, rate)


func _make_wind() -> AudioStreamWAV:
	var rate := 8000
	var dur := 6.0
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var y := 0.0
	for i in n:
		var t := float(i) / rate
		y += 0.06 * (rng.randf_range(-1.0, 1.0) - y)
		var gust := 0.55 + 0.25 * sin(TAU * t / 3.0) + 0.2 * sin(TAU * t / 2.0 + 1.0)
		var edge := minf(1.0, minf(t / 0.4, (dur - t) / 0.4))
		var s := y * 3.5 * gust * edge
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(bytes, rate, true)
