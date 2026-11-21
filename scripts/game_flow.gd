extends Node
## Pengatur alur game ala Baldi's Basics. Satu node ini di lantai 1.tscn (namai GameFlow).
##
## Alur:
##  1. Game mulai: Jennifer melambai dan menyapa (subtitle di bawah layar). Potongan kunci muncul di tiap KeyPoint.
##  2. Tiap buku diambil: layar soal (QuizUI). Jawaban salah bikin Jennifer makin cepat. Dia mulai ngejar setelah buku pertama.
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
@export var use_quiz_ui := true    ## false = papan soal buatan script ini dimatikan (kalau kamu pakai sistem soal sendiri)
@export var restart_delay := 3.5
@export var intro_line_seconds := 2.8
@export var intro_lines: PackedStringArray = [
	"Halo, anak-anak! Ibu Jennifer di sini.",
	"Kumpulkan 7 buku dan jawab soalnya dengan benar.",
	"Selesai? Kamu boleh pulang. Selamat belajar!",
]
@export_group("Sembunyi")
## Otomatis jadikan meja kelas (yang terdeteksi ItemSpawner) sebagai tempat sembunyi kolong meja. Nggak perlu aset/pasang manual.
@export var auto_desk_hiding := true          ## SEMUA meja kelas yang terdeteksi jadi tempat sembunyi
@export var auto_cabinets := true              ## lemari otomatis dipasang menempel dinding tiap ruangan
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

const KEY_PIECE := preload("res://scripts/key_piece.gd")
const HIDING_SPOT := preload("res://scripts/hiding_spot.gd")
const JUMPSCARE := preload("res://scripts/jumpscare.gd")
const MAIN_MENU_SCENE := "res://MAIN MENU/SCENE/MainMenu.tscn"
const CREDITS_SCENE := "res://MAIN MENU/SCENE/credits.tscn"

var _jennifer: Node
var _spawner: Node
var _initial := 0
var _collected := 0
var _pending := 0
var _quiz_no := 0
var _quiz_open := false
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
	await get_tree().create_timer(0.6).timeout   # tunggu ItemSpawner selesai menyebar
	_jennifer = get_node_or_null(jennifer_path)
	if _jennifer == null:
		_jennifer = get_tree().get_first_node_in_group("teacher")
	_spawner = get_node_or_null(spawner_path)
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("item_spawner")
	if _jennifer == null:
		push_warning("GameFlow: node Jennifer (group 'teacher') belum ada.")
	_spawn_pieces()
	if use_music_director and ResourceLoader.exists("res://scripts/music_director.gd"):
		var md := Node.new()
		md.name = "MusicDirector"
		md.set_script(load("res://scripts/music_director.gd"))
		add_child(md)
	_intro()
	if auto_desk_hiding or auto_cabinets:
		await get_tree().physics_frame
		_spawn_hiding_spots()


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
	GameState.notice.emit("Potongan kunci %d/%d didapat!" % [_pieces_got, _pieces_total])
	if _pieces_got >= _pieces_total:
		_assemble_key()


func _assemble_key() -> void:
	if GameState.add_item(key_item_id):
		GameState.notice.emit("Kunci Gerbang lengkap! Semua buku terkumpul? Ke gerbang, klik kanan.")
		return
	# Inventory penuh: jatuhkan kuncinya di dekat player.
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p != null and _spawner != null:
		_spawner.call("spawn_item_at", key_item_id, p.global_position + Vector3(0, 0, 1.0))
		GameState.notice.emit("Kunci Gerbang lengkap, tapi inventory penuh. Kuncinya jatuh di dekatmu!")


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


func _place_cabinets(space: PhysicsDirectSpaceState3D, box: AABB, floor_y: float) -> int:
	var made := 0
	var center := box.get_center()
	var dirs: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	dirs.shuffle()
	for d in dirs:
		if made >= cabinets_per_room:
			break
		var tangent := d.cross(Vector3.UP).normalized()
		var span := (box.size.z if absf(tangent.z) > 0.5 else box.size.x) * 0.5
		var reach := (box.size.x if absf(d.x) > 0.5 else box.size.z) * 0.5 + 1.0
		for frac in [0.0, -0.3, 0.3, -0.55, 0.55, -0.75, 0.75]:
			var origin: Vector3 = Vector3(center.x, floor_y + 1.2, center.z) + tangent * span * frac
			var hit := _ray(space, origin, origin + d * reach)
			if hit.is_empty():
				continue
			if absf((hit["normal"] as Vector3).y) > 0.3:
				continue   # bukan dinding tegak
			var pos: Vector3 = (hit["position"] as Vector3) - d * 0.5
			pos.y = floor_y
			var fl := _ray(space, pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 1.0)
			if not fl.is_empty():
				pos.y = (fl["position"] as Vector3).y
			var yaw := atan2(-d.x, -d.z)    # depan lemari (+Z) menghadap ke tengah ruangan
			if not _free_box(space, pos + Vector3.UP * 1.1, Vector3(1.3, 2.0, 0.85), yaw):
				continue
			if not _free_box(space, pos - d * 1.5 + Vector3.UP * 0.9, Vector3(0.8, 1.6, 0.8)):
				continue
			_add_spot(0, pos, yaw, 1.5, true)
			made += 1
			break
	return made


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
		_subtitle.text = intro_lines[i]
		_subtitle.visible_ratio = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(panel, "modulate:a", 1.0, 0.3)
		tw.tween_property(_subtitle, "visible_ratio", 1.0, clampf(intro_lines[i].length() * 0.035, 0.6, 1.8))
		if _jennifer != null and _jennifer.has_method("speak"):
			_jennifer.call("speak", "intro%d" % (i + 1))
		await get_tree().create_timer(intro_line_seconds + 1.4).timeout
	create_tween().tween_property(panel, "modulate:a", 0.0, 0.5)
	GameState.notice.emit("Tip: dekati meja atau lemari, tekan [E] untuk bersembunyi")


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
	if _quiz_open or _pending <= 0 or _ended:
		return
	_pending -= 1
	_quiz_no += 1
	if not use_quiz_ui:
		if _quiz_no >= total_books and _pending == 0:
			_all_books()
		return
	_quiz_open = true
	var quiz := QuizUI.open(self, _quiz_no)
	quiz.finished.connect(_on_quiz_finished)


func _on_quiz_finished(_correct: int, wrong: int) -> void:
	_quiz_open = false
	if wrong > 0 and _jennifer != null and _jennifer.has_method("add_anger"):
		_jennifer.call("add_anger", float(wrong))
	elif wrong == 0 and _jennifer != null and _jennifer.has_method("say"):
		_jennifer.call("say", "Bagus... terus kerjakan.", 2.5, "good")
	if _quiz_no >= total_books and _pending == 0:
		_all_books()
	else:
		_try_open_quiz()


func _all_books() -> void:
	_books_done = true
	var left := _pieces_total - _pieces_got
	if left > 0:
		GameState.notice.emit("Semua buku terkumpul! Masih %d potongan kunci. Cari dan ambil, lalu kabur!" % left)
	else:
		GameState.notice.emit("Semua buku terkumpul! Buka gerbang dan kabur!")
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
	GameState.set_process_unhandled_input(true)
	GameState.reset()
	_to_main_menu()   # game over -> kembali ke main menu


func on_escape() -> void:
	_end("KAMU BERHASIL KABUR!\nSampai jumpa besok di sekolah.", Color(0.0, 0.35, 0.1, 0.85), true)


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
	var text := "TERIMA KASIH SUDAH BERMAIN"
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
