extends Node3D
## Tempat sembunyi ala Evil Nun: LEMARI atau KOLONG MEJA. Hadap dari dekat, tekan E untuk masuk, tekan E lagi untuk keluar.
##
## Cara pasang: Node3D baru + script ini, taruh di LANTAI (titik asal = tengah bawah). Depan = sumbu +Z (panah biru).
## Build Model nyala = model lemari / meja guru dibuat otomatis dari kode.
## Build Model mati = pakai model sendiri: instance meja/lemari aslimu sebagai ANAK node ini (atau biarkan meja yang sudah
## ada di kelas dan taruh node ini di kolongnya). Atur Hide Offset (posisi player di dalam) dan Exit Offset
## (tempat player muncul saat keluar, harus lantai kosong di depannya), semua dalam koordinat lokal node ini.
##
## Jennifer: kalau dia LIHAT kamu masuk (dalam jarak see_distance dan tanpa penghalang), dia langsung ke sini dan buka paksa.
## Kalau tidak, dia memeriksa 2-3 tempat sembunyi terdekat dari posisi terakhirmu, lalu menyerah.
##
## TAMPILAN SEMBUNYI (v2):
##  - LEMARI : mengintip dari celah pintu (celah vertikal, serat kayu, debu di cahaya).
##  - KOLONG : mengintip dari bawah meja (celah lebar rendah, sisi kayu gelap).
##  - Pandangan diarahkan keluar otomatis dan kepala hanya bisa menoleh dalam batas wajar (seperti mengintip betulan).
##  - Model lemari/meja disembunyikan dari kamera selama kamu di dalam, jadi pandangan ke luar nggak terhalang.
##  - Posisi Jennifer tetap terlihat: siluet merah tembus tembok saat dia dekat + penanda arah/jarak di layar
##    (matikan lewat see_teacher_through_walls / show_teacher_marker kalau kerasa terlalu mudah).
##  - Makin dekat Jennifer, makin merah tepi celah, makin cepat detak jantung, dan siluetnya makin jelas.

enum Kind { LEMARI, KOLONG_MEJA }

# Shader layar sembunyi: bingkai kayu + celah intip + warna pandangan (dingin, redup, memerah saat bahaya).
const VIEW_SHADER := """
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform int mode = 0;
uniform vec2 slit_half = vec2(0.2, 0.4);
uniform vec2 slit_center = vec2(0.0, 0.0);
uniform float aspect = 1.78;
uniform float open_t : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float danger : hint_range(0.0, 1.0) = 0.0;
uniform float beat : hint_range(0.0, 1.0) = 0.0;
uniform vec2 look = vec2(0.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);

	// animasi membuka: celah tipis lalu melebar
	float e = clamp(open_t, 0.0, 1.0);
	e = e * e * (3.0 - 2.0 * e);
	vec2 hs = slit_half;
	hs.x *= mix(0.06, 1.0, e);
	hs.y *= mix(0.015, 1.0, smoothstep(0.0, 0.75, e));
	hs *= 1.0 - 0.025 * beat * danger;

	// napas halus + parallax kecil saat menoleh
	vec2 sway = vec2(sin(TIME * 1.1), sin(TIME * 1.7 + 1.0)) * 0.002;
	vec2 q = p - slit_center - look * vec2(0.03, 0.02) - sway;

	float rough = (fbm(q * vec2(16.0, 10.0) + 3.0) - 0.5) * 0.03;
	float rad = (mode == 0) ? 0.025 : 0.07;
	float d = sd_box(q, hs, rad) + rough;

	float inside = 1.0 - smoothstep(-0.003, 0.003, d);
	float spill = exp(-max(d, 0.0) * 7.0);
	float edge_dark = smoothstep(-0.14, 0.0, d);

	// ---- kayu di luar celah
	vec2 wp = p - look * vec2(0.06, 0.03);
	float grain;
	float seam;
	vec3 base;
	if (mode == 0) {
		grain = fbm(vec2(wp.x * 40.0, wp.y * 2.4) + 7.0);
		float cell = wp.x * 2.6;
		float fr = abs(fract(cell) - 0.5);
		seam = 1.0 - smoothstep(0.0, 0.02, 0.5 - fr);
		float tone = 0.85 + 0.3 * hash21(vec2(floor(cell), 3.0));
		base = vec3(0.23, 0.125, 0.06) * tone;
	} else {
		grain = fbm(vec2(wp.x * 3.0, wp.y * 46.0) + 2.0);
		float fr2 = abs(fract(wp.y * 2.2) - 0.5);
		seam = 1.0 - smoothstep(0.0, 0.02, 0.5 - fr2);
		base = vec3(0.20, 0.12, 0.07) * mix(0.55, 1.0, smoothstep(-0.4, 0.2, wp.y));
	}
	vec3 wood = base * (0.55 + 0.9 * grain);
	wood *= 1.0 - 0.55 * seam;
	wood *= 0.07 + 1.1 * spill;
	wood += vec3(0.45, 0.28, 0.12) * (1.0 - smoothstep(0.0, 0.025, d)) * step(0.0, d) * 0.55;
	wood += vec3(0.8, 0.03, 0.02) * spill * danger * (0.18 + 0.82 * beat);
	wood *= 1.0 - 0.45 * smoothstep(0.55, 1.15, length(p));

	// ---- pandangan ke luar
	float ab = 0.003 * edge_dark;
	vec3 sc = vec3(
		texture(screen_tex, SCREEN_UV + vec2(ab, 0.0)).r,
		texture(screen_tex, SCREEN_UV).g,
		texture(screen_tex, SCREEN_UV - vec2(ab, 0.0)).b);
	float luma = dot(sc, vec3(0.299, 0.587, 0.114));
	sc = mix(vec3(luma), sc, mix(0.85, 0.5, danger));
	sc *= vec3(0.92, 0.95, 1.0) * 1.05;
	sc = mix(sc, sc * vec3(1.35, 0.55, 0.5), danger * 0.55);
	sc *= 1.0 - 0.45 * edge_dark;

	// ---- debu melayang di cahaya
	float dust = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 g = vec2(uv.x * aspect, uv.y) * (8.0 + fi * 5.0) + vec2(TIME * 0.03 * (1.0 + fi), -TIME * 0.05 * (1.0 + fi * 0.5));
		vec2 gid = floor(g);
		vec2 gf = fract(g) - 0.5;
		float h = hash21(gid + fi * 17.0);
		vec2 off = (vec2(hash21(gid + 3.1), hash21(gid + 7.7)) - 0.5) * 0.6;
		dust += step(0.75, h) * (1.0 - smoothstep(0.0, 0.07, length(gf - off))) * (0.5 + 0.5 * sin(TIME * 1.5 + h * 30.0));
	}

	vec3 col = mix(wood, sc, inside);
	col += vec3(0.85, 0.8, 0.65) * dust * 0.10 * inside;
	col += (hash21(uv * vec2(aspect, 1.0) * 700.0 + fract(TIME) * 37.0) - 0.5) * 0.045;
	COLOR = vec4(col, fade);
}
"""

# Siluet Jennifer tembus tembok: garis tepi merah menyala + isian tipis, digambar di atas segalanya.
const SIL_SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_back;

uniform vec3 tint : source_color = vec3(1.0, 0.16, 0.12);
uniform float strength = 0.0;
uniform float pulse = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	ALBEDO = tint * (1.0 + 0.5 * pulse);
	ALPHA = strength * (0.14 + 0.86 * fres);
}
"""

@export var kind: Kind = Kind.LEMARI
@export var build_model := true
@export var use_distance := 3.2
@export var look_dot := 0.7
@export var hide_offset := Vector3.ZERO
@export var exit_offset := Vector3(0, 0, 1.5)
@export var peek_height := 0.5           ## tinggi mata dari LANTAI saat sembunyi di kolong meja (meter). Lemari: tinggi berdiri biasa
@export var see_distance := 9.0          ## jarak maksimal Jennifer bisa lihat kamu masuk (dulu 18, terlalu jauh)
@export var see_fov_dot := 0.35          ## harus berada di depan pandangan Jennifer (1 = lurus, 0 = 90 derajat, negatif = sampai belakang)
@export var model_scene: PackedScene     ## (opsional) model GLB sendiri; kosong = res://models/lemari.glb atau meja_guru.glb kalau ada

@export_group("Tampilan sembunyi")
@export var peek_size := Vector2.ZERO            ## setengah ukuran celah intip (satuan tinggi layar). (0,0) = otomatis sesuai jenis
@export var look_limit_yaw := 0.0                ## batas menoleh kiri/kanan dalam derajat. 0 = otomatis (lemari 60, kolong 100 = total 200 derajat kiri-kanan)
@export var look_limit_pitch := 0.0              ## batas menoleh atas/bawah dalam derajat. 0 = otomatis
@export var see_teacher_through_walls := true    ## siluet merah Jennifer terlihat menembus tembok kalau dia dalam jarak silhouette_range
@export var silhouette_range := 16.0
@export var show_teacher_marker := true          ## penanda jarak + arah Jennifer di layar
@export var marker_range := 24.0

var hidden_inside := false

var _player: CharacterBody3D
var _prompt: Label3D
var _anim: AnimationPlayer
var _door_l: Node3D
var _door_r: Node3D
var _e_prev := false
var _enter_time := 0.0
var _busy := false
var _exiting := false
var _saved := {}
var _overlay: CanvasLayer
var _ov_mat: ShaderMaterial
var _marker: Control
var _hint_root: Control
var _status_dot: Label
var _status_lbl: Label
var _status_id := -1
var _player_ref: CharacterBody3D
var _hidden_meshes: Array[GeometryInstance3D] = []
var _spot_hidden: Array[MeshInstance3D] = []
var _cam_y := 0.0
var _t := 0.0
var _prox := 99.0
var _prox_t := 0.0
var _heart: AudioStreamPlayer
var _heart_t := 0.0
static var _heart_cache: AudioStreamWAV
static var _view_shader: Shader
static var _sil_shader: Shader

# keadaan tampilan
var _open_t := 0.0          ## 0 = tertutup rapat, 1 = celah terbuka penuh
var _fade := 1.0            ## 1 = tampil, 0 = hilang
var _hint_a := 0.0
var _danger := 0.0          ## 0 aman, 1 Jennifer sangat dekat
var _beat := 0.0            ## berdenyut 1 -> 0 tiap detak jantung
var _face_yaw := 0.0        ## arah hadap player supaya menghadap keluar
var _look := Vector2.ZERO   ## offset menoleh, -1..1
var _fade_tw: Tween

# guru terdekat, siluet, penanda
var _near: Node3D
var _near_d := 999.0
var _sil_mat: ShaderMaterial
var _sil_meshes: Array[MeshInstance3D] = []
var _sil_prev: Array[Material] = []
var _sil_k := 0.0
var _mk_alpha := 0.0
var _mk_on := false
var _mk_pos := Vector2.ZERO
var _mk_ang := 0.0
var _mk_col := Color.WHITE
var _mk_text := ""


func _ready() -> void:
	add_to_group("hide_spot")
	process_priority = 50   # jalan SETELAH kamera, supaya batas menoleh selalu menang
	if build_model:
		_load_model()
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 34
	_prompt.pixel_size = 0.005
	_prompt.outline_size = 10
	_prompt.position = Vector3(0, 2.4 if kind == Kind.LEMARI else 1.2, 0)
	_prompt.text = "Press [E] to hide"
	_prompt.visible = false
	add_child(_prompt)


# ------------------------------------------------------------------ dipakai Jennifer

## Titik di depan tempat sembunyi tempat Jennifer berdiri memeriksa.
func front_point() -> Vector3:
	return global_transform * exit_offset


## Jennifer membuka paksa (player ketahuan).
func force_open() -> void:
	_busy = true
	_set_model_visible(true)   # pintu / meja kelihatan lagi saat dibuka paksa
	_open_doors(1.7, 0.18)
	_fade_out_view(0.15)


## Jennifer memeriksa tapi kosong.
func empty_check() -> void:
	_open_doors(1.1, 0.25)
	await get_tree().create_timer(0.9).timeout
	_open_doors(0.0, 0.25)


# ------------------------------------------------------------------ interaksi player

func _process(delta: float) -> void:
	_overlay_tick(delta)   # tetap jalan walau _busy, supaya fade-out layar selesai
	var e_now := Input.is_physical_key_pressed(KEY_E)
	var e_pressed := e_now and not _e_prev
	_e_prev = e_now
	if _busy:
		return
	if hidden_inside:
		_hidden_tick(delta)
		if e_pressed and not _exiting and Time.get_ticks_msec() / 1000.0 - _enter_time > 0.7:
			_exit()
		return
	if _player_ref == null or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player_ref == null:
			return
	# hemat CPU (bisa ratusan tempat sembunyi): detail dicek cuma kalau player dekat
	if global_position.distance_to(_player_ref.global_position) > use_distance + 4.0:
		if _prompt.visible:
			_prompt.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or bool(_player_ref.get_meta("hidden", false)):
		_prompt.visible = false
		return
	var center := global_position + Vector3.UP * (1.0 if kind == Kind.LEMARI else 0.5)
	var to_spot := center - cam.global_position
	var dist := to_spot.length()
	var looking := dist < use_distance and dist > 0.01 and (-cam.global_transform.basis.z).dot(to_spot / dist) > look_dot
	_prompt.visible = looking
	if looking and e_pressed:
		_enter(_player_ref, cam)


func _enter(player: CharacterBody3D, cam: Camera3D) -> void:
	var seen := _seen_by_teacher(player, cam)
	_player = player
	_saved = {
		"pos": player.global_position,
		"layer": player.collision_layer,
		"mask": player.collision_mask,
		"cam_dy": cam.global_position.y - player.global_position.y,
	}
	player.velocity = Vector3.ZERO
	var inside := global_transform * hide_offset
	player.global_position = Vector3(inside.x, player.global_position.y, inside.z)
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.set_meta("hidden", true)
	_set_player_meshes(player, false)   # badan player disembunyikan supaya nggak kelihatan nembus lantai/meja
	# tinggi kamera: kolong = dekat lantai (diukur dari lantai tempat sembunyi), lemari = tinggi berdiri
	var target_y := global_position.y + peek_height if kind == Kind.KOLONG_MEJA else player.global_position.y + float(_saved["cam_dy"])
	_cam_y = cam.global_position.y
	create_tween().tween_property(self, "_cam_y", target_y, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if kind == Kind.LEMARI:
		_open_doors(1.4, 0.2)
		get_tree().create_timer(0.5).timeout.connect(func(): _open_doors(0.0, 0.35))
	hidden_inside = true
	_exiting = false
	_enter_time = Time.get_ticks_msec() / 1000.0
	_t = 0.0
	_danger = 0.0
	_look = Vector2.ZERO
	_face_yaw = _outward_yaw()
	_prompt.visible = false
	_show_overlay()                # mulai TERTUTUP rapat (menutupi lompatan kamera), lalu celah terbuka pelan
	_set_model_visible(false)      # model lemari/meja disembunyikan dari kamera supaya pandangan ke luar bebas
	_silhouette_start()
	create_tween().tween_property(self, "_open_t", 1.0, 1.1).set_delay(0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	GameState.notice.emit("Hiding... stay quiet. Press [E] to exit")
	for tch in get_tree().get_nodes_in_group("teacher"):
		if tch.has_method("player_hid"):
			tch.call("player_hid", self, seen)


# Selama sembunyi: kamera "bernapas" halus, pandangan menghadap keluar dan dibatasi, siluet + penanda Jennifer diperbarui.
func _hidden_tick(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.global_position.y = _cam_y + sin(_t * 1.7) * 0.006
		_steer_look(cam, delta)
		_nearest_teacher(cam.global_position)
	_prox_t -= delta
	if _prox_t <= 0.0:
		_prox_t = 0.2
		_prox = 99.0
		for tch in get_tree().get_nodes_in_group("teacher"):
			_prox = minf(_prox, (tch as Node3D).global_position.distance_to(global_position))
	var target := clampf(1.0 - (_prox - 3.0) / 12.0, 0.0, 1.0)
	_danger = lerpf(_danger, target, clampf(delta * 3.0, 0.0, 1.0))
	if _heart != null and _danger > 0.05:
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = lerpf(1.0, 0.4, _danger)
			_heart.volume_db = lerpf(-26.0, -9.0, _danger)
			_heart.play()
			_beat = 1.0
	_update_status()
	_update_silhouette(delta)
	if cam != null:
		_update_marker(cam, delta)


# Arah hadap player (yaw dunia) supaya pandangannya lurus keluar dari bukaan.
func _outward_yaw() -> float:
	var f := global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.001:
		return 0.0
	f = f.normalized()
	return atan2(-f.x, -f.z)


# Memutar player menghadap keluar di awal, lalu membatasi menoleh (yaw + pitch) selama sembunyi.
func _steer_look(cam: Camera3D, delta: float) -> void:
	var yaw_lim := deg_to_rad(look_limit_yaw if look_limit_yaw > 0.0 else (60.0 if kind == Kind.LEMARI else 100.0))
	var pit_up := deg_to_rad(look_limit_pitch if look_limit_pitch > 0.0 else (22.0 if kind == Kind.LEMARI else 28.0))
	var pit_dn := deg_to_rad(look_limit_pitch if look_limit_pitch > 0.0 else (26.0 if kind == Kind.LEMARI else 14.0))
	var cur := _player.global_rotation.y
	if _t < 0.6:
		var k := clampf(delta * 8.0, 0.0, 1.0)
		cur = lerp_angle(cur, _face_yaw, k)
		cam.rotation.x = lerpf(cam.rotation.x, 0.0, k)
	var diff := wrapf(cur - _face_yaw, -PI, PI)
	var lim := clampf(diff, -yaw_lim, yaw_lim)
	_player.global_rotation.y = _face_yaw + lim
	cam.rotation.x = clampf(cam.rotation.x, -pit_dn, pit_up)
	var py := cam.rotation.x / (pit_up if cam.rotation.x > 0.0 else pit_dn)
	_look = Vector2(lim / yaw_lim, py)


func _set_player_meshes(player: Node, vis: bool) -> void:
	if vis:
		for g in _hidden_meshes:
			if is_instance_valid(g):
				g.visible = true
		_hidden_meshes.clear()
		return
	_hidden_meshes.clear()
	for n in player.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.visible:
			g.visible = false
			_hidden_meshes.append(g)


# Model lemari / meja milik tempat ini disembunyikan dari kamera selama player di dalam (kalau nggak, dindingnya menghalangi pandangan).
func _set_model_visible(vis: bool) -> void:
	if vis:
		for g in _spot_hidden:
			if is_instance_valid(g):
				g.visible = true
		_spot_hidden.clear()
		return
	_spot_hidden.clear()
	for n in find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		if g != null and g.visible:
			g.visible = false
			_spot_hidden.append(g)


func _exit() -> void:
	_exiting = true
	# celah menutup cepat, baru pindah ke luar (supaya perpindahan kamera tertutup)
	var tw := create_tween()
	tw.tween_property(self, "_open_t", 0.0, 0.22).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if _busy or not hidden_inside:
		return
	var out := global_transform * exit_offset
	var saved_pos: Vector3 = _saved["pos"]
	_player.global_position = Vector3(out.x, saved_pos.y, out.z)
	_player.collision_layer = int(_saved["layer"])
	_player.collision_mask = int(_saved["mask"])
	_player.set_physics_process(true)
	_player.remove_meta("hidden")
	_set_player_meshes(_player, true)
	_set_model_visible(true)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.global_position.y = _player.global_position.y + float(_saved["cam_dy"])
	hidden_inside = false
	if kind == Kind.LEMARI:
		_open_doors(1.4, 0.25)
		get_tree().create_timer(1.2).timeout.connect(func(): _open_doors(0.0, 0.35))
	_fade_out_view(0.35)
	_exiting = false
	for tch in get_tree().get_nodes_in_group("teacher"):
		if tch.has_method("player_left_hiding"):
			tch.call("player_left_hiding")


# Jennifer melihat player masuk? (dekat dan tanpa penghalang pandangan)
func _seen_by_teacher(player: Node3D, cam: Camera3D) -> bool:
	var space := get_world_3d().direct_space_state
	for t in get_tree().get_nodes_in_group("teacher"):
		var tn := t as Node3D
		if tn == null:
			continue
		var from := tn.global_position + Vector3.UP * 2.0
		var to := cam.global_position
		if from.distance_to(to) > see_distance:
			continue
		# harus ada di depan pandangan Jennifer (sebelumnya dia bisa "melihat" lewat punggungnya)
		if t.has_method("facing_dir"):
			var fd: Vector3 = t.call("facing_dir")
			var flat := player.global_position - tn.global_position
			flat.y = 0.0
			if fd != Vector3.ZERO and flat.length() > 0.5 and fd.dot(flat.normalized()) < see_fov_dot:
				continue
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collide_with_areas = false
		q.exclude = [(t as CollisionObject3D).get_rid(), player.get_rid()]
		if space.intersect_ray(q).is_empty():
			return true
	return false


# ------------------------------------------------------------------ layar sembunyi

static func _get_view_shader() -> Shader:
	if _view_shader == null:
		_view_shader = Shader.new()
		_view_shader.code = VIEW_SHADER
	return _view_shader


static func _get_sil_shader() -> Shader:
	if _sil_shader == null:
		_sil_shader = Shader.new()
		_sil_shader.code = SIL_SHADER
	return _sil_shader


# Layar sembunyi: bingkai kayu dengan celah intip (shader) + penanda Jennifer + panel [E] Keluar / status bahaya + detak jantung.
# Layer 9 (di bawah HUD layer 10) supaya notifikasi HUD tetap terbaca.
func _show_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	if _fade_tw != null:
		_fade_tw.kill()
	_open_t = 0.0
	_fade = 1.0
	_hint_a = 0.0
	_beat = 0.0
	_mk_alpha = 0.0
	_status_id = -1
	_overlay = CanvasLayer.new()
	_overlay.layer = 9
	add_child(_overlay)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)

	var view := ColorRect.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov_mat = ShaderMaterial.new()
	_ov_mat.shader = _get_view_shader()
	var lemari := kind == Kind.LEMARI
	var half := peek_size
	if half == Vector2.ZERO:
		half = Vector2(0.40, 0.47) if lemari else Vector2(0.93, 0.41)
	_ov_mat.set_shader_parameter("mode", 0 if lemari else 1)
	_ov_mat.set_shader_parameter("slit_half", half)
	_ov_mat.set_shader_parameter("slit_center", Vector2(0.0, 0.0))
	view.material = _ov_mat
	root.add_child(view)

	_marker = Control.new()
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_marker_draw)
	root.add_child(_marker)

	_build_hint(root)

	_heart = AudioStreamPlayer.new()
	_heart.stream = _make_heart()
	_overlay.add_child(_heart)
	_heart_t = 0.0
	create_tween().tween_property(self, "_hint_a", 1.0, 0.7).set_delay(1.0)


# Panel kecil di bawah: tombol [E] Keluar + status jarak Jennifer (Aman / Waspada / Bahaya).
func _build_hint(root: Control) -> void:
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("margin_bottom", 48 if kind == Kind.LEMARI else 20)
	root.add_child(wrap)
	_hint_root = wrap

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(col)

	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.015, 0.015, 0.62)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	pill.add_theme_stylebox_override("panel", sb)
	col.add_child(pill)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)

	var key := PanelContainer.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(1, 1, 1, 0.14)
	ksb.set_corner_radius_all(6)
	ksb.set_border_width_all(1)
	ksb.border_color = Color(1, 1, 1, 0.35)
	ksb.content_margin_left = 9.0
	ksb.content_margin_right = 9.0
	ksb.content_margin_top = 1.0
	ksb.content_margin_bottom = 1.0
	key.add_theme_stylebox_override("panel", ksb)
	var kl := Label.new()
	kl.text = "E"
	kl.add_theme_font_size_override("font_size", 18)
	key.add_child(kl)
	row.add_child(key)

	var out_lbl := Label.new()
	out_lbl.text = "Exit"
	out_lbl.add_theme_font_size_override("font_size", 18)
	out_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	row.add_child(out_lbl)

	var sep := VSeparator.new()
	row.add_child(sep)

	_status_dot = Label.new()
	_status_dot.text = "●"
	_status_dot.add_theme_font_size_override("font_size", 16)
	row.add_child(_status_dot)
	_status_lbl = Label.new()
	_status_lbl.text = "SAFE"
	_status_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(_status_lbl)


# Mengirim keadaan ke shader tiap frame (juga selama fade-out setelah keluar / dibuka paksa).
func _overlay_tick(delta: float) -> void:
	if _ov_mat == null:
		return
	_beat = maxf(_beat - delta * 3.5, 0.0)
	var vp := get_viewport().get_visible_rect().size
	_ov_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_ov_mat.set_shader_parameter("open_t", _open_t)
	_ov_mat.set_shader_parameter("fade", _fade)
	_ov_mat.set_shader_parameter("danger", _danger)
	_ov_mat.set_shader_parameter("beat", _beat)
	_ov_mat.set_shader_parameter("look", _look)
	if _hint_root != null:
		_hint_root.modulate.a = _hint_a * _fade
	if _marker != null:
		_marker.modulate.a = _fade


func _update_status() -> void:
	if _status_lbl == null:
		return
	var id := 0
	if _danger > 0.65:
		id = 2
	elif _danger > 0.25:
		id = 1
	if id == _status_id:
		return
	_status_id = id
	var txt := "SAFE"
	var col := Color(0.62, 0.92, 0.66)
	if id == 1:
		txt = "ALERT"
		col = Color(1.0, 0.8, 0.35)
	elif id == 2:
		txt = "DANGER"
		col = Color(1.0, 0.3, 0.25)
	_status_lbl.text = txt
	_status_lbl.add_theme_color_override("font_color", col)
	_status_dot.add_theme_color_override("font_color", col)


func _fade_out_view(secs: float) -> void:
	_silhouette_stop()
	if _overlay == null:
		return
	var ov := _overlay
	if _fade_tw != null:
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(self, "_fade", 0.0, secs)
	_fade_tw.tween_callback(_free_view.bind(ov))


func _free_view(ov: CanvasLayer) -> void:
	if is_instance_valid(ov):
		ov.queue_free()
	if _overlay == ov:
		_overlay = null
		_ov_mat = null
		_marker = null
		_hint_root = null
		_status_lbl = null
		_status_dot = null
		_heart = null


# ------------------------------------------------------------------ posisi Jennifer: siluet + penanda

func _nearest_teacher(from: Vector3) -> void:
	_near = null
	_near_d = 999.0
	for t in get_tree().get_nodes_in_group("teacher"):
		var tn := t as Node3D
		if tn == null:
			continue
		var d := tn.global_position.distance_to(from)
		if d < _near_d:
			_near_d = d
			_near = tn


# Siluet merah menembus tembok/meja: kelihatan di mana Jennifer berjalan walau terhalang. Makin dekat makin jelas.
func _silhouette_start() -> void:
	_silhouette_stop()
	if not see_teacher_through_walls:
		return
	_sil_mat = ShaderMaterial.new()
	_sil_mat.shader = _get_sil_shader()
	_sil_mat.render_priority = 100
	_sil_mat.set_shader_parameter("strength", 0.0)
	_sil_k = 0.0
	for t in get_tree().get_nodes_in_group("teacher"):
		for n in t.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null:
				continue
			_sil_meshes.append(mi)
			_sil_prev.append(mi.material_overlay)
			mi.material_overlay = _sil_mat


func _silhouette_stop() -> void:
	for i in _sil_meshes.size():
		if is_instance_valid(_sil_meshes[i]):
			_sil_meshes[i].material_overlay = _sil_prev[i]
	_sil_meshes.clear()
	_sil_prev.clear()
	_sil_mat = null


func _update_silhouette(delta: float) -> void:
	if _sil_mat == null:
		return
	var want := 0.0
	if _near != null and not _exiting:
		want = clampf(1.0 - _near_d / silhouette_range, 0.0, 1.0)
	_sil_k = lerpf(_sil_k, want, clampf(delta * 4.0, 0.0, 1.0))
	var vis := clampf(_open_t * 2.0 - 0.4, 0.0, 1.0)
	_sil_mat.set_shader_parameter("strength", _sil_k * 0.85 * vis)
	_sil_mat.set_shader_parameter("pulse", _beat)


# Penanda: kalau Jennifer ada di layar = lingkaran + jarak di atas kepalanya; kalau di luar layar = panah di tepi layar.
func _update_marker(cam: Camera3D, delta: float) -> void:
	if _marker == null:
		return
	var want := 0.0
	if show_teacher_marker and _near != null and not _exiting:
		want = clampf(1.2 - _near_d / marker_range, 0.0, 1.0) * clampf(_open_t * 2.0 - 0.3, 0.0, 1.0)
	_mk_alpha = lerpf(_mk_alpha, want, clampf(delta * 6.0, 0.0, 1.0))
	if _near != null:
		var vp := get_viewport().get_visible_rect().size
		var head := _near.global_position + Vector3.UP * 2.75
		var margin := 64.0
		var sp := cam.unproject_position(head)
		var safe := Rect2(Vector2(margin, margin), vp - Vector2(margin, margin) * 2.0)
		if not cam.is_position_behind(head) and safe.has_point(sp):
			_mk_on = true
			_mk_pos = sp
		else:
			_mk_on = false
			var rel := cam.global_transform.affine_inverse() * _near.global_position
			var dir := Vector2(rel.x, rel.z)   # x = kanan, z negatif = depan (= atas di layar)
			if dir.length() < 0.001:
				dir = Vector2.DOWN
			dir = dir.normalized()
			var half := vp * 0.5 - Vector2(margin + 20.0, margin + 40.0)
			var k := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
			_mk_pos = vp * 0.5 + dir * k
			_mk_ang = dir.angle()
	_mk_col = Color(0.92, 0.92, 0.85).lerp(Color(1.0, 0.18, 0.14), _danger)
	_mk_text = "%d m" % int(roundf(_near_d))
	_marker.queue_redraw()


func _marker_draw() -> void:
	if _marker == null or _mk_alpha < 0.02:
		return
	var c := Color(_mk_col.r, _mk_col.g, _mk_col.b, _mk_alpha)
	var shade := Color(0, 0, 0, _mk_alpha * 0.7)
	var font := ThemeDB.fallback_font
	var fs := 17
	if _mk_on:
		var r := 17.0 * (1.0 + _beat * 0.25)
		_marker.draw_arc(_mk_pos, r + 1.5, 0.0, TAU, 40, shade, 4.0, true)
		_marker.draw_arc(_mk_pos, r, 0.0, TAU, 40, c, 2.0, true)
		_marker.draw_circle(_mk_pos, 3.5, c)
		var tp := _mk_pos + Vector2(-40.0, 42.0)
		_marker.draw_string_outline(font, tp, _mk_text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, fs, 5, shade)
		_marker.draw_string(font, tp, _mk_text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, fs, c)
	else:
		var dir := Vector2.from_angle(_mk_ang)
		var side := dir.orthogonal()
		var p0 := _mk_pos
		var pts := PackedVector2Array([
			p0 + dir * 16.0,
			p0 - dir * 8.0 + side * 13.0,
			p0 - dir * 2.0,
			p0 - dir * 8.0 - side * 13.0,
		])
		_marker.draw_colored_polygon(pts, c)
		var tp2 := p0 - dir * 32.0 + Vector2(-40.0, 6.0)
		_marker.draw_string_outline(font, tp2, _mk_text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, fs, 5, shade)
		_marker.draw_string(font, tp2, _mk_text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, fs, c)


static func _make_heart() -> AudioStreamWAV:
	if _heart_cache != null:
		return _heart_cache
	var rate := 22050
	var count := int(rate * 0.5)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var s := sin(TAU * (62.0 - 26.0 * t) * t) * exp(-t * 20.0)
		var t2 := t - 0.17
		if t2 > 0.0:
			s += 0.75 * sin(TAU * (54.0 - 20.0 * t2) * t2) * exp(-t2 * 24.0)
		bytes.encode_s16(i * 2, int(clampf(s * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	_heart_cache = wav
	return wav


# ------------------------------------------------------------------ model

# Pakai GLB (lemari.glb / meja_guru.glb di res://models/) kalau ada, kalau nggak ada pakai bentuk kode.
func _load_model() -> void:
	var scene := model_scene
	if scene == null:
		var path := "res://models/lemari.glb" if kind == Kind.LEMARI else "res://models/meja_guru.glb"
		if ResourceLoader.exists(path):
			scene = load(path) as PackedScene
	if scene == null:
		if kind == Kind.LEMARI:
			_build_lemari()
		else:
			_build_meja()
		return
	var inst := scene.instantiate() as Node3D
	add_child(inst)
	_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_door_l = inst.find_child("DoorL", true, false) as Node3D
	_door_r = inst.find_child("DoorR", true, false) as Node3D
	if kind == Kind.LEMARI:
		var box := AABB()
		var has := false
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var part: AABB = (global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
			box = box.merge(part) if has else part
			has = true
		if has:
			_box(self, box.size, box.get_center(), null, true)
	else:
		_box(self, Vector3(1.5, 0.05, 0.75), Vector3(0, 0.75, 0), null, true)
		_box(self, Vector3(0.04, 0.75, 0.71), Vector3(-0.71, 0.375, 0), null, true)
		_box(self, Vector3(0.04, 0.75, 0.71), Vector3(0.71, 0.375, 0), null, true)
		_box(self, Vector3(1.38, 0.7, 0.03), Vector3(0, 0.375, -0.32), null, true)


# ------------------------------------------------------------------ model bawaan (bentuk kode)

func _open_doors(angle: float, secs: float) -> void:
	if _anim != null and _anim.has_animation("open"):
		if angle > 0.5:
			_anim.play("open", -1.0, 0.45 / maxf(secs, 0.1))
		else:
			_anim.play("close", -1.0, 0.45 / maxf(secs, 0.1))
		return
	if _door_l == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_door_l, "rotation:y", -angle, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_door_r, "rotation:y", angle, secs).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, solid := false) -> void:
	if mat != null:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.material_override = mat
		mi.position = pos
		parent.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		parent.add_child(body)


func _build_lemari() -> void:
	var w := 1.1
	var h := 2.1
	var d := 0.7
	var wood := _mat(Color(0.30, 0.18, 0.09))
	var door_wood := _mat(Color(0.36, 0.22, 0.11))
	var dark := _mat(Color(0.03, 0.02, 0.02))
	var metal := _mat(Color(0.7, 0.62, 0.3))
	_box(self, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wood, true)
	_box(self, Vector3(w - 0.12, h - 0.12, 0.02), Vector3(0, h * 0.5, d * 0.5 + 0.005), dark)   # bagian dalam gelap
	_door_l = _make_door(-1.0, w, h, d, door_wood, dark, metal)
	_door_r = _make_door(1.0, w, h, d, door_wood, dark, metal)


func _make_door(side: float, w: float, h: float, d: float, wood: Material, dark: Material, metal: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * (w * 0.5 - 0.02), 0, d * 0.5)
	add_child(pivot)
	var dw := w * 0.5 - 0.03
	var cx := -side * dw * 0.5
	_box(pivot, Vector3(dw, h - 0.12, 0.04), Vector3(cx, h * 0.5, 0.02), wood)
	for i in 4:   # celah ventilasi tempat mengintip
		_box(pivot, Vector3(dw * 0.7, 0.025, 0.045), Vector3(cx, 1.55 + i * 0.07, 0.022), dark)
	_box(pivot, Vector3(0.03, 0.18, 0.04), Vector3(-side * (dw - 0.07), 1.0, 0.055), metal)
	return pivot


func _build_meja() -> void:
	var w := 1.5
	var d := 0.75
	var top_y := 0.75
	var wood := _mat(Color(0.42, 0.28, 0.15))
	var dark_wood := _mat(Color(0.3, 0.19, 0.1))
	_box(self, Vector3(w, 0.05, d), Vector3(0, top_y, 0), wood, true)
	_box(self, Vector3(0.04, top_y, d - 0.04), Vector3(-w * 0.5 + 0.04, top_y * 0.5, 0), dark_wood, true)
	_box(self, Vector3(0.04, top_y, d - 0.04), Vector3(w * 0.5 - 0.04, top_y * 0.5, 0), dark_wood, true)
	_box(self, Vector3(w - 0.12, top_y - 0.05, 0.03), Vector3(0, top_y * 0.5, -d * 0.5 + 0.05), dark_wood, true)
