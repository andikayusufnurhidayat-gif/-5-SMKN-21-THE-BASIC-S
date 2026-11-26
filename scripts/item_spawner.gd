extends Node
## Penyebar item acak. Taruh satu node ini di scene lantai 1 (namai ItemSpawner).
##
## Tiap game dimulai, SEMUA item di katalog (GameState.ITEMS) dan buku (GameState.NOTEBOOK)
## disebar ke titik acak yang berbeda-beda. Jumlah tiap item diatur di katalog (spawn_count).
##
## Aturan sebar:
##  - Item biasa + buku: di dalam ruangan (node kelas*, ruang guru, ruang lab, toilet). Titiknya dicari
##    otomatis tiap game dimulai, jadi tempatnya berubah-ubah setiap main.
##  - Di ruangan, buku (dan sebagian item) diutamakan di ATAS MEJA: permukaan meja dicari otomatis lewat
##    sinar fisika (permukaan datar setinggi meja). Kalau ruangan nggak punya meja yang ketemu, dipasang di lantai.
##  - Item di corridor_items (koin): di jalan/koridor, dari titik yang direkam di res://spawn_points.json
##    (direkam lewat spawn_point_recorder.gd). Opsional: Marker3D di bawah node "Spawn Points Root".
##  - Kalau titik ruangan kurang atau nggak ketemu, sisanya dipasang di titik koridor seperti sebelumnya.
## Di lantai/koridor benda melayang pelan; di atas meja benda diletakkan langsung (berdiri tegak).

const PICKUP_SCRIPT := preload("res://scripts/pickup_item.gd")

@export var points_path := "res://spawn_points.json"
@export var spawn_points_root: Node3D
@export var spawn_notebooks := true
@export var spawn_items := true
@export var height_offset := 0.0            ## tambahan tinggi untuk benda di lantai/koridor (meter).
@export var scatter_radius := 0.3           ## geser acak kecil, hanya untuk titik koridor (meter). 0 = tepat di titik.
@export var min_item_spacing := 4.0         ## jarak minimal antar benda di koridor (meter).
@export var min_distance_from_player := 5.0 ## titik yang terlalu dekat posisi awal player dilewati.
@export var random_rotation := true

@export_group("Ruangan")
@export var spawn_in_rooms := true
## Node anak langsung dari scene ini yang namanya diawali salah satu kata ini dianggap ruangan.
@export var room_prefixes: PackedStringArray = ["kelas", "ruang guru", "ruang lab", "toilet"]
## Id item yang hanya muncul di koridor (bukan di ruangan).
@export var corridor_items: PackedStringArray = ["koin"]
@export var room_item_spacing := 2.5    ## jarak minimal antar benda di lantai ruangan (meter).
@export var candidates_per_room := 80   ## berapa kali mencoba titik acak lantai per ruangan.
@export var max_points_per_room := 12   ## titik lantai valid maksimal yang disimpan per ruangan.
@export var clearance := 0.35           ## jarak bebas dari dinding/perabot di sekitar titik lantai (meter).
@export var floor_tolerance := 0.15     ## selisih tinggi lantai yang masih dianggap lantai (meter).

@export_group("Meja")
@export var items_on_tables := true
@export var notebook_table_chance := 1.0   ## peluang buku di atas meja (1.0 = selalu kalau meja ada).
@export var item_table_chance := 0.5       ## peluang item lain (cokelat, baking soda, dll.) di atas meja.
@export var table_min_height := 0.6        ## tinggi permukaan meja dari lantai, batas bawah (meter).
@export var table_max_height := 1.3        ## batas atas (meter).
@export var table_min_size := 0.5          ## permukaan datar minimal selebar ini (meter), biar kursi nggak dikira meja.
@export var table_candidates_per_room := 240
@export var max_table_points_per_room := 10
@export var table_item_spacing := 0.8      ## jarak minimal antar benda di atas meja (meter).
@export var table_rest_gap := 0.01         ## celah kecil di atas permukaan meja (meter).

@export_group("Melayang")
@export var hover_height := 0.25        ## tinggi dasar benda dari lantai (meter), tidak berlaku di atas meja.
@export var bob_height := 0.04          ## naik-turun pelan (meter). 0 = diam.
@export var spin_items: PackedStringArray = ["koin"]  ## item yang berputar pelan.


func _ready() -> void:
	add_to_group("item_spawner")
	# Tunggu supaya semua node siap dan tabrakan peta (dibuat lantai_1.gd) sudah terdaftar di fisika.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	spawn_all()


func spawn_all() -> void:
	var corridor := _collect_points()
	var room_points := {}
	if spawn_in_rooms:
		room_points = _collect_room_points(_estimate_floor_y(_load_saved_points()))
		if room_points.is_empty():
			push_warning("ItemSpawner: tidak ada titik di ruangan. Benda dipasang di titik koridor.")
	if corridor.is_empty() and room_points.is_empty():
		push_warning("ItemSpawner: belum ada titik spawn. Rekam dulu pakai spawn_point_recorder.gd, atau isi Spawn Points Root.")
		return

	var floor_by_room := {}
	var table_by_room := {}
	for room_name in room_points:
		var d: Dictionary = room_points[room_name]
		if not (d["floor"] as Array).is_empty():
			floor_by_room[room_name] = d["floor"]
		if not (d["table"] as Array).is_empty():
			table_by_room[room_name] = d["table"]

	# Daftar benda yang akan disebar. Buku duluan supaya pasti kebagian titik.
	var queue: Array[Dictionary] = []
	if spawn_notebooks:
		var notebook: Dictionary = GameState.NOTEBOOK
		for _n in int(notebook.get("count", 7)):
			queue.append({"id": "notebook", "data": notebook})
	if spawn_items:
		for id in GameState.ITEMS:
			var data: Dictionary = GameState.ITEMS[id]
			for _n in int(data.get("spawn_count", 0)):
				queue.append({"id": id, "data": data})

	var corridor_entries: Array = []
	var room_entries: Array = []
	for entry in queue:
		if corridor_items.has(String(entry["id"])):
			corridor_entries.append(entry)
		else:
			room_entries.append(entry)

	# Pisahkan: mana yang mau di atas meja, mana yang di lantai.
	var table_entries: Array = []
	var floor_entries: Array = []
	for entry in room_entries:
		var chance := notebook_table_chance if String(entry["id"]) == "notebook" else item_table_chance
		if items_on_tables and not table_by_room.is_empty() and randf() < chance:
			table_entries.append(entry)
		else:
			floor_entries.append(entry)

	# Di atas meja (berdiri tegak, langsung menempel di permukaan).
	var table_result := _assign_points(table_entries, table_by_room, table_item_spacing)
	var table_chosen: Array = table_result["placed"]
	for item in table_chosen:
		_place(item["entry"], item["pos"], false, true)
	for entry in table_result["unplaced"]:
		floor_entries.append(entry)

	# Di lantai ruangan: sebar merata, dan tiap item hanya di ruangan yang cocok (lihat "rooms" di katalog).
	var room_result := _assign_points(floor_entries, floor_by_room, room_item_spacing)
	var room_chosen: Array = room_result["placed"]
	for item in room_chosen:
		_place(item["entry"], item["pos"], false, false)

	# Item koridor, ditambah item ruangan yang tidak kebagian titik di ruangan.
	var rest: Array = corridor_entries.duplicate()
	for entry in room_result["unplaced"]:
		rest.append(entry)
	var corridor_chosen := _pick_points(corridor, rest.size())
	for i in corridor_chosen.size():
		_place(rest[i], corridor_chosen[i], true, false)

	var total := table_chosen.size() + room_chosen.size() + corridor_chosen.size()
	if total < queue.size():
		push_warning("ItemSpawner: titik spawn kurang. Baru %d dari %d benda yang muncul." % [total, queue.size()])
	print("ItemSpawner: %d benda disebar (%d di atas meja, %d di lantai ruangan, %d di koridor)." % [
		total, table_chosen.size(), room_chosen.size(), corridor_chosen.size()])


func _place(entry: Dictionary, pos: Vector3, scatter: bool, on_table: bool) -> void:
	var pickup := _make_pickup(String(entry["id"]), entry["data"], not on_table)
	add_child(pickup)
	var offset := _random_offset() if scatter else Vector3.ZERO
	var lift := table_rest_gap if on_table else hover_height + height_offset
	pickup.global_position = pos + offset + Vector3.UP * lift
	if random_rotation:
		pickup.rotation.y = randf() * TAU


# Membuat satu benda yang bisa diambil: Area3D + script pickup + model (atau kotak warna pengganti).
# Model diratakan: tengahnya di titik pusat dan dasarnya tepat di y = 0, jadi benda selalu menapak
# di permukaan (atau melayang setinggi hover_height) apa pun letak pivot aslinya.
# floating = true: naik-turun pelan (dan berputar untuk spin_items). false (di atas meja): diam.
func _make_pickup(item_id: String, data: Dictionary, floating: bool) -> Area3D:
	var pickup := Area3D.new()
	pickup.name = item_id
	pickup.set_script(PICKUP_SCRIPT)
	pickup.set("item_id", item_id)
	if floating and bob_height > 0.0:
		pickup.set("bob_height", bob_height)
	if floating and spin_items.has(item_id):
		pickup.set("spin_speed", 1.6)

	var model: Node3D = null
	var model_path: String = data.get("model", "")
	if model_path != "" and ResourceLoader.exists(model_path):
		var packed := load(model_path) as PackedScene
		if packed != null:
			model = packed.instantiate() as Node3D
	if model == null:
		model = _placeholder(data.get("color", Color.GRAY))
	model.scale = Vector3.ONE * float(data.get("scale", 1.0))
	var box := _aabb_of(model)
	if box.size.length() > 0.0:
		model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	pickup.add_child(model)
	return pickup


func _placeholder(color: Color) -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	return mesh_instance


# Kotak pembatas gabungan semua mesh di dalam node (dalam ruang induknya, termasuk skala node ini).
func _aabb_of(node: Node, xf: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var found := false
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = xf * (node as MeshInstance3D).mesh.get_aabb()
		found = true
	for child in node.get_children():
		var sub := _aabb_of(child, xf)
		if sub.size != Vector3.ZERO:
			result = result.merge(sub) if found else sub
			found = true
	return result


# ------------------------------------------------------------------ titik koridor

func _collect_points() -> Array[Vector3]:
	var points: Array[Vector3] = _load_saved_points()
	if spawn_points_root != null:
		for child in spawn_points_root.get_children():
			if child is Node3D:
				points.append((child as Node3D).global_position)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var far_enough: Array[Vector3] = []
		for p in points:
			if p.distance_to(player.global_position) >= min_distance_from_player:
				far_enough.append(p)
		points = far_enough
	return points


func _load_saved_points() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not FileAccess.file_exists(points_path):
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(points_path))
	if parsed is Array:
		for entry in parsed:
			if entry is Array and entry.size() >= 3:
				result.append(Vector3(float(entry[0]), float(entry[1]), float(entry[2])))
	return result


# Pilih titik acak yang saling berjauhan. Kalau titiknya kurang renggang, dilengkapi dari sisa titik.
func _pick_points(points: Array[Vector3], needed: int) -> Array[Vector3]:
	points.shuffle()
	var chosen: Array[Vector3] = []
	for p in points:
		if chosen.size() >= needed:
			break
		if _far_from_all(p, chosen, min_item_spacing):
			chosen.append(p)
	if chosen.size() < needed:
		for p in points:
			if chosen.size() >= needed:
				break
			if not chosen.has(p):
				chosen.append(p)
	return chosen


func _random_offset() -> Vector3:
	if scatter_radius <= 0.0:
		return Vector3.ZERO
	var angle := randf() * TAU
	var dist := sqrt(randf()) * scatter_radius
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _far_from_all(p: Vector3, others: Array[Vector3], spacing: float) -> bool:
	for o in others:
		if p.distance_to(o) < spacing:
			return false
	return true


# Perkiraan tinggi lantai dari titik yang sudah direkam (nilai tengah). Dipakai kalau ruangan nggak punya mesh "lantai".
func _estimate_floor_y(saved: Array[Vector3]) -> float:
	if saved.is_empty():
		return 0.22
	var ys: Array[float] = []
	for p in saved:
		ys.append(p.y)
	ys.sort()
	return ys[int(ys.size() * 0.5)]


# ------------------------------------------------------------------ titik ruangan

# Mengembalikan {nama ruangan: {"floor": [titik lantai], "table": [titik di atas meja]}}.
func _collect_room_points(floor_y: float) -> Dictionary:
	var result := {}
	var holder := get_parent()
	var world := get_viewport().find_world_3d()
	if holder == null or world == null:
		return result
	var space := world.direct_space_state
	for child in holder.get_children():
		if not (child is Node3D) or not _is_room(String(child.name)):
			continue
		var room := child as Node3D
		var pts := _sample_room(room, space, floor_y)
		var n_floor: int = (pts["floor"] as Array).size()
		var n_table: int = (pts["table"] as Array).size()
		print("ItemSpawner: ruangan %s -> %d titik lantai, %d titik meja" % [room.name, n_floor, n_table])
		if n_floor > 0 or n_table > 0:
			result[String(room.name)] = pts
	return result


func _is_room(node_name: String) -> bool:
	var lower := node_name.to_lower()
	for prefix in room_prefixes:
		if lower.begins_with(prefix.to_lower()):
			return true
	return false


# Cari titik acak di satu ruangan. Lantai dicari dari mesh yang namanya diawali "lantai"/"floor".
# Kalau nggak ada, dipakai perkiraan dari kotak mesh ruangan dan tinggi lantai umum.
func _sample_room(room: Node3D, space: PhysicsDirectSpaceState3D, floor_y: float) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	if room is MeshInstance3D:
		meshes.append(room as MeshInstance3D)
	for node in room.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node as MeshInstance3D)

	var floors: Array[MeshInstance3D] = []
	for m in meshes:
		var lname := String(m.name).to_lower()
		if m.mesh != null and (lname.begins_with("lantai") or lname.begins_with("floor")):
			floors.append(m)

	var local_box := AABB()
	if floors.is_empty():
		local_box = _local_box(room, meshes)
		if local_box.size == Vector3.ZERO:
			return {"floor": [], "table": []}

	var player := get_tree().get_first_node_in_group("player") as Node3D

	var floor_pts: Array[Vector3] = []
	var attempts := 0
	while floor_pts.size() < max_points_per_room and attempts < candidates_per_room:
		attempts += 1
		var expected := _random_room_point(room, floors, local_box, floor_y)
		var checked: Variant = _check_floor(space, expected)
		if not (checked is Vector3):
			continue
		var p: Vector3 = checked
		if player != null and p.distance_to(player.global_position) < min_distance_from_player:
			continue
		if not _far_from_all(p, floor_pts, 1.0):
			continue
		floor_pts.append(p)

	var table_pts: Array[Vector3] = []
	if items_on_tables:
		attempts = 0
		while table_pts.size() < max_table_points_per_room and attempts < table_candidates_per_room:
			attempts += 1
			var expected := _random_room_point(room, floors, local_box, floor_y)
			var found: Variant = _check_table(space, expected)
			if not (found is Vector3):
				continue
			var t: Vector3 = found
			if player != null and t.distance_to(player.global_position) < min_distance_from_player:
				continue
			if not _far_from_all(t, table_pts, table_item_spacing):
				continue
			table_pts.append(t)

	return {"floor": floor_pts, "table": table_pts}


# Satu titik acak di lantai ruangan (tinggi lantai sudah diperkirakan).
func _random_room_point(room: Node3D, floors: Array[MeshInstance3D], local_box: AABB, floor_y: float) -> Vector3:
	if not floors.is_empty():
		return _random_on_floor_mesh(floors[randi() % floors.size()])
	var p := room.global_transform * Vector3(
		randf_range(local_box.position.x + local_box.size.x * 0.08, local_box.end.x - local_box.size.x * 0.08),
		local_box.position.y,
		randf_range(local_box.position.z + local_box.size.z * 0.08, local_box.end.z - local_box.size.z * 0.08))
	p.y = floor_y
	return p


# Titik acak di permukaan atas sebuah mesh lantai (sumbu "atas" dicari otomatis, jadi aman walau mesh diputar).
func _random_on_floor_mesh(floor_mesh: MeshInstance3D) -> Vector3:
	var a := floor_mesh.mesh.get_aabb()
	var gt := floor_mesh.global_transform
	var axes: Array[Vector3] = [gt.basis.x, gt.basis.y, gt.basis.z]
	var up_axis := 1
	var best := -1.0
	for ax in 3:
		var d := absf(axes[ax].normalized().dot(Vector3.UP))
		if d > best:
			best = d
			up_axis = ax
	var local := Vector3.ZERO
	for ax in 3:
		if ax == up_axis:
			local[ax] = a.end[ax] if axes[ax].dot(Vector3.UP) > 0.0 else a.position[ax]
		else:
			local[ax] = randf_range(a.position[ax] + a.size[ax] * 0.1, a.end[ax] - a.size[ax] * 0.1)
	return gt * local


# Kotak gabungan semua mesh, diukur dalam ruang lokal ruangan.
func _local_box(room: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var inv := room.global_transform.affine_inverse()
	var box := AABB()
	var has_any := false
	for m in meshes:
		if m.mesh == null:
			continue
		var part: AABB = (inv * m.global_transform) * m.mesh.get_aabb()
		box = box.merge(part) if has_any else part
		has_any = true
	return box


func _cast_down(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.collide_with_areas = false
	return space.intersect_ray(ray)


# Cek titik lantai: ada lantai (permukaan datar di tinggi yang diharapkan), dan di sekitarnya kosong
# dari dinding/perabot. Mengembalikan titik lantai sebenarnya (Vector3) atau null kalau nggak cocok.
func _check_floor(space: PhysicsDirectSpaceState3D, expected: Vector3) -> Variant:
	var hit := _cast_down(space, expected + Vector3.UP * 1.6, expected + Vector3.DOWN * 1.0)
	if hit.is_empty():
		return null
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	if normal.y < 0.85 or absf(pos.y - expected.y) > floor_tolerance:
		return null

	var sphere := SphereShape3D.new()
	sphere.radius = clearance
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * (clearance + 0.12))
	query.collide_with_areas = false
	if not space.intersect_shape(query, 1).is_empty():
		return null
	return pos


# Cek permukaan meja di atas titik lantai "expected": sinar dari atas ke bawah, permukaan pertama yang kena harus
# datar, setinggi meja, cukup lebar (kursi dan sandaran nggak lolos), dan ruang di atasnya kosong
# (nggak ada monitor/buku lain). Mengembalikan titik di permukaan meja (Vector3) atau null.
func _check_table(space: PhysicsDirectSpaceState3D, expected: Vector3) -> Variant:
	var from := Vector3(expected.x, expected.y + table_max_height + 0.25, expected.z)
	var to := Vector3(expected.x, expected.y + table_min_height - 0.2, expected.z)
	var hit := _cast_down(space, from, to)
	if hit.is_empty():
		return null
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var h := pos.y - expected.y
	if normal.y < 0.9 or h < table_min_height or h > table_max_height:
		return null

	# Permukaannya harus datar dan lebar: empat titik di sekeliling harus kena permukaan setinggi yang sama.
	var reach := table_min_size * 0.5
	for off in [Vector3(reach, 0, 0), Vector3(-reach, 0, 0), Vector3(0, 0, reach), Vector3(0, 0, -reach)]:
		var o: Vector3 = Vector3(pos.x, pos.y + 0.3, pos.z) + off
		var r := _cast_down(space, o, o + Vector3.DOWN * 0.7)
		if r.is_empty():
			return null
		var rp: Vector3 = r["position"]
		var rn: Vector3 = r["normal"]
		if absf(rp.y - pos.y) > 0.03 or rn.y < 0.9:
			return null

	# Ruang di atas titik harus kosong (cukup buat item yang berdiri, setinggi sekitar 0,45 m).
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.45, 0.3)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * (0.225 + 0.04))
	query.collide_with_areas = false
	if not space.intersect_shape(query, 1).is_empty():
		return null
	return pos


# Bagi titik ke daftar benda. by_room = {nama ruangan: [titik]}. Tiap benda hanya di ruangan yang cocok dengan
# "rooms" di katalog (kosong = di mana saja; kalau ruangan yang cocok nggak punya titik, dipakai ruangan mana saja).
# Ruangan yang paling sedikit terpakai diutamakan supaya merata. Mengembalikan {"placed": [{entry, pos}], "unplaced": [entry]}.
func _assign_points(entries: Array, by_room: Dictionary, spacing: float) -> Dictionary:
	var pool := {}
	for room_name in by_room:
		var shuffled: Array = (by_room[room_name] as Array).duplicate()
		shuffled.shuffle()
		pool[room_name] = shuffled
	var used := {}
	var taken: Array[Vector3] = []
	var placed: Array = []
	var unplaced: Array = []
	for entry in entries:
		var names := _allowed_rooms(entry, pool)
		names.shuffle()
		names.sort_custom(func(a, b): return int(used.get(a, 0)) < int(used.get(b, 0)))
		var done := false
		for room_name in names:
			var candidates: Array = pool[room_name]
			while not candidates.is_empty():
				var p: Vector3 = candidates.pop_back()
				if _far_from_all(p, taken, spacing):
					taken.append(p)
					used[room_name] = int(used.get(room_name, 0)) + 1
					placed.append({"entry": entry, "pos": p})
					done = true
					break
			if done:
				break
		if not done:
			unplaced.append(entry)
	return {"placed": placed, "unplaced": unplaced}


func _allowed_rooms(entry: Dictionary, pool: Dictionary) -> Array:
	var all_names: Array = []
	for room_name in pool:
		if not (pool[room_name] as Array).is_empty():
			all_names.append(room_name)
	var prefixes: Array = (entry["data"] as Dictionary).get("rooms", [])
	if prefixes.is_empty():
		return all_names
	var matched: Array = []
	for room_name in all_names:
		var lower := String(room_name).to_lower()
		for prefix in prefixes:
			if lower.begins_with(String(prefix).to_lower()):
				matched.append(room_name)
				break
	return matched if not matched.is_empty() else all_names


## Munculkan satu benda di posisi lantai tertentu (dipakai loker untuk isinya).
func spawn_item_at(item_id: String, pos: Vector3) -> void:
	var data: Dictionary = GameState.NOTEBOOK if item_id == "notebook" else GameState.ITEMS.get(item_id, {})
	if data.is_empty():
		push_warning("ItemSpawner: item tidak dikenal: %s" % item_id)
		return
	var pickup := _make_pickup(item_id, data, true)
	add_child(pickup)
	pickup.global_position = pos + Vector3.UP * (hover_height + height_offset)
	if random_rotation:
		pickup.rotation.y = randf() * TAU
