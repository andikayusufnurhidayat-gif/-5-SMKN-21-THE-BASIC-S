extends Node3D
## Potongan Kunci Gerbang. Dibuat game_flow.gd di tiap KeyPoint. Ada 3 potongan (kepala, batang, gerigi);
## kalau ketiganya terkumpul, Kunci Gerbang utuh masuk ke inventory.
## Menyala emas dengan percikan supaya kelihatan. Hadap potongannya dari dekat, lalu tekan E.
##
## Syarat ambil (beda tiap potongan):
##   HOLD = tahan E beberapa detik. Berisik: Jennifer dipancing ke tempat ini!
##   COIN = harus punya 1 Koin di inventory (koinnya terpakai).
##   FAR  = cuma bisa diambil kalau Jennifer jauh dari sini.

signal collected

enum Challenge { HOLD, COIN, FAR }

@export var piece_index := 0                 ## 0 = kepala/cincin, 1 = batang, 2 = gerigi
@export var challenge: Challenge = Challenge.HOLD
@export var use_distance := 3.2
@export var look_dot := 0.8
@export var hold_seconds := 4.0
@export var far_distance := 30.0
@export var hover_height := 0.55

var _label: Label3D
var _visual: Node3D
var _hold := 0.0
var _e_prev := false
var _t := 0.0
var _noise_sent := false


func _ready() -> void:
	_build()


func _build() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1, 0.78, 0.15)
	gold.metallic = 0.9
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1, 0.55, 0.05)
	gold.emission_energy_multiplier = 1.2
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.8, 0.05, 0.1)
	red.emission_enabled = true
	red.emission = Color(0.9, 0.05, 0.1)

	_visual = Node3D.new()
	_visual.position.y = hover_height
	add_child(_visual)
	match piece_index:
		0:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.1
			ring.outer_radius = 0.2
			_mesh(ring, gold, Vector3.ZERO, Vector3(PI / 2.0, 0, 0))
			var gem := SphereMesh.new()
			gem.radius = 0.05
			gem.height = 0.1
			_mesh(gem, red, Vector3(0, 0.25, 0))
		1:
			var shaft := CylinderMesh.new()
			shaft.top_radius = 0.04
			shaft.bottom_radius = 0.04
			shaft.height = 0.6
			_mesh(shaft, gold, Vector3.ZERO)
			var collar := CylinderMesh.new()
			collar.top_radius = 0.07
			collar.bottom_radius = 0.07
			collar.height = 0.05
			_mesh(collar, gold, Vector3(0, 0.15, 0))
			var ribbon := BoxMesh.new()
			ribbon.size = Vector3(0.1, 0.22, 0.012)
			_mesh(ribbon, red, Vector3(0, 0.04, 0.06))
		_:
			for i in 3:
				var tooth := BoxMesh.new()
				tooth.size = Vector3(0.18 - i * 0.03, 0.06, 0.05)
				_mesh(tooth, gold, Vector3(0.05, -0.15 + i * 0.15, 0))
			var base := BoxMesh.new()
			base.size = Vector3(0.06, 0.5, 0.05)
			_mesh(base, gold, Vector3.ZERO)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.3)
	light.light_energy = 1.6
	light.omni_range = 5.0
	_visual.add_child(light)

	var sparks := CPUParticles3D.new()
	sparks.amount = 16
	sparks.lifetime = 1.8
	sparks.direction = Vector3.UP
	sparks.spread = 45.0
	sparks.initial_velocity_min = 0.2
	sparks.initial_velocity_max = 0.6
	sparks.gravity = Vector3(0, 0.1, 0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.35
	var dot := SphereMesh.new()
	dot.radius = 0.025
	dot.height = 0.05
	var dot_mat := StandardMaterial3D.new()
	dot_mat.albedo_color = Color(1, 0.85, 0.3)
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = dot_mat
	sparks.mesh = dot
	sparks.emitting = true
	_visual.add_child(sparks)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.pixel_size = 0.006
	_label.outline_size = 10
	_label.modulate = Color(1, 0.92, 0.5)
	_label.position = Vector3(0, hover_height + 0.7, 0)
	_label.visible = false
	add_child(_label)


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	_visual.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_visual.rotation.y += delta * 1.4
	_visual.position.y = hover_height + sin(_t * 2.0) * 0.06

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var center := global_position + Vector3(0, hover_height, 0)
	var to_piece := center - cam.global_position
	var dist := to_piece.length()
	var looking := dist < use_distance and dist > 0.01 and (-cam.global_transform.basis.z).dot(to_piece / dist) > look_dot
	var e_now := Input.is_physical_key_pressed(KEY_E)
	var e_pressed := e_now and not _e_prev
	_e_prev = e_now

	if not looking:
		_label.visible = false
		_hold = 0.0
		_noise_sent = false
		return
	_label.visible = true

	match challenge:
		Challenge.HOLD:
			if e_now:
				if not _noise_sent:
					_noise_sent = true
					for t in get_tree().get_nodes_in_group("teacher"):
						if t.has_method("distract"):
							t.call("distract", global_position, hold_seconds + 8.0)
					GameState.notice.emit("Noisy! Jennifer can hear this from here...")
				_hold += delta
				if _hold >= hold_seconds:
					_done()
					return
			else:
				_hold = 0.0
				_noise_sent = false
			var filled := int(_hold / hold_seconds * 8.0)
			_label.text = "Hold [E] to pull out the key piece\n" + "[" + "#".repeat(filled) + "-".repeat(8 - filled) + "]"
		Challenge.COIN:
			var has_coin := GameState.slots.has("koin")
			_label.text = "Press [E]: insert 1 Coin" if has_coin else "Needs 1 Coin (find one in the hallway)"
			if e_pressed and has_coin:
				var idx := GameState.slots.find("koin")
				GameState.slots[idx] = ""
				GameState.inventory_changed.emit()
				GameState.notice.emit("Coin inserted, a key piece came out!")
				_done()
		Challenge.FAR:
			var near := false
			for t in get_tree().get_nodes_in_group("teacher"):
				if (t as Node3D).global_position.distance_to(global_position) < far_distance:
					near = true
			_label.text = "Ms. Jennifer is too close! Wait for her to leave" if near else "Press [E] to take it (quick!)"
			if e_pressed and not near:
				_done()


func _done() -> void:
	collected.emit()
	queue_free()
