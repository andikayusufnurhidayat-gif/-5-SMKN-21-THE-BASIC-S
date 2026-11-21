extends Node
## Efek item khusus. Dibuat otomatis oleh GameState (jadi anak node GameState), nggak perlu dipasang manual.
## File ini sudah menyertakan patch gerbang (gate_key). Timpa seluruh file item_effects.gd lama dengan ini.
##
## KONTRAK UNTUK JENNIFER: node Jennifer ada di group "teacher". Method OPSIONAL, kalau ada akan dipanggil:
##   distract(posisi: Vector3, detik: float)   <- Peluit: Jennifer tertarik jalan ke posisi itu
##   stun(detik: float)                        <- Penghapus kena: Jennifer berhenti sebentar (batuk kapur)
##   slow(detik: float)                        <- Lem diinjak: Jennifer jalan pelan
##   on_baking_soda(posisi, radius, detik)     <- Baking soda ditabur (info tambahan)
## Baking soda sekarang jadi PENGHALANG FISIK di lantai selama soda_seconds: tabung tabrakan di lapisan fisika 2
## yang cuma ditabrak Jennifer (mask Jennifer = 1 + 2), player tetap bebas lewat.

const THROWN := preload("res://scripts/thrown_item.gd")
const TEACHER_ONLY_LAYER := 2

@export var throw_speed := 11.0         ## kecepatan lemparan (meter/detik)
@export var throw_lift := 2.5           ## dorongan ke atas biar lemparan melengkung
@export var soda_radius := 1.6          ## jari-jari area baking soda
@export var soda_seconds := 12.0        ## lama baking soda menghalangi jalan
@export var hit_radius := 1.8           ## penghapus dianggap kena Jennifer kalau jatuh sedekat ini (dari badannya)
@export var stun_seconds := 3.0
@export var slow_seconds := 5.0
@export var trap_radius := 0.8
@export var trap_seconds := 45.0        ## lama lem bertahan di lantai
@export var whistle_seconds := 10.0     ## lama Jennifer tertarik ke arah peluit
@export var highlight_seconds := 10.0


## Dipanggil GameState. Mengembalikan true kalau item benar-benar terpakai (jadi hilang dari slot).
func use_effect(item_id: String, kind: String, data: Dictionary) -> bool:
	match kind:
		"throw":
			return _throw(item_id, data)
		"whistle":
			return _whistle()
		"trap":
			return _place_trap()
		"highlight":
			return _highlight()
		"key":
			return _use_key()
		"gate_key":
			return _use_gate_key()
	return false


func _notice(text: String) -> void:
	GameState.notice.emit(text)


func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	return get_viewport().find_world_3d().direct_space_state.intersect_ray(query)


func _floor_below(pos: Vector3) -> Vector3:
	var hit := _ray(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 4.0)
	if hit.is_empty():
		return pos
	return hit["position"]


func _flat_mat(color: Color, x_ray := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if x_ray:
		m.no_depth_test = true
		m.render_priority = 10
	return m


# ------------------------------------------------------------------ lempar

func _throw(item_id: String, data: Dictionary) -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var dir := -cam.global_transform.basis.z
	var start := cam.global_position + dir * 0.6 + Vector3.DOWN * 0.15
	var projectile := Node3D.new()
	projectile.set_script(THROWN)
	get_tree().current_scene.add_child(projectile)
	projectile.call("setup", item_id, data, start, dir * throw_speed + Vector3.UP * throw_lift, Callable(self, "_on_landed"))
	return true


func _on_landed(item_id: String, pos: Vector3, normal: Vector3, collider: Object) -> void:
	print("ItemEffects: %s mendarat di %s" % [item_id, pos])
	match item_id:
		"baking_soda":
			_soda_cloud(pos, normal)
		"penghapus":
			_chalk_hit(pos, collider)


func _soda_cloud(pos: Vector3, normal: Vector3) -> void:
	var floor_pos := _floor_below(pos + normal * 0.1)
	var cloud := Area3D.new()
	cloud.name = "SodaCloud"
	cloud.add_to_group("teacher_block")
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = floor_pos

	# Penghalang fisik: tabung setinggi badan di lapisan 2. Cuma Jennifer (mask 1+2) yang menabrak ini.
	var barrier := StaticBody3D.new()
	barrier.name = "SodaBarrier"
	barrier.collision_layer = 1 << (TEACHER_ONLY_LAYER - 1)
	barrier.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = soda_radius
	cyl.height = 3.0
	shape.shape = cyl
	shape.position.y = 1.5
	barrier.add_child(shape)
	cloud.add_child(barrier)

	# Bubuk putih tebal di lantai, jelas kelihatan.
	var pile := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = soda_radius
	disc.bottom_radius = soda_radius
	disc.height = 0.06
	pile.mesh = disc
	pile.material_override = _flat_mat(Color(1, 1, 1, 0.92))
	pile.position.y = 0.04
	cloud.add_child(pile)
	var mound := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = soda_radius * 0.5
	dome.height = soda_radius * 0.5
	mound.mesh = dome
	mound.material_override = _flat_mat(Color(0.97, 0.97, 0.95, 1.0))
	mound.position.y = 0.05
	cloud.add_child(mound)
	cloud.add_child(_puff(Color(1, 1, 1, 0.8), 70))

	var tween := cloud.create_tween()
	tween.tween_interval(soda_seconds)
	tween.tween_callback(cloud.queue_free)

	for t in get_tree().get_nodes_in_group("teacher"):
		if t.has_method("on_baking_soda"):
			t.call("on_baking_soda", floor_pos, soda_radius, soda_seconds)
	_notice("Baking soda ditaburkan! Jennifer nggak bisa lewat %d detik" % int(soda_seconds))


func _chalk_hit(pos: Vector3, collider: Object) -> void:
	var dust := _puff(Color(0.95, 0.95, 0.9, 0.8), 40)
	get_tree().current_scene.add_child(dust)
	dust.global_position = pos
	var tween := dust.create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(dust.queue_free)

	var hit_any := false
	for t in get_tree().get_nodes_in_group("teacher"):
		if not (t is Node3D):
			continue
		# Jarak diukur dari badan Jennifer (bukan telapak kakinya), dia tinggi.
		var center := (t as Node3D).global_position + Vector3.UP * 1.2
		if t == collider or center.distance_to(pos) <= hit_radius:
			hit_any = true
			if t.has_method("stun"):
				t.call("stun", stun_seconds)
	if hit_any:
		_notice("Kena! Jennifer terbatuk-batuk kena debu kapur")


func _puff(color: Color, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.4
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1.5, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.material = _flat_mat(color)
	p.mesh = mesh
	p.position.y = 0.1
	p.emitting = true
	return p


# ------------------------------------------------------------------ peluit

func _whistle() -> bool:
	var cam := _camera()
	var speaker := AudioStreamPlayer.new()
	speaker.stream = _whistle_stream()
	speaker.volume_db = -4.0
	add_child(speaker)
	speaker.play()
	speaker.finished.connect(speaker.queue_free)

	var pos := cam.global_position if cam != null else Vector3.ZERO
	var heard := false
	for t in get_tree().get_nodes_in_group("teacher"):
		if t.has_method("distract"):
			t.call("distract", pos, whistle_seconds)
			heard = true
	_notice("Priiit! Jennifer mendengarnya..." if heard else "Priiit!")
	return true


# Bunyi peluit dibuat dari kode (nada tinggi bergetar), jadi nggak butuh file audio.
func _whistle_stream() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.7)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var freq := 2600.0 + 250.0 * sin(t * TAU * 11.0)
		phase += TAU * freq / rate
		var env := minf(1.0, t / 0.02) * clampf((0.7 - t) / 0.12, 0.0, 1.0)
		var sample := sin(phase) * 0.45 * env
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav


# ------------------------------------------------------------------ lem

func _place_trap() -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var forward := -cam.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var from := cam.global_position + forward * 1.4
	var hit := _ray(from, from + Vector3.DOWN * 5.0)
	if hit.is_empty():
		_notice("Nggak ada lantai di depan buat naruh lem")
		return false
	var floor_pos: Vector3 = hit["position"]

	var trap := Area3D.new()
	trap.name = "GlueTrap"
	trap.add_to_group("teacher_trap")
	get_tree().current_scene.add_child(trap)
	trap.global_position = floor_pos

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = trap_radius
	cyl.height = 0.8
	shape.shape = cyl
	shape.position.y = 0.4
	trap.add_child(shape)

	var puddle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = trap_radius * 0.9
	disc.bottom_radius = trap_radius * 0.9
	disc.height = 0.02
	puddle.mesh = disc
	puddle.material_override = _flat_mat(Color(0.9, 0.95, 0.6, 0.7))
	puddle.position.y = 0.015
	trap.add_child(puddle)

	trap.body_entered.connect(_on_trap_entered.bind(trap))
	var tween := trap.create_tween()
	tween.tween_interval(trap_seconds)
	tween.tween_callback(trap.queue_free)
	_notice("Lem ditaruh di lantai")
	return true


func _on_trap_entered(body: Node3D, trap: Area3D) -> void:
	if not body.is_in_group("teacher"):
		return
	if body.has_method("slow"):
		body.call("slow", slow_seconds)
	_notice("Jennifer kena lem!")
	trap.queue_free()


# ------------------------------------------------------------------ stabilo

func _highlight() -> bool:
	var marked := 0
	for node in get_tree().get_nodes_in_group("pickup"):
		if str(node.get("item_id")) != "notebook":
			continue
		marked += 1
		var old := node.get_node_or_null("HighlightMarker")
		if old != null:
			old.queue_free()
		var marker := MeshInstance3D.new()
		marker.name = "HighlightMarker"
		var beam := CylinderMesh.new()
		beam.top_radius = 0.05
		beam.bottom_radius = 0.05
		beam.height = 3.0
		marker.mesh = beam
		marker.material_override = _flat_mat(Color(1.0, 0.92, 0.15, 0.6), true)
		marker.position.y = 1.5
		node.add_child(marker)
		var tween := marker.create_tween()
		tween.tween_interval(highlight_seconds)
		tween.tween_callback(marker.queue_free)
	if marked == 0:
		_notice("Semua buku sudah ketemu")
		return false
	_notice("Stabilo: %d buku menyala selama %d detik" % [marked, int(highlight_seconds)])
	return true


# ------------------------------------------------------------------ kunci loker

func _use_key() -> bool:
	var cam := _camera()
	for locker in get_tree().get_nodes_in_group("locker"):
		if not locker.has_method("can_use") or not locker.call("can_use", cam):
			continue
		if bool(locker.get("opened")):
			continue
		locker.call("open")
		_notice("Loker terbuka!")
		return true
	_notice("Kunci Loker: hadap loker dari dekat, lalu klik kanan")
	return false


# ------------------------------------------------------------------ kunci gerbang

func _use_gate_key() -> bool:
	var cam := _camera()
	for gate in get_tree().get_nodes_in_group("school_gate"):
		if not gate.has_method("can_use") or not gate.call("can_use", cam):
			continue
		if bool(gate.get("is_open")):
			continue
		if gate.call("try_open"):
			_notice("Gerbang terbuka! Lari!")
			return true
		return false
	_notice("Kunci Gerbang: hadap gerbang dari dekat, lalu klik kanan")
	return false
