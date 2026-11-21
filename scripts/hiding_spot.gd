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

enum Kind { LEMARI, KOLONG_MEJA }

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

var hidden_inside := false

var _player: CharacterBody3D
var _prompt: Label3D
var _anim: AnimationPlayer
var _door_l: Node3D
var _door_r: Node3D
var _e_prev := false
var _enter_time := 0.0
var _busy := false
var _saved := {}
var _overlay: CanvasLayer
var _vignette: TextureRect
var _player_ref: CharacterBody3D
var _hidden_meshes: Array[GeometryInstance3D] = []
var _cam_y := 0.0
var _t := 0.0
var _prox := 99.0
var _prox_t := 0.0
var _heart: AudioStreamPlayer
var _heart_t := 0.0
static var _heart_cache: AudioStreamWAV


func _ready() -> void:
	add_to_group("hide_spot")
	if build_model:
		_load_model()
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 34
	_prompt.pixel_size = 0.005
	_prompt.outline_size = 10
	_prompt.position = Vector3(0, 2.4 if kind == Kind.LEMARI else 1.2, 0)
	_prompt.text = "Tekan [E] untuk bersembunyi"
	_prompt.visible = false
	add_child(_prompt)


# ------------------------------------------------------------------ dipakai Jennifer

## Titik di depan tempat sembunyi tempat Jennifer berdiri memeriksa.
func front_point() -> Vector3:
	return global_transform * exit_offset


## Jennifer membuka paksa (player ketahuan).
func force_open() -> void:
	_busy = true
	_open_doors(1.7, 0.18)


## Jennifer memeriksa tapi kosong.
func empty_check() -> void:
	_open_doors(1.1, 0.25)
	await get_tree().create_timer(0.9).timeout
	_open_doors(0.0, 0.25)


# ------------------------------------------------------------------ interaksi player

func _process(delta: float) -> void:
	var e_now := Input.is_physical_key_pressed(KEY_E)
	var e_pressed := e_now and not _e_prev
	_e_prev = e_now
	if _busy:
		return
	if hidden_inside:
		_hidden_tick(delta)
		if e_pressed and Time.get_ticks_msec() / 1000.0 - _enter_time > 0.7:
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
	_enter_time = Time.get_ticks_msec() / 1000.0
	_t = 0.0
	_prompt.visible = false
	_show_overlay()
	GameState.notice.emit("Bersembunyi... diam. Tekan [E] untuk keluar")
	for tch in get_tree().get_nodes_in_group("teacher"):
		if tch.has_method("player_hid"):
			tch.call("player_hid", self, seen)


# Selama sembunyi: kamera "bernapas" halus; kalau Jennifer dekat, layar memerah berdenyut dan terdengar detak jantung.
func _hidden_tick(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.global_position.y = _cam_y + sin(_t * 1.7) * 0.006
	_prox_t -= delta
	if _prox_t <= 0.0:
		_prox_t = 0.2
		_prox = 99.0
		for tch in get_tree().get_nodes_in_group("teacher"):
			_prox = minf(_prox, (tch as Node3D).global_position.distance_to(global_position))
	var danger := clampf(1.0 - (_prox - 3.0) / 12.0, 0.0, 1.0)
	if _vignette != null:
		var a := 0.62 + 0.2 * danger + 0.12 * danger * sin(_t * (3.0 + danger * 9.0))
		_vignette.modulate = Color(1.0, 1.0 - danger * 0.65, 1.0 - danger * 0.65, a)
	if _heart != null and danger > 0.05:
		_heart_t -= delta
		if _heart_t <= 0.0:
			_heart_t = lerpf(1.0, 0.4, danger)
			_heart.volume_db = lerpf(-26.0, -9.0, danger)
			_heart.play()


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


func _exit() -> void:
	var out := global_transform * exit_offset
	var saved_pos: Vector3 = _saved["pos"]
	_player.global_position = Vector3(out.x, saved_pos.y, out.z)
	_player.collision_layer = int(_saved["layer"])
	_player.collision_mask = int(_saved["mask"])
	_player.set_physics_process(true)
	_player.remove_meta("hidden")
	_set_player_meshes(_player, true)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.global_position.y = _player.global_position.y + float(_saved["cam_dy"])
	hidden_inside = false
	if kind == Kind.LEMARI:
		_open_doors(1.4, 0.25)
		get_tree().create_timer(1.2).timeout.connect(func(): _open_doors(0.0, 0.35))
	if _overlay != null:
		var ov := _overlay
		_overlay = null
		_vignette = null
		_heart = null
		var tw := create_tween()
		tw.tween_property(ov.get_child(0), "modulate:a", 0.0, 0.25)
		tw.tween_callback(ov.queue_free)
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


func _grad_tex(top: bool) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.97))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0, 0) if top else Vector2(0, 1)
	gt.fill_to = Vector2(0, 1) if top else Vector2(0, 0)
	gt.width = 4
	gt.height = 256
	return gt


# Layar sembunyi: dua pita gelap berujung halus menutup perlahan (mengintip dari celah) + vignette + detak jantung.
func _show_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 40
	add_child(_overlay)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)
	var size_top := 0.34 if kind == Kind.LEMARI else 0.42
	var size_bottom := 0.32 if kind == Kind.LEMARI else 0.26
	for top in [true, false]:
		var r := TextureRect.new()
		r.texture = _grad_tex(top)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.anchor_left = 0.0
		r.anchor_right = 1.0
		if top:
			r.anchor_top = 0.0
			r.anchor_bottom = 0.0
			root.add_child(r)
			create_tween().tween_property(r, "anchor_bottom", size_top, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			r.anchor_top = 1.0
			r.anchor_bottom = 1.0
			root.add_child(r)
			create_tween().tween_property(r, "anchor_top", 1.0 - size_bottom, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.95))
	var rt := GradientTexture2D.new()
	rt.gradient = grad
	rt.fill = GradientTexture2D.FILL_RADIAL
	rt.fill_from = Vector2(0.5, 0.5)
	rt.fill_to = Vector2(1.0, 0.5)
	rt.width = 512
	rt.height = 512
	_vignette = TextureRect.new()
	_vignette.texture = rt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 1, 1, 0.0)
	root.add_child(_vignette)
	var hint := Label.new()
	hint.text = "[E]  Keluar"
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -64.0
	hint.offset_bottom = -22.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	hint.modulate = Color(1, 1, 1, 0.0)
	root.add_child(hint)
	create_tween().tween_property(hint, "modulate:a", 0.65, 1.2).set_delay(0.6)
	_heart = AudioStreamPlayer.new()
	_heart.stream = _make_heart()
	_overlay.add_child(_heart)
	_heart_t = 0.0


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
