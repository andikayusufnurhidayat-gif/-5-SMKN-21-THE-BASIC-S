@tool
extends Node3D
## Loker buatan sendiri, dibuat lewat kode (seperti mesin kantin). Muncul langsung di editor.
##
## Titik asal = tengah bawah (lantai). Bagian DEPAN menghadap sumbu +Z (panah biru): putar node di sumbu Y
## supaya pintunya menghadap ke ruangan. Taruh tepat di tinggi lantai.
## Terkunci sampai dibuka pakai Kunci Loker: hadap loker dari dekat, pilih kuncinya di slot, klik kanan.
## Isinya (Reward Items) muncul melayang di depan loker.

@export var locker_width := 0.55:
	set(value):
		locker_width = value
		_refresh()
@export var locker_height := 1.8:
	set(value):
		locker_height = value
		_refresh()
@export var locker_depth := 0.5:
	set(value):
		locker_depth = value
		_refresh()
@export var body_color := Color("3b6ea5"):
	set(value):
		body_color = value
		_refresh()
## Id item (lihat katalog di game_state.gd) yang keluar saat loker dibuka.
@export var reward_items: PackedStringArray = ["koin", "koin", "peluit"]
## Jarak maksimal kamera pemain ke depan loker supaya kunci bisa dipakai.
@export var use_distance := 3.0

var opened := false
var _root: Node3D
var _door: Node3D


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("locker")


## Dipanggil kalau loker diklik kiri (kalau script pemain memanggilnya).
func interact() -> void:
	GameState.notice.emit("The locker is empty" if opened else "The locker is locked. You need a Locker Key.")


## True kalau kamera pemain cukup dekat, menghadap loker, dan berada di sisi depannya.
func can_use(cam: Camera3D) -> bool:
	if cam == null or _root == null:
		return false
	var front := global_transform * Vector3(0.0, locker_height * 0.5, locker_depth * 0.5)
	var to_locker := front - cam.global_position
	var dist := to_locker.length()
	if dist > use_distance:
		return false
	if dist < 0.01:
		return true
	var look_dir := -cam.global_transform.basis.z
	if look_dir.dot(to_locker / dist) < 0.5:
		return false
	return (cam.global_position - global_position).dot(global_transform.basis.z) > 0.0


## Dipanggil item_effects.gd saat kunci dipakai: pintu terbuka lalu isinya muncul.
func open() -> void:
	if opened or _door == null:
		return
	opened = true
	var tween := create_tween()
	tween.tween_property(_door, "rotation:y", deg_to_rad(-110.0), 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_spawn_rewards)


func _spawn_rewards() -> void:
	var spawner := get_tree().get_first_node_in_group("item_spawner")
	if spawner == null or not spawner.has_method("spawn_item_at"):
		push_warning("Locker: ItemSpawner nggak ketemu, isi loker nggak bisa dimunculkan.")
		return
	var count := reward_items.size()
	for i in count:
		var offset := (i - (count - 1) * 0.5) * 0.35
		var pos := global_transform * Vector3(offset, 0.0, locker_depth * 0.5 + 0.5)
		spawner.call("spawn_item_at", reward_items[i], pos)


func _refresh() -> void:
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Built"
	add_child(_root)

	var w := locker_width
	var h := locker_height
	var d := locker_depth
	var zf := d * 0.5

	var body := _mat(body_color, 0.3, 0.5)
	var door_mat := _mat(body_color.lightened(0.12), 0.3, 0.45)
	var dark := _mat(Color(0.08, 0.09, 0.11), 0.2, 0.7)
	var metal := _mat(Color(0.75, 0.77, 0.8), 0.9, 0.3)

	# Badan dan bidang gelap di balik pintu (kelihatan kalau pintu terbuka).
	_add_box(_root, Vector3(w, h, d), Vector3(0, h * 0.5, 0), body)
	_add_box(_root, Vector3(w * 0.9, h * 0.94, 0.02), Vector3(0, h * 0.5, zf + 0.005), dark)

	# Pintu: engsel di sisi kiri, berputar di sumbu Y.
	_door = Node3D.new()
	_door.name = "DoorPivot"
	_door.position = Vector3(-w * 0.5 + 0.01, 0.0, zf + 0.025)
	_root.add_child(_door)
	_add_box(_door, Vector3(w * 0.97, h * 0.96, 0.03), Vector3(w * 0.485, h * 0.5, 0), door_mat)
	for i in 3:
		_add_box(_door, Vector3(w * 0.6, 0.02, 0.012), Vector3(w * 0.485, h * 0.88 - i * 0.05, 0.02), dark)
	_add_box(_door, Vector3(0.03, 0.14, 0.04), Vector3(w * 0.88, h * 0.5, 0.03), metal)
	if opened:
		_door.rotation.y = deg_to_rad(-110.0)

	# Fisika cuma dibuat saat game jalan.
	if Engine.is_editor_hint():
		return
	var body_node := StaticBody3D.new()
	body_node.name = "Body"
	body_node.position = Vector3(0, h * 0.5, 0)
	_root.add_child(body_node)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, d)
	shape.shape = box
	body_node.add_child(shape)


func _mat(color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
