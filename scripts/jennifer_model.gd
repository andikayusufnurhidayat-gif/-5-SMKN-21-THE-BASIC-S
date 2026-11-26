@tool
extends Node3D
## Model 3D Ms. Jennifer versi SERAM, dari bentuk dasar lewat kode. Depan model = sumbu +Z.
## Tinggi sekitar 2,6 m (lebih tinggi dari player 2,0 m), badan kurus, lengan sampai lutut, kepala lonjong,
## mata melotot dengan pupil kecil di cekungan gelap, mulut cemberut lebar, kepala miring dan sesekali nyentak.
## Warna/tekstur kerudung dan mantel diambil dari gambar aslinya.
##
## API (dipanggil teacher.gd):
##   set_motion(kecepatan_rasio, mengejar)  -> jalan kaku; saat ngejar kedua tangan terjulur ke depan
##   wave(detik)                            -> lambaian pelan yang bikin merinding
##   set_mood("calm" | "angry" | "shout")   -> ekspresi

const SKIN := Color(0.56, 0.58, 0.50)
const HIJAB := Color(0.09, 0.14, 0.08)
const SCARF := Color(0.20, 0.26, 0.15)
const COAT := Color(0.11, 0.17, 0.10)
const PANTS := Color(0.05, 0.06, 0.04)
const WOOD := Color(0.45, 0.36, 0.22)
const LIPS := Color(0.42, 0.10, 0.09)

var _t := 0.0
var _speed := 0.0
var _chasing := false
var _wave_left := 0.0
var _wave_w := 0.0
var _mood := "calm"
var _twitch_in := 2.0
var _twitch_amt := 0.0
var _eye_jit := 0.0
var _scare := false

var _body: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _brow_l: MeshInstance3D
var _brow_r: MeshInstance3D
var _eye_l: MeshInstance3D
var _eye_r: MeshInstance3D
var _pupil_l: MeshInstance3D
var _pupil_r: MeshInstance3D
var _mouth: MeshInstance3D
var _pupil_mat: StandardMaterial3D
var _mouth_mat: StandardMaterial3D


func _ready() -> void:
	scale = Vector3(0.88, 1.2, 0.88)   # lebih tinggi dan kurus
	_build()
	set_mood("calm")


# ------------------------------------------------------------------ API

func set_motion(speed_ratio: float, chasing: bool) -> void:
	_speed = speed_ratio
	_chasing = chasing


## Pose menerkam saat menangkap player (dipakai jumpscare.gd lewat teacher.gd).
func jumpscare() -> void:
	_scare = true
	set_mood("shout")


func wave(seconds := 4.0) -> void:
	_wave_left = seconds


func set_mood(mood: String) -> void:
	_mood = mood
	if _brow_l == null:
		return
	var angry := mood == "angry" or mood == "shout"
	_brow_l.rotation.z = -0.6 if angry else 0.3
	_brow_r.rotation.z = 0.6 if angry else -0.3
	_brow_l.position.y = 0.105 if angry else 0.135
	_brow_r.position.y = _brow_l.position.y
	var pupil_s := 1.0
	if mood == "angry":
		pupil_s = 0.8
	elif mood == "shout":
		pupil_s = 0.6
	_pupil_l.scale = Vector3.ONE * pupil_s
	_pupil_r.scale = Vector3.ONE * pupil_s
	_pupil_mat.emission_enabled = angry
	match mood:
		"angry":
			_mouth.scale = Vector3(1.2, 4.0, 1.0)
			_mouth_mat.albedo_color = Color(0.2, 0.02, 0.02)
		"shout":
			_mouth.scale = Vector3(1.1, 10.0, 1.0)
			_mouth_mat.albedo_color = Color(0.1, 0.0, 0.0)
		_:
			_mouth.scale = Vector3.ONE
			_mouth_mat.albedo_color = LIPS


# ------------------------------------------------------------------ animasi

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _leg_l == null:
		return
	_t += delta
	if _scare:
		_scare_pose(delta)
		return
	var sp := clampf(_speed, 0.0, 1.6)
	var moving := sp > 0.05
	var freq := 4.5 + sp * 4.0
	var ph := sin(_t * freq) if moving else 0.0
	var swing := 0.4 * minf(sp, 1.0)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, ph * swing, clampf(delta * 12.0, 0.0, 1.0))
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -ph * swing, clampf(delta * 12.0, 0.0, 1.0))

	# tangan: menjuntai kaku; saat ngejar terjulur ke depan, penggaris terangkat
	var chase_pose := _chasing and moving
	var l_idle := 0.05 + sin(_t * 1.3) * 0.04
	var r_idle := 0.12 + sin(_t * 1.1 + 1.0) * 0.04
	var l_target := -1.35 if chase_pose else l_idle
	var r_target := -0.95 if chase_pose else r_idle
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, r_target, clampf(delta * 7.0, 0.0, 1.0))

	# lambaian pelan dan kaku, kepala ikut miring
	_wave_left = maxf(_wave_left - delta, 0.0)
	_wave_w = move_toward(_wave_w, 1.0 if _wave_left > 0.0 else 0.0, delta * 2.5)
	_arm_l.rotation.x = lerpf(lerpf(_arm_l.rotation.x, l_target, clampf(delta * 7.0, 0.0, 1.0)), -2.6, _wave_w)
	_arm_l.rotation.z = lerpf(0.0, 0.3 + sin(_t * 4.5) * 0.35, _wave_w)

	# badan: bergoyang pelan, condong saat ngejar (tanpa loncat-loncat)
	_body.rotation.z = sin(_t * freq * 0.5) * 0.05 * minf(sp, 1.0) + sin(_t * 0.8) * 0.01
	var lean := 0.24 if chase_pose else 0.0
	_body.rotation.x = lerpf(_body.rotation.x, lean, clampf(delta * 5.0, 0.0, 1.0))
	_body.scale.y = 1.0 + sin(_t * 1.6) * 0.008   # napas

	# kepala: miring, sesekali nyentak tiba-tiba
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch_in = randf_range(1.2, 3.8)
		_twitch_amt = randf_range(-0.55, 0.55)
	_twitch_amt = move_toward(_twitch_amt, 0.0, delta * 1.4)
	_head.rotation.y = _twitch_amt
	var tilt := 0.2 if _mood == "calm" else 0.12
	_head.rotation.z = tilt + (sin(_t * 22.0) * 0.05 if _mood == "shout" else 0.0)
	_head.rotation.x = 0.1 if chase_pose else 0.0

	# pupil gemetar halus
	_eye_jit -= delta
	if _eye_jit <= 0.0:
		_eye_jit = 0.08
		_pupil_l.position.x = -0.075 + randf_range(-0.005, 0.005)
		_pupil_r.position.x = 0.075 + randf_range(-0.005, 0.005)
		_pupil_l.position.y = 0.045 + randf_range(-0.004, 0.004)
		_pupil_r.position.y = _pupil_l.position.y
	var eye_s := _target_eye() * (1.0 + sin(_t * 3.0) * 0.02)
	_eye_l.scale = _eye_l.scale.lerp(Vector3.ONE * eye_s, clampf(delta * 8.0, 0.0, 1.0))
	_eye_r.scale = _eye_l.scale


func _scare_pose(delta: float) -> void:
	var k := clampf(delta * 12.0, 0.0, 1.0)
	_body.rotation.x = lerpf(_body.rotation.x, 0.5, k)
	_body.position.x = sin(_t * 50.0) * 0.02
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.1, k)
	_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.9, k)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.9, k)
	_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.9, k)
	_head.rotation.x = lerpf(_head.rotation.x, 0.35, k)
	_head.rotation.y = sin(_t * 33.0) * 0.15
	_head.rotation.z = sin(_t * 40.0) * 0.12
	_mouth.scale = Vector3(1.3, 14.0 + sin(_t * 30.0) * 3.0, 1.0)
	_eye_l.scale = _eye_l.scale.lerp(Vector3.ONE * (1.5 + sin(_t * 25.0) * 0.08), k)
	_eye_r.scale = _eye_l.scale


func _target_eye() -> float:
	return 1.3 if _mood == "shout" else (1.15 if _mood == "angry" else 1.0)


# ------------------------------------------------------------------ bangun model

func _mat(color: Color, tex_path := "", uv := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex != null:
			m.albedo_texture = tex
			m.albedo_color = Color(0.85, 0.85, 0.85)
			m.uv1_scale = Vector3(uv, uv, uv)
			m.texture_repeat = true
	return m


func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0.0 else r * 2.0
	return s


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _build() -> void:
	var coat_mat := _mat(COAT, "res://characters/jennifer_coat.png", 1.0)
	var hijab_mat := _mat(HIJAB)
	var scarf_mat := _mat(SCARF, "res://characters/jennifer_hijab.png", 2.0)
	var skin_mat := _mat(SKIN)
	var pants_mat := _mat(PANTS)

	_leg_l = _make_leg(-0.1, pants_mat)
	_leg_r = _make_leg(0.1, pants_mat)

	_body = Node3D.new()
	add_child(_body)

	# mantel panjang yang kumal: sempit di bahu, compang-camping di ujung
	var coat := CylinderMesh.new()
	coat.top_radius = 0.17
	coat.bottom_radius = 0.26
	coat.height = 0.95
	coat.radial_segments = 16
	_add(_body, coat, coat_mat, Vector3(0, 1.12, 0), Vector3(1, 1, 0.62))
	var rag_mat := _mat(Color(0.04, 0.07, 0.04))
	for i in 5:
		var a := -0.8 + i * 0.4
		_add(_body, _box(0.07, 0.24, 0.012), rag_mat, Vector3(sin(a) * 0.24, 0.62, cos(a) * 0.15), Vector3.ONE, Vector3(0.1, a * 0.3, randf_range(-0.15, 0.15)))
	var belt := CylinderMesh.new()
	belt.top_radius = 0.185
	belt.bottom_radius = 0.185
	belt.height = 0.05
	_add(_body, belt, _mat(Color(0.07, 0.1, 0.06)), Vector3(0, 1.17, 0), Vector3(1, 1, 0.64))

	# kerudung menjuntai di bahu
	_add(_body, _sphere(0.27, 0.34), scarf_mat, Vector3(0, 1.5, -0.01), Vector3(1.05, 1.0, 0.85))

	# kepala lonjong
	_head = Node3D.new()
	_head.position = Vector3(0, 1.84, 0)
	_body.add_child(_head)
	_add(_head, _sphere(0.2, 0.62), hijab_mat, Vector3(0, 0.03, -0.04))
	_add(_head, _sphere(0.155, 0.52), skin_mat, Vector3(0, 0.0, 0.065))
	# cekungan gelap di sekitar mata
	var socket_mat := _mat(Color(0.04, 0.03, 0.03))
	_add(_head, _sphere(0.085), socket_mat, Vector3(-0.072, 0.045, 0.175), Vector3(1.0, 1.25, 0.55))
	_add(_head, _sphere(0.085), socket_mat, Vector3(0.072, 0.045, 0.175), Vector3(1.0, 1.25, 0.55))
	# mata melotot, pupil kecil
	var white := _mat(Color(0.9, 0.9, 0.82))
	_eye_l = _add(_head, _sphere(0.062), white, Vector3(-0.075, 0.045, 0.205))
	_eye_r = _add(_head, _sphere(0.062), white, Vector3(0.075, 0.045, 0.205))
	_pupil_mat = _mat(Color(0.01, 0.01, 0.01))
	_pupil_mat.emission = Color(1.0, 0.08, 0.04)
	_pupil_mat.emission_energy_multiplier = 2.5
	_pupil_l = _add(_head, _sphere(0.017), _pupil_mat, Vector3(-0.075, 0.045, 0.262))
	_pupil_r = _add(_head, _sphere(0.017), _pupil_mat, Vector3(0.075, 0.045, 0.262))
	# alis tebal
	var brow_mat := _mat(Color(0.07, 0.05, 0.03))
	_brow_l = _add(_head, _box(0.09, 0.02, 0.016), brow_mat, Vector3(-0.075, 0.135, 0.205))
	_brow_r = _add(_head, _box(0.09, 0.02, 0.016), brow_mat, Vector3(0.075, 0.135, 0.205))
	# hidung panjang
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.026
	nose.height = 0.1
	_add(_head, nose, skin_mat, Vector3(0, -0.03, 0.225), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	# mulut cemberut lebar (ujung bibir turun)
	_mouth_mat = _mat(LIPS)
	_mouth = _add(_head, _box(0.13, 0.014, 0.014), _mouth_mat, Vector3(0, -0.105, 0.205))
	var corner := _box(0.05, 0.012, 0.012)
	_add(_mouth, corner, _mouth_mat, Vector3(-0.075, -0.014, 0), Vector3.ONE, Vector3(0, 0, 0.75))
	_add(_mouth, corner, _mouth_mat, Vector3(0.075, -0.014, 0), Vector3.ONE, Vector3(0, 0, -0.75))

	# tangan panjang sampai lutut, tangan kanan memegang penggaris "REMEDIAL"
	_arm_r = _make_arm(0.24, coat_mat, skin_mat)
	_arm_l = _make_arm(-0.24, coat_mat, skin_mat)
	_arm_r.rotation.x = 0.12
	var ruler := _add(_arm_r, _box(0.07, 1.25, 0.014), _mat(WOOD), Vector3(0, -0.72, 0.05), Vector3.ONE, Vector3(0, 0, 0.7))
	var label := Label3D.new()
	label.text = "REMEDIAL"
	label.font_size = 28
	label.pixel_size = 0.0034
	label.modulate = Color(0.12, 0.08, 0.04)
	label.rotation_degrees = Vector3(0, 0, 90)
	label.position = Vector3(0, 0.05, 0.009)
	ruler.add_child(label)


func _make_leg(x: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.82, 0)
	add_child(pivot)
	_add(pivot, _capsule(0.072, 0.84), mat, Vector3(0, -0.42, 0))
	_add(pivot, _box(0.13, 0.07, 0.26), _mat(Color(0.03, 0.03, 0.02)), Vector3(0, -0.82, 0.05))
	return pivot


func _make_arm(x: float, coat_mat: Material, skin_mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 1.52, 0)
	_body.add_child(pivot)
	_add(pivot, _capsule(0.045, 0.85), coat_mat, Vector3(0, -0.42, 0))
	_add(pivot, _capsule(0.035, 0.24), skin_mat, Vector3(0, -0.92, 0))   # tangan pucat panjang
	return pivot
