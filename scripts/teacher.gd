@tool
extends CharacterBody3D
## Ms. Jennifer. Node CharacterBody3D bernama "Jennifer" + script ini. Semua anak node dibuat lewat kode.
##
## Tiga kondisi:
##  PATROLI : tenang, jalan pelan keliling area sekitar player (kecepatan patrol_speed). Dari awal sampai ada jawaban salah.
##  MARAH   : tiap jawaban salah = marah dan ngejar player selama hunt_seconds (menumpuk). Kecepatan = base_speed
##            + nomor buku * speed_per_book + bonus marah. Marah reda sendiri, lalu balik patroli.
##  NGAMUK  : setelah buku terakhir. Ngejar terus, lebih cepat dari lari player.
## Player sembunyi (hiding_spot.gd): kalau dia lihat player masuk, dia langsung buka paksa tempatnya.
## Kalau nggak lihat, dia memeriksa 2-3 tempat sembunyi terdekat dari posisi terakhir player, lalu menyerah.
## Suara ketukan penggaris: makin cepat dan makin keras seiring kecepatannya (3D, makin dekat makin kencang).
## Navmesh dibake otomatis dari collision peta saat game mulai (kalau scene belum punya NavigationRegion3D).

signal caught_player

@export var use_3d_model := true            ## false = pakai gambar 2D (sprite billboard)
@export var model_scene: PackedScene        ## (opsional) model 3D buatan sendiri (.glb/.tscn), menggantikan model bawaan
@export var glb_path := "res://characters/jennifer.glb"   ## model Ms. Jennifer 3D bersekeleton + animasi (otomatis dipakai kalau ada)
@export var face_angry_path := "res://characters/face_angry.png"   ## tekstur wajah marah (wajah tenang sudah ada di dalam GLB)
@export var voice_db := -2.0              ## volume suara Jennifer (res://audio/voice/jennifer_<id>.wav/.ogg)
@export var model_scale := 1.3            ## pembesar model GLB (tinggi asli 1,8 m, jadi sekitar 2,3 m)
@export var texture_path := "res://characters/jennifer.png"
@export var texture: Texture2D
@export var texture_wave: Texture2D
@export var sprite_height := 2.2

@export_group("Gerak")
@export var patrol_speed := 2.6        ## kecepatan patroli tenang
@export var base_speed := 4.0          ## kecepatan ngejar. player: jalan 10, lari 15
@export var speed_per_book := 1.3      ## tambahan kecepatan tiap buku (buku 1 = 5.3, buku 7 = 13.1)
@export var anger_speed := 1.5         ## tambahan kecepatan per jawaban salah (sementara)
@export var anger_decay := 0.08        ## bonus kecepatan marah mereda per detik
@export var rage_multiplier := 1.3
@export var hunt_seconds := 40.0       ## lama ngejar per jawaban salah (menumpuk, maks 90)
@export var retarget_base := 3.0
@export var retarget_min := 0.6
@export var catch_distance := 1.3
@export var player_sprint_margin := 1.0   ## kecepatan lari player selalu minimal kecepatan Jennifer + ini
@export var patrol_min_dist := 10.0
@export var patrol_max_dist := 28.0
@export var bake_navmesh := true

@export_group("Ketukan penggaris")
@export var tap_enabled := true
@export var tap_volume_min_db := -12.0
@export var tap_volume_max_db := 4.0

static var _tap_cache: AudioStreamWAV

var _model: Node3D
var _anim: AnimationPlayer
var _sprite: Sprite3D
var _speech: Label3D
var _agent: NavigationAgent3D
var _tap: AudioStreamPlayer3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _hunt_left := 0.0
var _rage := false
var _caught := false
var _opening := false
var _books := 0
var _anger := 0.0
var _stun_left := 0.0
var _slow_left := 0.0
var _distract_left := 0.0
var _distract_pos := Vector3.ZERO
var _target := Vector3.ZERO
var _retarget_left := 0.0
var _nav_ok := false
var _nav_check := 0.0
var _speech_id := 0
var _mood_cur := "calm"
var _last_pos := Vector3.ZERO
var _stuck := 0.0
var _avoid_left := 0.0
var _avoid_dir := Vector3.ZERO
var _tap_t := 0.0
var _meshes: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _base_cols: Array[Color] = []
var _face_mat: StandardMaterial3D
var _tex_calm: Texture2D
var _tex_angry: Texture2D
var _anim_name := ""
var _greet_left := 0.0
var _look_left := 0.0
var _voice: AudioStreamPlayer3D
var _voice_cache := {}
var _tex_blink: Texture2D
var _tex_talk: Texture2D
var _blink_t := 3.0
var _search_travel := 0.0
var _search_direct := 0.0
var _checking_desk := false
var _player_base_sprint := -1.0
var _face_pos := Vector3.INF
var _patrol_target := Vector3.ZERO
var _patrol_wait := 0.0
# sembunyi / pencarian
var _player_hidden := false
var _hiding_spot: Node3D
var _searching := false
var _search_spots: Array[Node3D] = []
var _search_i := 0
var _search_wait := 0.0


func _ready() -> void:
	add_to_group("teacher")
	collision_mask = 3   # lapisan 1 (peta) + lapisan 2 (penghalang baking soda, cuma Jennifer yang menabrak)
	_build()
	_target = global_position
	_last_pos = global_position
	_patrol_target = global_position
	if not Engine.is_editor_hint() and bake_navmesh:
		_bake_navigation()


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	shape.shape = cap
	shape.position.y = 1.0
	add_child(shape)

	if use_3d_model:
		if model_scene == null and ResourceLoader.exists(glb_path):
			model_scene = load(glb_path) as PackedScene
		if model_scene != null:
			_model = model_scene.instantiate() as Node3D
			_model.scale = Vector3.ONE * model_scale
			_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			_setup_glb()
		else:
			_model = (load("res://scripts/jennifer_model.gd") as GDScript).new() as Node3D
		add_child(_model)
	else:
		_build_sprite()

	_speech = Label3D.new()
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.no_depth_test = true
	_speech.font_size = 48
	_speech.pixel_size = 0.008
	_speech.outline_size = 12
	_speech.position.y = (1.95 * model_scale + 0.4) if (_model != null and _anim != null) else (sprite_height + (1.0 if use_3d_model else 0.5))
	_speech.visible = false
	add_child(_speech)

	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.8
	_agent.target_desired_distance = 0.9
	add_child(_agent)

	if not Engine.is_editor_hint():
		_tap = AudioStreamPlayer3D.new()
		_tap.stream = _make_tap()
		_tap.unit_size = 10.0
		_tap.max_distance = 80.0
		_tap.max_db = 6.0
		_tap.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_tap.position.y = 1.0
		add_child(_tap)
		_voice = AudioStreamPlayer3D.new()
		_voice.unit_size = 12.0
		_voice.max_distance = 70.0
		_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_voice.position.y = 2.0
		add_child(_voice)


func _build_sprite() -> void:
	var tex := texture
	if tex == null and ResourceLoader.exists(texture_path):
		tex = load(texture_path) as Texture2D
	if tex == null:
		var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.18, 0.35, 0.2))
		tex = ImageTexture.create_from_image(img)
	_sprite = Sprite3D.new()
	_sprite.texture = tex
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	_sprite.pixel_size = sprite_height / float(tex.get_height())
	_sprite.position.y = sprite_height * 0.5
	add_child(_sprite)


# Bunyi "tok" penggaris kayu, dibuat dari kode (nggak butuh file audio).
static func _make_tap() -> AudioStreamWAV:
	if _tap_cache != null:
		return _tap_cache
	var rate := 22050
	var count := int(rate * 0.16)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in count:
		var t := float(i) / rate
		var body := sin(TAU * 170.0 * t) * exp(-t * 34.0)
		var knock := sin(TAU * 480.0 * t) * exp(-t * 70.0) * 0.6
		var click := rng.randf_range(-1.0, 1.0) * exp(-t * 220.0)
		var s := clampf((body * 0.8 + knock + click * 0.8) * 0.9, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	_tap_cache = wav
	return wav


# Bake navmesh dari collision statis peta (sekali, di awal game) kalau scene belum punya navmesh sendiri.
func _bake_navigation() -> void:
	for i in 4:
		await get_tree().physics_frame
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(map).size() > 0:
		return
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nm.cell_size = 0.3
	nm.cell_height = 0.2
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.4
	nm.agent_max_slope = 40.0
	var src := NavigationMeshSourceGeometryData3D.new()
	var scene := get_tree().current_scene
	NavigationServer3D.parse_source_geometry_data(nm, src, scene)
	var region := NavigationRegion3D.new()
	region.name = "JenniferNavRegion"
	scene.add_child(region)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, func():
		region.navigation_mesh = nm
		print("Jennifer: navmesh selesai dibake."))


# ------------------------------------------------------------------ gerak

func _is_hunting() -> bool:
	return _rage or _hunt_left > 0.0


## Kecepatan Jennifer saat ini (ngejar atau patroli).
func current_speed() -> float:
	if _is_hunting():
		return _hunt_speed()
	return patrol_speed + _books * 0.25


func _hunt_speed() -> float:
	var s := base_speed + _books * speed_per_book + _anger * anger_speed
	if _rage:
		s *= rage_multiplier
	return s


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _caught:
		return
	if _opening:
		velocity.x = 0.0
		velocity.z = 0.0
		_update_anim(0.0)
		return
	_face_pos = Vector3.INF
	_tick(delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	var dir := Vector3.ZERO
	var spd := 0.0
	if _stun_left <= 0.0:
		if _distract_left > 0.0:
			dir = _dir_to(_distract_pos)
			spd = _hunt_speed() * 0.8
		elif _searching:
			dir = _search_dir(delta)
			spd = _hunt_speed() * 0.7
		elif _is_hunting():
			dir = _dir_to(_target)
			spd = _hunt_speed()
		elif _look_left > 0.0:
			dir = Vector3.ZERO
		else:
			dir = _patrol_dir(delta)
			spd = patrol_speed + _books * 0.25
	if _slow_left > 0.0:
		spd *= 0.35

	# anti-nyangkut: menyamping sebentar kalau jalan di tempat
	if dir != Vector3.ZERO:
		if _avoid_left > 0.0:
			_avoid_left -= delta
			dir = (dir * 0.35 + _avoid_dir).normalized()
		var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
		if moved < spd * delta * 0.25:
			_stuck += delta
			if _stuck > 0.5:
				_stuck = 0.0
				_avoid_left = 0.9
				var side := 1.0 if randf() < 0.5 else -1.0
				_avoid_dir = dir.cross(Vector3.UP).normalized() * side
		else:
			_stuck = 0.0
	else:
		_stuck = 0.0
	_last_pos = global_position

	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_update_visual(delta, dir, hspeed)
	_update_tap(delta, hspeed)
	if _is_hunting() and not _player_hidden:
		_check_catch()   # saat patroli tenang dia nggak menangkap, bersentuhan saja nggak apa-apa


func _tick(delta: float) -> void:
	_stun_left = maxf(_stun_left - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	_distract_left = maxf(_distract_left - delta, 0.0)
	_greet_left = maxf(_greet_left - delta, 0.0)
	_look_left = maxf(_look_left - delta, 0.0)
	if _anger > 0.0:
		_anger = maxf(_anger - anger_decay * delta, 0.0)
	# kecepatan lari player dijaga minimal kecepatan Jennifer + margin (player selalu bisa lebih cepat saat lari)
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and "sprint_speed" in pl:
		if _player_base_sprint < 0.0:
			_player_base_sprint = float(pl.get("sprint_speed"))
		pl.set("sprint_speed", maxf(_player_base_sprint, current_speed() + player_sprint_margin))
	if not _rage and _hunt_left > 0.0:
		_hunt_left = maxf(_hunt_left - delta, 0.0)
		if _hunt_left <= 0.0:
			say("Hmph...", 2.0, "calm_down")
	var want := "shout" if _rage else ("angry" if _hunt_left > 0.0 else "calm")
	if want != _mood_cur:
		_mood_cur = want
		_set_mood(want)
	_nav_check -= delta
	if _nav_check <= 0.0:
		_nav_check = 1.0
		_nav_ok = NavigationServer3D.map_get_regions(_agent.get_navigation_map()).size() > 0
	if _is_hunting() and _stun_left <= 0.0 and not _player_hidden and not _searching:
		_retarget_left -= delta
		if _retarget_left <= 0.0:
			var p := get_tree().get_first_node_in_group("player") as Node3D
			if p != null:
				_target = p.global_position
			_retarget_left = _interval()


func _interval() -> float:
	if _rage:
		return retarget_min
	return clampf(retarget_base - _books * 0.4 - _anger * 0.15, retarget_min, retarget_base)


func _dir_to(pos: Vector3) -> Vector3:
	var flat := pos - global_position
	flat.y = 0.0
	if flat.length() < 0.7:
		return Vector3.ZERO
	var goal := pos
	if _nav_ok:
		_agent.target_position = pos
		goal = _agent.get_next_path_position()
	var d := goal - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO


# Patroli tenang: jalan ke titik acak di navmesh, di sekitar (tapi nggak menempel ke) player.
func _patrol_dir(delta: float) -> Vector3:
	if not _nav_ok:
		return Vector3.ZERO
	_patrol_wait -= delta
	var flat := _patrol_target - global_position
	flat.y = 0.0
	if flat.length() < 1.2 or _patrol_wait <= 0.0:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		var center := p.global_position if p != null else global_position
		var ang := randf() * TAU
		var dist := randf_range(patrol_min_dist, patrol_max_dist)
		var want := center + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		_patrol_target = NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), want)
		_patrol_wait = randf_range(6.0, 12.0)
	return _dir_to(_patrol_target)


func _check_catch() -> void:
	if _stun_left > 0.0:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := p.global_position - global_position
	if absf(d.y) < 2.5 and Vector2(d.x, d.z).length() <= catch_distance:
		_catch_player()


func _catch_player() -> void:
	if _caught:
		return
	_caught = true
	velocity = Vector3.ZERO
	_set_mood("shout")
	caught_player.emit()
	get_tree().call_group("game_flow", "on_caught")


# ------------------------------------------------------------------ sembunyi dan pencarian

## Dipanggil hiding_spot.gd saat player masuk tempat sembunyi. seen = true kalau Jennifer melihat player masuk.
func player_hid(spot: Node3D, seen: bool) -> void:
	_player_hidden = true
	_hiding_spot = spot
	if not seen and not _is_hunting():
		return   # dia nggak sadar ada player, nggak ada yang dicari
	_search_spots.clear()
	if seen:
		_search_spots.append(spot)
		say("Aku lihat kamu masuk situ...", 3.0, "saw_you")
	else:
		var all := get_tree().get_nodes_in_group("hide_spot")
		all.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(_target) < (b as Node3D).global_position.distance_to(_target))
		var near: Array = []
		for s in all:
			if (s as Node3D).global_position.distance_to(_target) <= 10.0:
				near.append(s)
		if near.is_empty():
			near = all.slice(0, 3)
		var n := mini(near.size(), randi_range(4, 6))
		for i in n:
			_search_spots.append(near[i] as Node3D)
		say("Kemana dia...?", 2.5, "where")
	_search_i = 0
	_reset_search_step()
	_searching = true
	_hunt_left = maxf(_hunt_left, 15.0)


## Dipanggil hiding_spot.gd saat player keluar dari tempat sembunyi.
func player_left_hiding() -> void:
	# Hanya marah kalau dia memang lagi mencari (ketahuan / lagi ngejar). Kalau dia nggak sadar kamu sembunyi, keluar ya aman.
	var was_alerted := _searching or _is_hunting()
	_player_hidden = false
	_hiding_spot = null
	_searching = false
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if was_alerted and p != null and p.global_position.distance_to(global_position) < 14.0:
		_hunt_left = maxf(_hunt_left, 20.0)
		_retarget_left = 0.0


## Arah hadap Jennifer (datar). Dipakai hiding_spot.gd buat cek dia bisa lihat player masuk atau nggak.
func facing_dir() -> Vector3:
	if _model != null:
		var f := _model.global_transform.basis * Vector3(0, 0, 1)
		f.y = 0.0
		if f.length() > 0.01:
			return f.normalized()
	var v := Vector3(velocity.x, 0.0, velocity.z)
	return v.normalized() if v.length() > 0.1 else Vector3.ZERO


func _reset_search_step() -> void:
	_search_travel = 0.0
	_search_direct = 0.0
	_search_wait = 0.0


func _search_dir(delta: float) -> Vector3:
	if _search_i >= _search_spots.size():
		if _rage and _player_hidden:
			# ngamuk: terus mencari ke tempat sembunyi terdekat sampai ketemu
			var all := get_tree().get_nodes_in_group("hide_spot")
			all.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(global_position) < (b as Node3D).global_position.distance_to(global_position))
			_search_spots.clear()
			for s in all.slice(0, 8):
				_search_spots.append(s as Node3D)
			_search_i = 0
			_reset_search_step()
		else:
			_searching = false
			_hunt_left = 0.0 if not _rage else _hunt_left
			_look_left = 3.0   # celingak-celinguk sebentar, lalu pergi patroli
			say("Hm... dimana dia?", 2.5, "gave_up")
		return Vector3.ZERO
	var spot := _search_spots[_search_i]
	if not is_instance_valid(spot):
		_search_i += 1
		_reset_search_step()
		return Vector3.ZERO
	var front: Vector3 = spot.call("front_point")
	var flat := front - global_position
	flat.y = 0.0
	_search_travel += delta
	var arrived := flat.length() <= 1.4
	if not arrived:
		var d := _dir_to(front)
		if _search_travel > 0.5 and (d == Vector3.ZERO or _agent.is_navigation_finished()):
			# jalur navmesh mentok (titik depan ketutup kursi/meja lain): dekati lurus beberapa detik, lalu periksa dari situ
			if flat.length() < 6.0 and _search_direct < 3.0:
				_search_direct += delta
				d = flat.normalized()
			else:
				arrived = true
		if not arrived and _search_travel > 14.0:
			arrived = true
		if not arrived:
			return d
	_face_pos = spot.global_position
	_checking_desk = int(spot.get("kind")) == 1
	_search_wait += delta
	if _search_wait >= 1.8:
		_reset_search_step()
		if spot == _hiding_spot and _player_hidden:
			_opening = true
			spot.call("force_open")
			get_tree().create_timer(0.5).timeout.connect(_catch_player)
		else:
			spot.call("empty_check")
			_search_i += 1
	return Vector3.ZERO


# ------------------------------------------------------------------ tampilan dan suara

func _update_visual(delta: float, dir: Vector3, hspeed: float) -> void:
	if _model == null:
		return
	# menghadap arah jalan; kalau diam, menghadap tempat yang diperiksa atau player
	var face := dir
	if _face_pos != Vector3.INF:
		face = _face_pos - global_position
		face.y = 0.0
	elif face.length() < 0.1:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null:
			face = p.global_position - global_position
			face.y = 0.0
	if face.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(face.x, face.z), clampf(delta * 8.0, 0.0, 1.0))
	if _model.has_method("set_motion"):
		_model.call("set_motion", hspeed / 8.0, _is_hunting())
	elif _anim != null:
		_update_anim(hspeed)


# Ketukan penggaris: makin cepat jalannya, makin rapat dan makin keras ketukannya.
func _update_tap(delta: float, hspeed: float) -> void:
	if not tap_enabled or _tap == null or hspeed < 0.5:
		return
	_tap_t -= delta
	if _tap_t > 0.0:
		return
	_tap_t = clampf(3.4 / maxf(hspeed, 1.0), 0.16, 1.2)
	_tap.volume_db = lerpf(tap_volume_min_db, tap_volume_max_db, clampf(hspeed / 16.0, 0.0, 1.0))
	_tap.pitch_scale = randf_range(0.93, 1.07) + hspeed * 0.01
	_tap.play()


func _set_mood(mood: String) -> void:
	if _model != null and _model.has_method("set_mood"):
		_model.call("set_mood", mood)
	_apply_tint(mood)


# ---- model GLB bersekeleton ----

func _setup_glb() -> void:
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		_meshes.append(mi)
		for i in mi.get_surface_override_material_count():
			var base := mi.get_active_material(i)
			if base is StandardMaterial3D:
				var dup := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				mi.set_surface_override_material(i, dup)
				_mats.append(dup)
				_base_cols.append(dup.albedo_color)
				if mi.name == "Face":
					_face_mat = dup
					_tex_calm = dup.albedo_texture
	if ResourceLoader.exists(face_angry_path):
		_tex_angry = load(face_angry_path) as Texture2D
	var dir := face_angry_path.get_base_dir()
	if ResourceLoader.exists(dir + "/face_blink.png"):
		_tex_blink = load(dir + "/face_blink.png") as Texture2D
	if ResourceLoader.exists(dir + "/face_talk.png"):
		_tex_talk = load(dir + "/face_talk.png") as Texture2D
	_apply_tint("calm")
	if _anim != null:
		for n in ["idle", "walk", "run", "scream", "stun", "angry_idle", "look_around"]:
			if _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		if _anim.has_animation("idle"):
			_anim.play("idle")


# Marah/ngamuk: wajah diganti wajah seram dan badan menggelap kemerahan.
func _apply_tint(mood: String) -> void:
	if _mats.is_empty():
		return
	var tint := Color(1, 1, 1)
	match mood:
		"angry":
			tint = Color(1.0, 0.78, 0.74)
		"shout":
			tint = Color(1.0, 0.55, 0.52)
	for i in _mats.size():
		_mats[i].albedo_color = _base_cols[i] * tint
	if _face_mat != null:
		_face_mat.albedo_texture = _tex_angry if (mood != "calm" and _tex_angry != null) else _tex_calm


# Pilih animasi dari kondisi: jumpscare > batuk > memeriksa tempat sembunyi > melambai > lari/jalan > diam.
func _update_anim(hspeed: float) -> void:
	if _anim == null:
		return
	var want := "idle"
	var spd := 1.0
	if _caught:
		want = "scream"
	elif _stun_left > 0.0:
		want = "stun"
	elif _opening or _face_pos != Vector3.INF:
		want = "peek" if _checking_desk else "search_door"
	elif _look_left > 0.0 and hspeed < 0.6:
		want = "look_around"
	elif _greet_left > 0.0:
		want = "wave"
	elif hspeed > 0.6:
		if _is_hunting():
			want = "run"
			spd = clampf(hspeed / 9.0, 0.8, 1.7)
		else:
			want = "walk"
			spd = clampf(hspeed / 2.6, 0.7, 1.5)
	elif _is_hunting():
		want = "angry_idle"
	if not _anim.has_animation(want):
		want = "search_door" if (want == "peek" and _anim.has_animation("search_door")) else "idle"
	if want != _anim_name:
		_anim_name = want
		_anim.play(want, 0.25)
	_anim.speed_scale = spd


## Posisi kepala (dunia), dipakai kamera jumpscare.
func is_hunting() -> bool:
	return _is_hunting()


func is_rage() -> bool:
	return _rage


## Putar suara Jennifer res://audio/voice/jennifer_<id>.(ogg|wav|mp3). Kalau filenya nggak ada, diam saja.
func speak(voice_id: String) -> void:
	if _voice == null:
		return
	var st := _voice_stream(voice_id)
	if st == null:
		return
	_voice.stream = st
	_voice.volume_db = voice_db
	_voice.play()


func _voice_stream(id: String) -> AudioStream:
	if _voice_cache.has(id):
		return _voice_cache[id]
	var found: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var p := "res://audio/voice/jennifer_%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			found = load(p) as AudioStream
			break
	_voice_cache[id] = found
	return found


# Wajah hidup: berkedip saat tenang, mulut terbuka-tutup saat bicara, wajah seram saat marah.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _face_mat == null:
		return
	var tex: Texture2D = _tex_calm
	if _mood_cur != "calm":
		tex = _tex_angry if _tex_angry != null else _tex_calm
	else:
		_blink_t -= delta
		if _blink_t < -0.14:
			_blink_t = randf_range(2.5, 6.0)
		if _blink_t < 0.0 and _tex_blink != null:
			tex = _tex_blink
		elif _voice != null and _voice.playing and _tex_talk != null and (Time.get_ticks_msec() / 120) % 2 == 0:
			tex = _tex_talk
	if _face_mat.albedo_texture != tex:
		_face_mat.albedo_texture = tex


func head_position() -> Vector3:
	if _anim != null:
		return global_position + Vector3.UP * 1.68 * model_scale
	return global_position + Vector3.UP * (2.2 if use_3d_model else sprite_height * 0.9)


## Pose menerkam saat menangkap player; menghadap arah face_dir.
func jumpscare_pose(face_dir: Vector3) -> void:
	_caught = true
	velocity = Vector3.ZERO
	if _model != null:
		_model.rotation.y = atan2(face_dir.x, face_dir.z)
		if _model.has_method("jumpscare"):
			_model.call("jumpscare")
		elif _anim != null and _anim.has_animation("scream"):
			_anim_name = "scream"
			_anim.speed_scale = 1.0
			_anim.play("scream", 0.05)
		_apply_tint("shout")


# ------------------------------------------------------------------ dipanggil game_flow / quiz

func start_chase() -> void:
	_hunt_left = maxf(_hunt_left, hunt_seconds)
	_retarget_left = 0.0


func on_notebook_collected(count: int) -> void:
	_books = count


## Tiap jawaban salah: marah dan ngejar selama hunt_seconds (menumpuk), plus bonus kecepatan sementara.
func add_anger(amount: float) -> void:
	if amount <= 0.0:
		return
	_anger += amount
	_hunt_left = minf(_hunt_left + hunt_seconds * amount, 90.0)
	_retarget_left = 0.0
	say("Jawabanmu SALAH!", 2.5, "wrong")


func enter_rage() -> void:
	_rage = true
	_hunt_left = 9999.0
	_retarget_left = 0.0
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.55, 0.55)
	say("KAMU TIDAK AKAN KABUR!", 4.0, "rage")


# ------------------------------------------------------------------ kontrak item_effects.gd

func distract(pos: Vector3, seconds: float) -> void:
	_distract_pos = pos
	_distract_left = seconds


func stun(seconds: float) -> void:
	_stun_left = maxf(_stun_left, seconds)
	say("Uhuk! Uhuk!", seconds, "cough")


func slow(seconds: float) -> void:
	_slow_left = maxf(_slow_left, seconds)
	say("Kakiku lengket!", seconds, "glue")


func on_baking_soda(_pos: Vector3, _radius: float, _seconds: float) -> void:
	pass   # penghalangnya fisik (lapisan tabrakan 2), nggak perlu logika khusus di sini


# ------------------------------------------------------------------ sambutan

func say(text: String, seconds := 3.0, voice_id := "") -> void:
	if voice_id != "":
		speak(voice_id)
	_speech_id += 1
	var my_id := _speech_id
	_speech.text = text
	_speech.visible = true
	await get_tree().create_timer(seconds).timeout
	if my_id == _speech_id:
		_speech.visible = false


## Lambaian + sapaan. Model 3D: tangan kiri melambai. Sprite 2D: badan bergoyang.
func greet(with_voice := true) -> void:
	say("Halo! Selamat datang di SMKN 21!", 4.0, "greet" if with_voice else "")
	if _model != null:
		if _model.has_method("wave"):
			_model.call("wave", 4.0)
		elif _anim != null and _anim.has_animation("wave"):
			_greet_left = 2.6
			_anim_name = "wave"
			_anim.play("wave", 0.2)
		return
	if _sprite == null:
		return
	var base_tex := _sprite.texture
	var tw := create_tween()
	for i in 5:
		tw.tween_callback(func():
			if texture_wave != null:
				_sprite.texture = texture_wave)
		tw.tween_property(_sprite, "offset:x", 90.0, 0.2)
		tw.parallel().tween_property(_sprite, "position:y", sprite_height * 0.5 + 0.08, 0.2)
		tw.tween_callback(func(): _sprite.texture = base_tex)
		tw.tween_property(_sprite, "offset:x", -90.0, 0.2)
		tw.parallel().tween_property(_sprite, "position:y", sprite_height * 0.5, 0.2)
	tw.tween_property(_sprite, "offset:x", 0.0, 0.15)
