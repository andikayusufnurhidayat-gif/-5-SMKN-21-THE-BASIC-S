extends Node3D

# Node teratas yang collision-nya pakai kotak sederhana per mesh (lebih ringan):
# pagar (Scene4-19), pohon (25-31), tanaman (24, 37, 38)
const BOX_SCENES := [24, 25, 26, 27, 28, 29, 30, 31, 37, 38]

func _ready():
	for m in find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if mesh.mesh == null or _skip(mesh):
			continue
		if _use_box(_top_node(mesh)):
			_add_box(mesh)
		else:
			_add_trimesh(mesh)

func _top_node(n: Node) -> Node:
	while n.get_parent() != self:
		n = n.get_parent()
	return n

func _use_box(top: Node) -> bool:
	var s := str(top.name)
	if not s.begins_with("Sketchfab_Scene"):
		return false
	var num := s.trim_prefix("Sketchfab_Scene").to_int()
	return (num >= 4 and num <= 19) or num in BOX_SCENES

func _skip(mesh: Node) -> bool:
	# lewati mesh milik Player / body lain, dan yang sudah punya collision
	var p := mesh.get_parent()
	while p != null and p != self:
		if p is CollisionObject3D:
			return true
		p = p.get_parent()
	for c in mesh.get_children():
		if c is StaticBody3D:
			return true
	return false

func _add_trimesh(mesh: MeshInstance3D):
	mesh.create_trimesh_collision()
	# dinding tipis: aktifkan collision dari dua sisi
	for c in mesh.get_children():
		if c is StaticBody3D:
			for s in c.get_children():
				if s is CollisionShape3D and s.shape is ConcavePolygonShape3D:
					s.shape.backface_collision = true

func _add_box(mesh: MeshInstance3D):
	var aabb := mesh.get_aabb()
	if aabb.size.length() < 0.001:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	cs.shape = box
	cs.position = aabb.get_center()
	body.add_child(cs)
	mesh.add_child(body)
