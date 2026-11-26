@tool
extends Node3D
## Mesin kantin buatan sendiri, dibuat lewat kode (nggak butuh file model). Muncul langsung di editor.
##
## Titik asal = tengah bawah (lantai). Bagian DEPAN menghadap sumbu +Z (panah biru) node ini:
## putar node di sumbu Y supaya depannya menghadap ke jalan.
## Taruh node ini tepat di tinggi lantai (Y = Y lantai), bukan melayang atau tenggelam.
## Ukuran disetel lewat Machine Width / Height / Depth di Inspector. Bawaannya setinggi 1,85
## (pemain di game ini setinggi 2,0, jadi mesin sedikit lebih pendek dari pemain).
##
## Cara beli: hadap mesin dari jarak dekat (Use Distance), klik kiri buat ganti pilihan barang
## (tampil di bawah panel koin), lalu pilih koin di slot dan klik kanan. 1 koin = 1 barang.
## Daftar pilihan ada di PRODUCTS (id item dari katalog game_state.gd).

@export var machine_width := 0.95:
	set(value):
		machine_width = value
		_refresh()
@export var machine_height := 1.85:
	set(value):
		machine_height = value
		_refresh()
@export var machine_depth := 0.85:
	set(value):
		machine_depth = value
		_refresh()
@export var body_color := Color("1f7a3a"):
	set(value):
		body_color = value
		_refresh()
@export var accent_color := Color("ffb703"):
	set(value):
		accent_color = value
		_refresh()
@export var sign_text := "KANTIN":
	set(value):
		sign_text = value
		_refresh()
## Jarak maksimal kamera pemain ke depan mesin supaya koin bisa dipakai.
@export var use_distance := 3.5

const PRODUCTS: Array[String] = ["baking_soda", "es_teh"]

## Barang yang akan keluar kalau beli. Diganti dengan klik kiri pada mesin.
var selected_product := "baking_soda"

var _root: Node3D


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("vending_machine")


## Dipanggil saat mesin diklik kiri (kalau script pemain memanggilnya).
func interact() -> void:
	var next := (PRODUCTS.find(selected_product) + 1) % PRODUCTS.size()
	selected_product = PRODUCTS[next]
	_rebuild()
	var item_name: String = GameState.ITEMS.get(selected_product, {}).get("name", selected_product)
	GameState.notice.emit("Vending machine: option %s. Select a coin, then right-click to buy" % item_name)


## True kalau kamera pemain cukup dekat, menghadap mesin, dan berada di sisi depannya.
func can_use(cam: Camera3D) -> bool:
	if cam == null or _root == null:
		return false
	var front := global_transform * Vector3(0.0, machine_height * 0.5, machine_depth * 0.5)
	var to_machine := front - cam.global_position
	var dist := to_machine.length()
	if dist > use_distance:
		return false
	if dist < 0.01:
		return true
	var look_dir := -cam.global_transform.basis.z
	if look_dir.dot(to_machine / dist) < 0.5:
		return false
	return (cam.global_position - global_position).dot(global_transform.basis.z) > 0.0


## Dipanggil GameState saat pembelian berhasil: barang jatuh ke nampan.
func on_purchase() -> void:
	if _root == null:
		return
	var product := _make_product()
	# Pusatkan model dan kecilkan supaya muat di nampan, nggak peduli letak pivot aslinya.
	var box := _merged_aabb(product, Transform3D.IDENTITY)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var fit := 1.0
	if longest > 0.0001:
		fit = machine_height * 0.08 / longest
	product.scale = Vector3.ONE * fit
	product.position = -box.get_center() * fit
	var holder := Node3D.new()
	holder.name = "DroppedProduct"
	holder.add_child(product)
	# Barang jatuh di DEPAN kaca (nggak nembus rak/kaca) lalu mendarat di alas nampan yang menonjol.
	var half_height := box.size.y * fit * 0.5
	var land_y := machine_height * 0.09 + 0.01 + half_height
	holder.position = Vector3(-machine_width * 0.14, machine_height * 0.62, machine_depth * 0.5 + 0.15)
	holder.scale = Vector3.ONE * 0.2
	_root.add_child(holder)
	var tween := create_tween()
	tween.tween_property(holder, "scale", Vector3.ONE, 0.12)
	tween.tween_property(holder, "position:y", land_y, 0.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.tween_callback(holder.queue_free)


# Bentuk barang yang jatuh: model asli item (sama seperti yang ada di lantai), atau kotak warna kalau modelnya nggak ada.
func _make_product() -> Node3D:
	var data: Dictionary = GameState.ITEMS.get(selected_product, {})
	var path: String = data.get("model", "")
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var node := packed.instantiate() as Node3D
			if node != null:
				return node
	var fallback := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.2, 0.08)
	fallback.mesh = box
	fallback.material_override = _mat(data.get("color", Color(0.9, 0.9, 0.8)))
	return fallback


# Skala node supaya sisi terpanjangnya sama dengan target (meter), biar muat di nampan.
func _fit_to_size(node: Node3D, target: float) -> void:
	var box := _merged_aabb(node, Transform3D.IDENTITY)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0001:
		node.scale = Vector3.ONE * (target / longest)


func _merged_aabb(node: Node, xf: Transform3D) -> AABB:
	var result := AABB()
	var found := false
	if node is Node3D:
		xf = xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = xf * (node as MeshInstance3D).mesh.get_aabb()
		found = true
	for child in node.get_children():
		var sub := _merged_aabb(child, xf)
		if sub.size != Vector3.ZERO:
			result = result.merge(sub) if found else sub
			found = true
	return result


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

	var w := machine_width
	var h := machine_height
	var d := machine_depth
	var zf := d * 0.5  # permukaan depan

	var body := _mat(body_color, 0.1, 0.5)
	var dark := _mat(Color(0.1, 0.11, 0.13), 0.2, 0.6)
	var light := _mat(Color(0.82, 0.84, 0.86), 0.3, 0.5)
	var gold := _mat(accent_color, 0.2, 0.5)

	# Badan dan pelat depan gelap.
	_add_box(Vector3(w, h, d), Vector3(0, h * 0.5, 0), body)
	_add_box(Vector3(w * 0.92, h * 0.84, 0.03), Vector3(0, h * 0.5, zf + 0.015), dark)

	# Rak dan produk di balik kaca (3 baris x 4 kolom).
	var window_x := -w * 0.14
	for r in 3:
		var row_y := h * 0.58 + (r - 1) * h * 0.15
		for c in 4:
			var px := window_x + (c - 1.5) * w * 0.13
			var hue := float(r * 4 + c) / 12.0
			_add_box(Vector3(w * 0.09, h * 0.1, 0.05), Vector3(px, row_y, zf + 0.055), _mat(Color.from_hsv(hue, 0.65, 0.9), 0.0, 0.6))
		_add_box(Vector3(w * 0.58, 0.015, 0.07), Vector3(window_x, row_y - h * 0.06, zf + 0.06), light)
	var glass := _mat(Color(0.6, 0.8, 1.0, 0.25), 0.0, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_box(Vector3(w * 0.6, h * 0.5, 0.01), Vector3(window_x, h * 0.58, zf + 0.095), glass)

	# Panel kanan: tombol dan lubang koin.
	var panel_x := w * 0.33
	_add_box(Vector3(w * 0.2, h * 0.38, 0.03), Vector3(panel_x, h * 0.62, zf + 0.045), light)
	for r in 4:
		for c in 2:
			_add_box(Vector3(w * 0.05, h * 0.03, 0.02),
				Vector3(panel_x + (c - 0.5) * w * 0.07, h * 0.72 - r * h * 0.05, zf + 0.07), _mat(Color(0.2, 0.2, 0.25)))
	_add_box(Vector3(w * 0.12, h * 0.03, 0.02), Vector3(panel_x, h * 0.5, zf + 0.06), gold)
	_add_box(Vector3(w * 0.08, h * 0.012, 0.025), Vector3(panel_x, h * 0.5, zf + 0.065), dark)
	_add_label("COIN", Vector3(panel_x, h * 0.455, zf + 0.065), h * 0.03, Color(0.1, 0.1, 0.1))
	_add_label(_choice_text(), Vector3(panel_x, h * 0.405, zf + 0.065), h * 0.028, accent_color)

	# Nampan pengambilan barang.
	_add_box(Vector3(w * 0.6, h * 0.1, 0.06), Vector3(window_x, h * 0.14, zf + 0.03), dark)
	var flap := _mat(Color(0.0, 0.0, 0.0, 0.55))
	flap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_box(Vector3(w * 0.56, h * 0.075, 0.015), Vector3(window_x, h * 0.14, zf + 0.07), flap)
	# Alas nampan yang menonjol ke depan, tempat barang mendarat (dengan dinding samping dan bibir depan).
	var bin_top := h * 0.09 + 0.01
	_add_box(Vector3(w * 0.56, 0.02, 0.26), Vector3(window_x, h * 0.09, zf + 0.13), dark)
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.02, h * 0.06, 0.26),
			Vector3(window_x + side * (w * 0.28 - 0.01), bin_top + h * 0.03, zf + 0.13), dark)
	_add_box(Vector3(w * 0.56, 0.05, 0.02), Vector3(window_x, bin_top + 0.025, zf + 0.25), dark)

	# Papan nama di atas.
	_add_box(Vector3(w * 0.96, h * 0.07, 0.05), Vector3(0, h * 0.945, zf + 0.025), gold)
	_add_label(sign_text, Vector3(0, h * 0.945, zf + 0.055), h * 0.05, Color(0.1, 0.1, 0.1))

	# Fisika cuma dibuat saat game jalan.
	if Engine.is_editor_hint():
		return
	var body_node := StaticBody3D.new()
	body_node.name = "Body"
	body_node.position = Vector3(0, h * 0.5, 0)
	_root.add_child(body_node)
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(w, h, d)
	body_shape.shape = body_box
	body_node.add_child(body_shape)

	# Zona di depan mesin supaya mesin bisa dibidik dan diklik.
	var area := Area3D.new()
	area.name = "UseArea"
	area.position = Vector3(0, h * 0.5, d * 0.5 + 0.6)
	_root.add_child(area)
	var area_shape := CollisionShape3D.new()
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(w + 1.0, h, 1.8)
	area_shape.shape = area_box
	area.add_child(area_shape)


# Tulisan pendek pilihan produk di bawah panel koin.
func _choice_text() -> String:
	match selected_product:
		"baking_soda":
			return "SODA"
		"es_teh":
			return "ICED TEA"
	return selected_product.to_upper()


func _mat(color: Color, metallic := 0.0, roughness := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	_root.add_child(mi)


func _add_label(text: String, pos: Vector3, height_m: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = height_m / 64.0
	label.modulate = color
	label.position = pos
	_root.add_child(label)
