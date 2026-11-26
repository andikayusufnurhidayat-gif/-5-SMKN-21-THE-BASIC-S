extends Node3D
## Benda yang lagi dilempar (baking soda, penghapus papan tulis). Dibuat oleh item_effects.gd.
## Terbang melengkung (kena gravitasi), berputar, lalu saat menabrak sesuatu (lantai, dinding, Jennifer)
## memanggil callback on_land(item_id, posisi, normal, yang_ditabrak) dan menghilang.

const GRAVITY := 16.0
const MAX_AGE := 6.0

var _velocity := Vector3.ZERO
var _item_id := ""
var _on_land := Callable()
var _model: Node3D
var _age := 0.0
var _exclude: Array[RID] = []


func setup(item_id: String, data: Dictionary, start: Vector3, velocity: Vector3, on_land: Callable) -> void:
	_item_id = item_id
	_velocity = velocity
	_on_land = on_land
	global_position = start
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		_exclude.append((player as CollisionObject3D).get_rid())
	_model = _build_model(data)
	add_child(_model)


func _build_model(data: Dictionary) -> Node3D:
	var node: Node3D = null
	var path: String = data.get("model", "")
	if path != "" and ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			node = packed.instantiate() as Node3D
	if node == null:
		var mesh_instance := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		mesh_instance.mesh = sphere
		node = mesh_instance
	node.scale = Vector3.ONE * float(data.get("scale", 1.0))
	return node


func _physics_process(delta: float) -> void:
	if _model == null:
		return
	_age += delta
	_velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		if _on_land.is_valid():
			_on_land.call(_item_id, global_position, hit["normal"], hit["collider"])
		queue_free()
		return
	global_position = to
	_model.rotate_x(delta * 9.0)
	if _age > MAX_AGE:
		queue_free()
