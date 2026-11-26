extends Node
## Pengatur alur game ala Baldi's Basics. Satu node ini di lantai 1.tscn (namai GameFlow).
##
## Alur:
##  1. Game mulai: Jennifer melambai dan menyapa (subtitle di bawah layar). Potongan kunci muncul di tiap KeyPoint.
##  2. Tiap buku diambil: papan soal hijau muda (ThinkPad, dipanggil NotebookTracker). Jawaban salah bikin Jennifer makin cepat. Dia mulai ngejar setelah buku pertama.
##  3. Kumpulkan SEMUA potongan kunci (tiap potongan punya syarat ambil sendiri, lihat key_piece.gd).
##     Setelah lengkap, "Kunci Gerbang" utuh masuk ke inventory.
##  4. Semua buku terkumpul: Jennifer ngamuk. Buka gerbang pakai Kunci Gerbang (klik kanan dari dekat), lari keluar = menang.
##     Menang -> kredit. Ketangkap -> game mengulang.
##
## Buku dideteksi otomatis dari node di group "pickup" yang item_id-nya "notebook" (menghilang = diambil).

@export var jennifer_path: NodePath
@export var spawner_path: NodePath
@export var key_points: Array[NodePath] = []   ## Marker3D di lantai. Tiap KeyPoint = 1 potongan kunci (maks 3).
@export var total_books := 7
@export var broken_book_count := 4             ## berapa buku (dari total) yang berisi 1 soal rusak
@export var key_item_id := "kunci_gerbang"
@export var restart_delay := 3.5
@export var intro_line_seconds := 2.8
@export var intro_lines: PackedStringArray = [
	"Good evening.",
	"How are you feeling today?",
]
@export_group("Cutscene")
## Cutscene pembuka (chat, terbang di atas peta lantai 1, Jennifer menyapa, judul). SPASI / ENTER = lewati.
@export var opening_cutscene := true
## true = cutscene cuma diputar sekali per sesi game (retry setelah kalah langsung main).
@export var opening_once_per_session := false
## Cutscene ending 2 (berhasil kabur): buka gembok, lari keluar gerbang, Jennifer frustrasi. Mati = langsung kabur tanpa cutscene.
@export var escape_cutscene := true
@export_group("Sembunyi")
## Otomatis jadikan meja kelas (yang terdeteksi ItemSpawner) sebagai tempat sembunyi kolong meja. Nggak perlu aset/pasang manual.
@export var auto_desk_hiding := true          ## SEMUA meja kelas yang terdeteksi jadi tempat sembunyi
@export var auto_cabinets := true              ## lemari otomatis dipasang di POJOK tiap ruangan (jauh dari pintu)
@export var cabinets_per_room := 1
@export var max_desk_spots := 150
@export var desk_scan_step := 0.35             ## kerapatan pemindaian (meter)
@export var desk_min_height := 0.55            ## tinggi permukaan meja dari lantai
@export var desk_max_height := 1.1
@export var desk_min_top := 0.3                ## lebar minimal permukaan datar (meja murid kecil, kursi nggak lolos)
@export var desk_cluster := 0.55               ## titik sedekat ini dianggap satu meja
@export_group("Musik")
@export var use_music_director := true         ## musik latar adaptif (tenang/tegang/kejar) menggantikan lagu menu
@export_group("Kredit")
## Scene kredit buatanmu. Kosong = pakai kredit gulir bawaan dari file teks di bawah.
@export_file("*.tscn") var credits_scene_path := ""
@export_file("*.txt") var credits_text_path := "res://Credit.txt"
## Kosong = otomatis pakai scene utama proyek (biasanya main menu).
@export_file("*.tscn") var main_menu_path := ""

const OPENING_PATH := "res://scripts/opening_cutscene.gd"
const ESCAPE_PATH := "res://scripts/escape_cutscene.gd"
const KEY_PIECE := preload("res://scripts/key_piece.gd")
const HIDING_SPOT := preload("res://scripts/hiding_spot.gd")
const JUMPSCARE := preload("res://scripts/jumpscare.gd")
const CAUGHT_CUTSCENE := preload("res://scripts/caught_cutscene.gd")
const SUBS := preload("res://scripts/subtitle_data.gd")
const MAIN_MENU_SCENE := "res://MAIN MENU/SCENE/MainMenu.tscn"
const CREDITS_SCENE := "res://MAIN MENU/SCENE/credits.tscn"

var _jennifer: Node
var _spawner: Node
var _initial := 0
var _collected := 0
var _pending := 0
var _quiz_no := 0
var _wrong_this_book := 0
var _books_done := false
var _pieces_total := 0
var _pieces_got := 0
var _ended := false
var _rolling := false
var _poll := 0.0
var _subtitle: Label


func _ready() -> void:
	add_to_group("game_flow")
	QuestionBank.roll_broken_books(total_books, broken_book_count)
	var cut := _make_opening()   # layar langsung hitam sebelum pemain sempat melihat dunia
	await get_tree().create_timer(0.6).timeout   # tunggu ItemSpawner selesai menyebar
	_jennifer = get_node_or_null(jennifer_path)
	if _jennifer == null:
		_jennifer = get_tree().get_first_node_in_group("teacher")
	_spawner = get_node_or_null(spawner_path)
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("item_spawner")
	if _jennifer == null:
		push_warning("GameFlow: node Jennifer (group 'teacher') belum ada.")
	var tracker := get_tree().get_first_node_in_group("notebook_tracker")
	if tracker != null:
		tracker.connect("quiz_answered", _on_quiz_answered)
		tracker.connect("notebook_collected", _on_book_done)
	if cut != null:
		cut.call("run", _jennifer, intro_lines, intro_line_seconds)
		await cut.finished
		Engine.set_meta("opening_seen", true)
	_spawn_pieces()   # setelah cutscene, supaya cahaya potongan kunci nggak kelihatan dari udara
	if use_music_director and ResourceLoader.exists("res://scripts/music_director.gd"):
		var md := Node.new()
		md.name = "MusicDirector"
		md.set_script(load("res://scripts/music_director.gd"))
		add_child(md)
	if cut == null:
		_intro()
	else:
		GameState.notice.emit("Tip: get close to a desk or locker and press [E] to hide")
	if auto_desk_hiding or auto_cabinets:
		await get_tree().physics_frame
		_spawn_hiding_spots()


## Bikin node cutscene pembuka. Null = cutscene mati / sudah pernah diputar / script bermasalah (pakai intro lama).
func _make_opening() -> Node:
	if not opening_cutscene:
		print("GameFlow: cutscene pembuka MATI (opening_cutscene = false di Inspector GameFlow).")
		return null
	if not ResourceLoader.exists(OPENING_PATH):
		push_warning("GameFlow: %s nggak ada. Taruh opening_cutscene.gd di folder res://scripts/." % OPENING_PATH)
		return null
	if opening_once_per_session and Engine.has_meta("opening_seen"):
		print("GameFlow: cutscene pembuka dilewati (sudah pernah diputar di sesi ini).")
		return null
	var node := Node.new()
	node.name = "OpeningCutscene"
	node.set_script(load(OPENING_PATH))
	if not (node.has_method("run") and node.has_method("cover") and node.has_signal("finished")):
		push_warning("GameFlow: opening_cutscene.gd gagal dimuat, pakai intro biasa.")
		node.free()
		return null
	add_child(node)
	var jen := get_node_or_null(jennifer_path)
	if jen == null:
		jen = get_tree().get_first_node_in_group("teacher")
	node.call("cover", get_parent(), jen)
	print("GameFlow: cutscene pembuka dimulai.")
	return node


## Dipanggil school_gate.gd: gerbang cuma boleh dibuka kalau semua buku sudah terkumpul.
func all_books_collected() -> bool:
	return _books_done


# ------------------------------------------------------------------ potongan kunci

func _spawn_pieces() -> void:
	var i := 0
	for path in key_points:
		if i >= 3:
			break
		var point := get_node_or_null(path) as Node3D
		if point == null:
			continue
		var piece := Node3D.new()
		piece.set_script(KEY_PIECE)
		piece.set("piece_index", i)
		piece.set("challenge", i)   # 0 HOLD, 1 COIN, 2 FAR
		add_child(piece)
		piece.global_position = point.global_position
		piece.connect("collected", _on_piece_collected)
		_pieces_total += 1
		i += 1
	if _pieces_total == 0:
		push_warning("GameFlow: key_points kosong, potongan kunci nggak muncul. Isi Key Points di Inspector.")
	else:
		print("GameFlow: %d potongan kunci disebar." % _pieces_total)


func _on_piece_collected() -> void:
	_pieces_got += 1
	GameState.notice.emit("Key piece %d/%d collected!" % [_pieces_got, _pieces_total])
	if _pieces_got >= _pieces_total:
		_assemble_key()


func _assemble_key() -> void:
	if GameState.add_item(key_item_id):
		GameState.notice.emit("Gate Key complete! Got all the notebooks? Go to the gate and right-click.")
		return
	# Inventory penuh: jatuhkan kuncinya di dekat player.
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null and _spawner != null:
		_spawner.call("spawn_item_at", key_item_id, p.global_position + Vector3(0, 0, 1.0))
		GameState.notice.emit("Gate Key complete, but your inventory is full. The key dropped near you!")


# ------------------------------------------------------------------ tempat sembunyi otomatis (meja dan lemari)

func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	return space.intersect_ray(q)


func _free_box(space: PhysicsDirectSpaceState3D, center: Vector3, size: Vector3, yaw := 0.0) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(Vector3.UP, yaw), center)
	q.collide_with_areas = false
	return space.intersect_shape(q, 1).is_empty()


func _room_prefixes() -> PackedStringArray:
	if _spawner != null:
		var p: Variant = _spawner.get("room_prefixes")
		if p is PackedStringArray:
			return p
	return PackedStringArray(["kelas", "ruang guru", "ruang lab", "toilet"])


func _room_bounds(room: Node3D) -> AABB:
	var box := AABB()
	var has := false
	for m in room.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var part: AABB = mi.global_transform * mi.get_aabb()
		box = box.merge(part) if has else part
		has = true
	return box if has else AABB()


func _add_spot(kind: int, pos: Vector3, yaw: float, exit_dist: float, build_model: bool) -> void:
	var spot := Node3D.new()
	spot.set_script(HIDING_SPOT)
	spot.set("kind", kind)              # 0 = lemari, 1 = kolong meja
	spot.set("build_model", build_model)
	spot.set("exit_offset", Vector3(0, 0, exit_dist))
	if kind == 0:
		spot.set_meta("auto_cabinet", true)   # dipakai _prune_blocking_cabinets()
	get_tree().current_scene.add_child(spot)
	spot.global_position = pos
	spot.rotation.y = yaw


func _spawn_hiding_spots() -> void:
	var floor_y := 0.22
	if _spawner != null and _spawner.has_method("_estimate_floor_y") and _spawner.has_method("_load_saved_points"):
		var saved: Variant = _spawner.call("_load_saved_points")
		floor_y = float(_spawner.call("_estimate_floor_y", saved))
	var holder: Node = _spawner.get_parent() if _spawner != null else get_tree().current_scene
	var prefixes := _room_prefixes()
	var desks := 0
	var cabinets := 0
	for child in holder.get_children():
		if not (child is Node3D) or not _is_room_name(String(child.name), prefixes):
			continue
		var box := _room_bounds(child as Node3D)
		if box.size == Vector3.ZERO:
			continue
		var space := get_viewport().find_world_3d().direct_space_state
		if auto_desk_hiding and desks < max_desk_spots:
			desks += _make_desk_spots(space, box, floor_y, max_desk_spots - desks)
		if auto_cabinets and not String(child.name).to_lower().begins_with("toilet"):
			cabinets += _place_cabinets(space, box, floor_y)
		await get_tree().physics_frame
	print("GameFlow: %d tempat sembunyi kolong meja + %d lemari dibuat otomatis." % [desks, cabinets])
	await get_tree().physics_frame
	await get_tree().physics_frame
	_prune_blocking_cabinets()


func _is_room_name(node_name: String, prefixes: PackedStringArray) -> bool:
	var lower := node_name.to_lower()
	for pfx in prefixes:
		if lower.begins_with(String(pfx).to_lower()):
			return true
	return false


# Tinggi permukaan atas meja di (x, z), atau -999 kalau di situ bukan permukaan datar setinggi meja.
func _desk_top(space: PhysicsDirectSpaceState3D, x: float, z: float, floor_y: float) -> float:
	var hit := _ray(space, Vector3(x, floor_y + desk_max_height + 0.25, z), Vector3(x, floor_y + desk_min_height - 0.2, z))
	if hit.is_empty():
		return -999.0
	var p: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	var h := p.y - floor_y
	if n.y < 0.9 or h < desk_min_height or h > desk_max_height:
		return -999.0
	return p.y


func _make_desk_spots(space: PhysicsDirectSpaceState3D, box: AABB, floor_y: float, budget: int) -> int:
	# 1) pindai grid: titik di permukaan datar selebar desk_min_top dan ada kolong kosong di bawahnya
	var pts: Array[Vector3] = []
	var half := desk_min_top * 0.5
	var x := box.position.x
	while x <= box.end.x:
		var z := box.position.z
		while z <= box.end.z:
			var top := _desk_top(space, x, z, floor_y)
			if top > -900.0:
				var ok := true
				for off in [Vector2(half, 0), Vector2(-half, 0), Vector2(0, half), Vector2(0, -half)]:
					var t2 := _desk_top(space, x + off.x, z + off.y, floor_y)
					if t2 < -900.0 or absf(t2 - top) > 0.04:
						ok = false
						break
				if ok:
					var under := _ray(space, Vector3(x, top - 0.12, z), Vector3(x, floor_y - 0.4, z))
					if not under.is_empty() and (under["position"] as Vector3).y < floor_y + 0.15:
						pts.append(Vector3(x, (under["position"] as Vector3).y, z))
			z += desk_scan_step
		x += desk_scan_step
	# 2) gabungkan titik berdekatan jadi satu meja
	var centers: Array[Vector3] = []
	var counts: Array[int] = []
	for p in pts:
		var found := -1
		for i in centers.size():
			if Vector2(centers[i].x - p.x, centers[i].z - p.z).length() < desk_cluster:
				found = i
				break
		if found >= 0:
			centers[found] = (centers[found] * counts[found] + p) / (counts[found] + 1)
			counts[found] += 1
		else:
			centers.append(p)
			counts.append(1)
	# 3) pasang tempat sembunyi; arah keluar = sisi yang cukup kosong buat berdiri
	var made := 0
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	for c in centers:
		if made >= budget:
			break
		var placed := false
		for dist in [1.5, 1.15]:
			dirs.shuffle()
			for d in dirs:
				var front: Vector3 = c + d * dist
				if _free_box(space, front + Vector3.UP * 0.9, Vector3(0.6, 1.6, 0.6)):
					_add_spot(1, c, atan2(d.x, d.z), dist, false)
					made += 1
					placed = true
					break
			if placed:
				break
	return made


# Lemari dipasang di POJOK ruangan (bukan tengah dinding), jadi nggak menghalangi pintu masuk atau jalan.
# Pengecekan dinding memakai sinar rendah (50 cm dari lantai) supaya jendela nggak dianggap bukaan, tapi celah pintu tetap ketahuan.
# Dicoba dua tingkat: ketat (dinding utuh 2 m dari lemari), lalu agak longgar. Kalau gagal, alasannya dicetak di Output.
func _place_cabinets(space: PhysicsDirectSpaceState3D, box: AABB, floor_y: float) -> int:
	var made := 0
	var c3 := box.get_center()
	var d_right := _wall_dist(space, c3, floor_y, Vector3.RIGHT, box)
	var d_left := _wall_dist(space, c3, floor_y, Vector3.LEFT, box)
	var d_back := _wall_dist(space, c3, floor_y, Vector3.BACK, box)
	var d_fwd := _wall_dist(space, c3, floor_y, Vector3.FORWARD, box)
	if d_right < 0.0 or d_left < 0.0 or d_back < 0.0 or d_fwd < 0.0:
		print("Lemari: dinding ruangan di (%.1f, %.1f) nggak terdeteksi, dilewati." % [c3.x, c3.z])
		return 0
	var x_max := c3.x + d_right
	var x_min := c3.x - d_left
	var z_max := c3.z + d_back
	var z_min := c3.z - d_fwd
	var corners: Array[Vector2] = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]
	corners.shuffle()
	var used: Array[Vector2] = []
	var why := {"pintu/bukaan": 0, "terhalang": 0}
	for level in [2, 1]:
		for c in corners:
			if made >= cabinets_per_room:
				return made
			if used.has(c):
				continue
			var wx := x_max if c.x > 0.0 else x_min
			var wz := z_max if c.y > 0.0 else z_min
			if _try_corner(space, c, wx, wz, floor_y, level, why):
				made += 1
				used.append(c)
	if made == 0:
		print("Lemari: ruangan di (%.1f, %.1f) gagal. Ditolak karena pintu/bukaan: %d, terhalang: %d." % [c3.x, c3.z, why["pintu/bukaan"], why["terhalang"]])
	return made


func _try_corner(space: PhysicsDirectSpaceState3D, c: Vector2, wx: float, wz: float, floor_y: float, level: int, why: Dictionary) -> bool:
	var sx: float = c.x
	var sz: float = c.y
	for against_x in [true, false]:
		var d := Vector3(sx, 0.0, 0.0) if against_x else Vector3(0.0, 0.0, sz)      # arah ke dinding tempat punggung lemari
		var side := Vector3(0.0, 0.0, sz) if against_x else Vector3(sx, 0.0, 0.0)    # arah ke dinding samping (sudut)
		for off in [0.65, 1.0, 1.5]:   # jarak dari dinding samping; sedikit geser dari sudut kalau sudutnya terhalang
			var px: float = wx - sx * (0.5 if against_x else float(off))
			var pz: float = wz - sz * (float(off) if against_x else 0.5)
			var pos := Vector3(px, floor_y, pz)
			var fl := _ray(space, pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 1.0)
			if not fl.is_empty():
				pos.y = (fl["position"] as Vector3).y
			var yaw := atan2(-d.x, -d.z)    # depan lemari (+Z) menghadap ke tengah ruangan
			if not _corner_is_solid(space, pos, d, side, off, level):
				why["pintu/bukaan"] += 1
				continue
			if not _free_box(space, pos + Vector3.UP * 1.1, Vector3(1.14, 2.0, 0.78), yaw) \
					or not _free_box(space, pos - d * 1.5 + Vector3.UP * 0.9, Vector3(0.8, 1.6, 0.8)):
				why["terhalang"] += 1
				continue
			_add_spot(0, pos, yaw, 1.5, true)
			return true
	return false


# Jarak median dari titik tengah ke dinding tegak searah d (-1 kalau nggak ketemu).
# Sinar di dua ketinggian (dada dan 50 cm) supaya jendela / kaki meja nggak merusak hasil.
func _wall_dist(space: PhysicsDirectSpaceState3D, c3: Vector3, floor_y: float, d: Vector3, box: AABB) -> float:
	var tangent := d.cross(Vector3.UP).normalized()
	var span := (box.size.z if absf(tangent.z) > 0.5 else box.size.x) * 0.5
	var reach := (box.size.x if absf(d.x) > 0.5 else box.size.z) * 0.5 + 1.0
	var dists: Array[float] = []
	for h in [1.2, 0.5]:
		for frac in [0.0, -0.25, 0.25, -0.5, 0.5, -0.7, 0.7]:
			var origin: Vector3 = Vector3(c3.x, floor_y + h, c3.z) + tangent * span * frac
			var hit := _ray(space, origin, origin + d * reach)
			if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
				continue
			dists.append(origin.distance_to(hit["position"] as Vector3))
	if dists.size() < 3:
		return -1.0
	dists.sort()
	return dists[int(dists.size() * 0.5)]


# True kalau dinding di sekitar calon lemari utuh (tanpa pintu / bukaan). Sinar rendah (50 cm): jendela diabaikan, pintu ketahuan.
# Sinar dirapatkan tiap 20 cm supaya celah pintu yang sebagian tertutup daun pintu tetap ketahuan.
func _corner_is_solid(space: PhysicsDirectSpaceState3D, pos: Vector3, d: Vector3, side: Vector3, off: float, level: int) -> bool:
	var base := Vector3(pos.x, pos.y + 0.5, pos.z)
	var s: float = -(off - 0.2)    # dari dekat sudut, sepanjang dinding belakang lemari, menjauhi sudut
	var s_to: float = 2.6 if level >= 2 else 1.8
	while s <= s_to:
		var o: Vector3 = base - side * s
		if _ray(space, o, o + d * 1.0).is_empty():
			return false
		s += 0.2
	var t := 0.0                   # sepanjang dinding samping, menjauhi dinding belakang
	var t_to: float = 2.4 if level >= 2 else 1.6
	while t <= t_to:
		var o2: Vector3 = base - d * t
		if _ray(space, o2, o2 + side * (off + 0.8)).is_empty():
			return false
		t += 0.2
	return true


# Pemeriksaan akhir: lemari otomatis yang berdiri di bukaan pintu (dinding di belakangnya putus) dihapus.
func _prune_blocking_cabinets() -> void:
	var space := get_viewport().find_world_3d().direct_space_state
	var removed := 0
	for spot in get_tree().get_nodes_in_group("hide_spot"):
		var sp := spot as Node3D
		if sp == null or not sp.has_meta("auto_cabinet") or sp.is_queued_for_deletion():
			continue
		if _cabinet_in_doorway(space, sp):
			print("Lemari dihapus (menghalangi pintu/bukaan) di ", sp.global_position)
			sp.queue_free()
			removed += 1
	if removed > 0:
		print("GameFlow: %d lemari dihapus karena menghalangi pintu." % removed)


func _cabinet_in_doorway(space: PhysicsDirectSpaceState3D, sp: Node3D) -> bool:
	var ex: Array[RID] = []
	for n in sp.find_children("*", "CollisionObject3D", true, false):
		ex.append((n as CollisionObject3D).get_rid())
	var tf := sp.global_transform
	var inv := tf.affine_inverse()
	# batas kiri/kanan: berhenti di dinding samping kalau ada (lemari di sudut)
	var lim: Array[float] = [1.6, 1.6]
	for i in 2:
		var sgn := -1.0 if i == 0 else 1.0
		var qs := PhysicsRayQueryParameters3D.create(tf * Vector3(0.0, 0.5, 0.9), tf * Vector3(sgn * 1.6, 0.5, 0.9))
		qs.collide_with_areas = false
		qs.exclude = ex
		var hs := space.intersect_ray(qs)
		if not hs.is_empty():
			lim[i] = absf((inv * (hs["position"] as Vector3)).x)
	var x: float = -lim[0] + 0.15
	while x <= lim[1] - 0.15:
		var q := PhysicsRayQueryParameters3D.create(tf * Vector3(x, 0.5, 1.3), tf * Vector3(x, 0.5, -1.4))
		q.collide_with_areas = false
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return true
		if (inv * (hit["position"] as Vector3)).z < -0.95:
			return true
		x += 0.2
	return false


# ------------------------------------------------------------------ sambutan

func _intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -200.0
	holder.offset_bottom = -90.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.03, 0.62)
	style.set_corner_radius_all(18)
	style.border_color = Color(0.55, 0.38, 0.2, 0.9)
	style.set_border_width_all(2)
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.modulate.a = 0.0
	holder.add_child(panel)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 30)
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	panel.add_child(_subtitle)
	if _jennifer != null and _jennifer.has_method("greet"):
		_jennifer.call("greet", false)
	for i in intro_lines.size():
		_subtitle.text = SUBS.line("intro%d" % (i + 1), intro_lines[i])
		_subtitle.visible_ratio = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(panel, "modulate:a", 1.0, 0.3)
		tw.tween_property(_subtitle, "visible_ratio", 1.0, clampf(intro_lines[i].length() * 0.035, 0.6, 1.8))
		if _jennifer != null and _jennifer.has_method("speak"):
			_jennifer.call("speak", "intro%d" % (i + 1))
		await get_tree().create_timer(intro_line_seconds + 1.4).timeout
	create_tween().tween_property(panel, "modulate:a", 0.0, 0.5)
	GameState.notice.emit("Tip: get close to a desk or locker and press [E] to hide")


# ------------------------------------------------------------------ buku dan soal

func _process(delta: float) -> void:
	if _ended:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.2
	var remaining := _remaining_notebooks()
	if _initial == 0:
		_initial = remaining   # tunggu sampai buku selesai disebar
		return
	var collected := _initial - remaining
	while _collected < collected:
		_collected += 1
		_pending += 1
		if _jennifer != null and _jennifer.has_method("on_notebook_collected"):
			_jennifer.call("on_notebook_collected", _collected)
	_try_open_quiz()


func _remaining_notebooks() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and str(node.get("item_id")) == "notebook":
			n += 1
	return n


func _try_open_quiz() -> void:
	# Papan soal dibuka oleh NotebookTracker saat buku diambil. Di sini cuma menghitung buku yang selesai dijawab.
	while _pending > 0 and not _ended:
		_pending -= 1
		_quiz_no += 1
		if _quiz_no >= total_books and _pending == 0:
			_all_books()


## Tiap jawaban salah di papan soal bikin Jennifer marah.
func _on_quiz_answered(correct: bool) -> void:
	if correct:
		return
	_wrong_this_book += 1
	if _jennifer != null and _jennifer.has_method("add_anger"):
		_jennifer.call("add_anger", 1.0)


## Papan soal selesai dan bukunya dihitung. Semua jawaban benar = Jennifer tenang.
func _on_book_done(_count: int, _total: int) -> void:
	if _wrong_this_book == 0 and _jennifer != null and _jennifer.has_method("say"):
		_jennifer.call("say", "Correct.", 2.5, "good")
	_wrong_this_book = 0


func _all_books() -> void:
	_books_done = true
	var left := _pieces_total - _pieces_got
	if left > 0:
		GameState.notice.emit("All notebooks collected! %d key pieces left. Find them, then escape!" % left)
	else:
		GameState.notice.emit("All notebooks collected! Open the gate and escape!")
	if _jennifer != null and _jennifer.has_method("enter_rage"):
		_jennifer.call("enter_rage")


# ------------------------------------------------------------------ menang / kalah

func on_caught() -> void:
	if _ended:
		return
	_ended = true
	var jen := _jennifer
	if jen == null:
		jen = get_tree().get_first_node_in_group("teacher")
	var js := Node.new()
	js.set_script(JUMPSCARE)
	add_child(js)
	js.call("run", jen)
	await js.finished
	# Ending 1 (tertangkap): cutscene ruang guru
	var cs := Node.new()
	cs.set_script(CAUGHT_CUTSCENE)
	add_child(cs)
	cs.call("run", jen)
	var old_cam: Variant = js.get("_cam")
	js.queue_free()
	if old_cam is Node and is_instance_valid(old_cam):
		(old_cam as Node).queue_free()
	await cs.finished
	GameState.set_process_unhandled_input(true)
	GameState.reset()
	_to_main_menu()   # game over -> kembali ke main menu


## Dipanggil school_gate.gd saat Kunci Gerbang dipakai (semua buku sudah terkumpul). true = cutscene ending 2 mengambil alih
## (cutscene sendiri yang membuka gerbang), false = gerbang dibuka seperti biasa.
func on_gate_unlock(gate: Node) -> bool:
	if _ended or not escape_cutscene or not ResourceLoader.exists(ESCAPE_PATH):
		return false
	var script := load(ESCAPE_PATH) as Script
	if script == null:
		return false
	_ended = true   # cegah ketangkap / on_escape dobel selama cutscene
	_play_escape(gate, script)
	return true


func _play_escape(gate: Node, script: Script) -> void:
	var cs := Node.new()
	cs.name = "EscapeCutscene"
	cs.set_script(script)
	add_child(cs)
	cs.call("run", gate)
	await cs.finished
	GameState.set_process_unhandled_input(true)
	GameState.reset()
	_go_credits()   # ending 2 -> kredit, sama seperti kabur biasa


func on_escape() -> void:
	_end("YOU ESCAPED!\nSee you at school tomorrow.", Color(0.0, 0.35, 0.1, 0.85), true)


func _end(text: String, color: Color, win: bool) -> void:
	if _ended:
		return
	_ended = true
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(color.r, color.g, color.b, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.modulate.a = 0.0
	center.add_child(box)
	var lines := text.split("\n")
	var title := Label.new()
	title.text = lines[0]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	box.add_child(title)
	if lines.size() > 1:
		var sub := Label.new()
		sub.text = lines[1]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 34)
		sub.modulate = Color(1, 1, 1, 0.85)
		box.add_child(sub)
	get_tree().paused = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(bg, "color:a", color.a, 0.9)
	tw.tween_property(box, "modulate:a", 1.0, 1.0).set_delay(0.3)
	await get_tree().create_timer(restart_delay, true).timeout
	GameState.reset()
	if win:
		_go_credits()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()


# ------------------------------------------------------------------ kredit

func _go_credits() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var path := credits_scene_path if credits_scene_path != "" else CREDITS_SCENE
	if ResourceLoader.exists(path):
		get_tree().paused = false
		get_tree().change_scene_to_file(path)   # credits selesai -> otomatis ke main menu
		return
	_roll_credits()


# Kredit gulir bawaan: isi dari credits_text_path (bawaan res://Credit.txt). Klik/tombol apa saja = lewati.
func _roll_credits() -> void:
	_rolling = true
	process_mode = Node.PROCESS_MODE_ALWAYS   # supaya tombol lewati tetap terbaca saat game di-pause
	var text := "THANK YOU FOR PLAYING"
	if FileAccess.file_exists(credits_text_path):
		text = FileAccess.get_file_as_string(credits_text_path)
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 300
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(vp.x * 0.8, 0)
	label.size = Vector2(vp.x * 0.8, 10)
	label.add_theme_font_size_override("font_size", 34)
	label.position = Vector2(vp.x * 0.1, vp.y)
	layer.add_child(label)
	await get_tree().process_frame
	var height := label.get_minimum_size().y
	var seconds := maxf(12.0, height / 70.0)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(label, "position:y", -height - 40.0, seconds)
	tw.tween_interval(1.0)
	await tw.finished
	if _rolling:
		_rolling = false
		_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	# --- TOMBOL TES (hapus kalau sudah selesai) ---
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F9:       # ending 2: kabur
			var g := get_tree().get_first_node_in_group("school_gate")
			if g != null:
				on_gate_unlock(g)
		elif event.keycode == KEY_F10:    # ending 1: tertangkap
			on_caught()
	# ----------------------------------------------
	# Lewati kredit gulir bawaan dengan klik/tombol apa saja.
	if _rolling and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_rolling = false
		_to_main_menu()
	# Lewati kredit gulir bawaan dengan klik/tombol apa saja.
	if _rolling and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_rolling = false
		_to_main_menu()


func _to_main_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var path := main_menu_path if main_menu_path != "" else MAIN_MENU_SCENE
	if not ResourceLoader.exists(path):
		path = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if path != "" and ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		get_tree().reload_current_scene()
