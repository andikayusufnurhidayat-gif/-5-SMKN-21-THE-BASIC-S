@tool
extends Node3D
## Pintu gerbang sekolah putih (2 daun pagar + gembok; pilar opsional) dibuat lewat kode. Daun gerbang ngayun terbuka pakai Tween.
## Terkunci sampai player memakai item "kunci_gerbang" dari dekat (klik kanan, lihat patch item_effects.gd).
##
## Titik asal = tengah bawah (lantai), di antara dua pilar. Sisi DALAM sekolah = +Z (panah biru), sisi LUAR = -Z.
## Kalau kebalik, putar node ini 180 derajat di sumbu Y. Kalau daun gerbang ngayun ke arah yang salah,
## ubah Swing Sign jadi -1. Pintu kabur (ExitArea) ada di sisi luar; masuk ke sana saat gerbang terbuka = menang.
## Ukuran bisa disetel di Inspector biar pas dengan gerbang di mapmu.

signal opened

@export var gate_width := 6.0:
	set(v):
		gate_width = v
		_refresh()
@export var gate_height := 2.4:
	set(v):
		gate_height = v
		_refresh()
@export var pillar_width := 0.8:
	set(v):
		pillar_width = v
		_refresh()
@export var pillar_height := 3.0:
	set(v):
		pillar_height = v
		_refresh()
@export var use_distance := 4.5
@export var open_angle := 100.0         ## derajat
@export var open_seconds := 1.6
@export var swing_sign := 1.0           ## 1 = ngayun ke sisi dalam (+Z), -1 = ke luar
@export var gate_color := Color(0.93, 0.93, 0.95):
	set(v):
		gate_color = v
		_refresh()

## Bikin 2 pilar sendiri? Mati = pakai gapura yang sudah ada di map (cuma daun pintu + gembok yang dibuat).
@export var build_pillars := false:
	set(v):
		build_pillars = v
		_refresh()

var is_open := false
var _built := false
var _left: Node3D
var _right: Node3D
var _lock: Node3D
var _hint_until := 0.0


func _ready() -> void:
	add_to_group("school_gate")
	_build()


func _refresh() -> void:
	if _built and is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	is_open = false
	_build()


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)


func _build() -> void:
	var half := gate_width * 0.5
	# Pilar kiri dan kanan (opsional, mati kalau pakai gapura yang sudah ada).
	if build_pillars:
		for s in [-1.0, 1.0]:
			var px: float = s * (half + pillar_width * 0.5)
			_box(self, Vector3(pillar_width, pillar_height, pillar_width), Vector3(px, pillar_height * 0.5, 0), gate_color)
			_box(self, Vector3(pillar_width * 1.3, 0.18, pillar_width * 1.3), Vector3(px, pillar_height + 0.09, 0), gate_color)
			_solid(self, Vector3(pillar_width, pillar_height, pillar_width), Vector3(px, pillar_height * 0.5, 0))

	_built = true
	_left = _make_door(-1.0)
	_right = _make_door(1.0)

	# Gembok + tulisan.
	_lock = Node3D.new()
	_lock.position = Vector3(0, gate_height * 0.55, 0.09)
	add_child(_lock)
	_box(_lock, Vector3(0.22, 0.26, 0.1), Vector3.ZERO, Color(0.9, 0.75, 0.15))
	_box(_lock, Vector3(0.1, 0.16, 0.06), Vector3(0, 0.2, 0), Color(0.55, 0.55, 0.6))
	var label := Label3D.new()
	label.text = "LOCKED"
	label.font_size = 50
	label.pixel_size = 0.004
	label.modulate = Color(1, 0.3, 0.3)
	label.position = Vector3(0, 0.55, 0.05)
	_lock.add_child(label)

	# Zona petunjuk (dekat gerbang) dan zona kabur (di luar gerbang).
	var hint := Area3D.new()
	hint.position = Vector3(0, 1.5, 0)
	_area_box(hint, Vector3(gate_width + 2.0, 3.0, 5.0))
	add_child(hint)
	hint.body_entered.connect(_on_hint_entered)

	var exit := Area3D.new()
	exit.name = "ExitArea"
	exit.position = Vector3(0, 1.5, -3.5)
	_area_box(exit, Vector3(gate_width, 3.0, 4.0))
	add_child(exit)
	exit.body_entered.connect(_on_exit_entered)


func _area_box(area: Area3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	area.add_child(cs)


# Satu daun gerbang. side = -1 (engsel kiri) atau 1 (engsel kanan). Daun memanjang ke tengah.
func _make_door(side: float) -> Node3D:
	var half := gate_width * 0.5
	var pivot := Node3D.new()
	pivot.position = Vector3(side * half, 0, 0)
	add_child(pivot)
	var dir := -side
	_box(pivot, Vector3(half, 0.08, 0.06), Vector3(dir * half * 0.5, 0.3, 0), gate_color)
	_box(pivot, Vector3(half, 0.08, 0.06), Vector3(dir * half * 0.5, gate_height - 0.1, 0), gate_color)
	var bars := 8
	for i in bars + 1:
		var x := dir * half * float(i) / float(bars)
		_box(pivot, Vector3(0.05, gate_height, 0.05), Vector3(x, gate_height * 0.5, 0), gate_color)
		_box(pivot, Vector3(0.09, 0.16, 0.09), Vector3(x, gate_height + 0.08, 0), gate_color)  # ujung runcing/tumpul
	_solid(pivot, Vector3(half, gate_height, 0.12), Vector3(dir * half * 0.5, gate_height * 0.5, 0))
	return pivot


# ------------------------------------------------------------------ interaksi

## True kalau kamera pemain cukup dekat dan menghadap gerbang.
func can_use(cam: Camera3D) -> bool:
	if cam == null:
		return false
	var center := global_position + Vector3(0, gate_height * 0.5, 0)
	var to_gate := center - cam.global_position
	var dist := to_gate.length()
	if dist > use_distance:
		return false
	if dist < 0.01:
		return true
	return (-cam.global_transform.basis.z).dot(to_gate / dist) > 0.3


## Dipakai item_effects.gd. Gerbang cuma bisa dibuka kalau semua buku sudah terkumpul. Mengembalikan true kalau terbuka.
func try_open() -> bool:
	if is_open:
		return false
	var flow := get_tree().get_first_node_in_group("game_flow")
	if flow != null and flow.has_method("all_books_collected") and not bool(flow.call("all_books_collected")):
		GameState.notice.emit("The gate cannot be opened yet: collect all the notebooks first!")
		return false
	# Cutscene ending 2 (kabur): game_flow.gd mengambil alih, lalu memanggil open() sendiri di momen yang pas.
	if flow != null and flow.has_method("on_gate_unlock") and bool(flow.call("on_gate_unlock", self)):
		return true
	open()
	return true


func open() -> void:
	if is_open:
		return
	is_open = true
	if _lock != null:
		_lock.queue_free()
	var angle := deg_to_rad(open_angle) * swing_sign
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_left, "rotation:y", -angle, open_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_right, "rotation:y", angle, open_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened.emit()


func _on_hint_entered(body: Node3D) -> void:
	if is_open or not body.is_in_group("player"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _hint_until:
		return
	_hint_until = now + 4.0
	GameState.notice.emit("The gate is locked. Find the Gate Key first!")


func _on_exit_entered(body: Node3D) -> void:
	if is_open and body.is_in_group("player"):
		get_tree().call_group("game_flow", "on_escape")
