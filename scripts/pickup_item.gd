extends Area3D
## Benda yang bisa diambil: item slot (baking_soda, chocolate, koin, gembok) atau buku (notebook).
## Biasanya dibuat otomatis oleh item_spawner.gd. Kotak tabrakan dibuat otomatis dari ukuran model.
##
## Cara ambil: hadap bendanya lalu tekan tombol interaksi.

@export var item_id := "chocolate"
@export var auto_pickup := false  ## true = langsung terambil saat player menyentuh (tanpa tombol)
@export var bob_height := 0.0     ## > 0 = barang naik-turun pelan (kesan melayang), satuan meter
@export var spin_speed := 0.0     ## radian per detik, 0 = tidak berputar

var _visual: Node3D
var _visual_base_y := 0.0
var _time := randf() * TAU


func _ready() -> void:
	add_to_group("pickup")
	if not _has_collision_shape():
		_build_collision()
	if auto_pickup:
		body_entered.connect(_on_body_entered)
	# Model = anak Node3D pertama (bukan kotak tabrakan). Hanya model yang bergerak, tabrakannya diam.
	for child in get_children():
		if child is Node3D and not (child is CollisionShape3D):
			_visual = child as Node3D
			_visual_base_y = _visual.position.y
			break
	set_process(_visual != null and (bob_height > 0.0 or spin_speed != 0.0))


func _process(delta: float) -> void:
	_time += delta
	if bob_height > 0.0:
		_visual.position.y = _visual_base_y + sin(_time * 2.0) * bob_height
	if spin_speed != 0.0:
		_visual.rotate_y(spin_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		interact()


## Dipanggil oleh PlayerActions saat bendanya dihadapi dan tombol interaksi ditekan.
func interact() -> void:
	if item_id == "notebook":
		var tracker := get_tree().get_first_node_in_group("notebook_tracker")
		if tracker == null:
			push_warning("Pickup: node NotebookTracker belum ada di scene lantai 1.")
			return
		tracker.call("request_collect", self)
		return
	# Kalau inventory penuh, item tetap di tempatnya dan HUD menampilkan "Inventory penuh".
	if GameState.add_item(item_id):
		queue_free()


func _has_collision_shape() -> bool:
	for child in get_children():
		if child is CollisionShape3D:
			return true
	return false


func _build_collision() -> void:
	var box := _models_aabb()
	if box.size.length() <= 0.0:
		return
	var size := box.size * 1.4
	size = Vector3(maxf(size.x, 0.4), maxf(size.y, 0.4), maxf(size.z, 0.4))
	var shape := CollisionShape3D.new()
	var shape_box := BoxShape3D.new()
	shape_box.size = size
	shape.shape = shape_box
	shape.position = box.get_center()
	add_child(shape)


# Kotak pembatas gabungan semua mesh milik model (anak langsung dari node ini).
func _models_aabb() -> AABB:
	var stack: Array = []
	for child in get_children():
		if child is Node3D and not (child is CollisionShape3D):
			stack.append([child, Transform3D.IDENTITY])
	var merged := AABB()
	var has_any := false
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xf: Transform3D = entry[1]
		if node is Node3D:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				var part: AABB = xf * mesh_instance.mesh.get_aabb()
				if has_any:
					merged = merged.merge(part)
				else:
					merged = part
					has_any = true
		for sub in node.get_children():
			stack.append([sub, xf])
	return merged
