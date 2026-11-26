class_name ItemIcons
extends Node
## Membuat ikon 2D otomatis dari model 3D (.glb) item, dipakai oleh hud.gd.
## Jadi nggak perlu bikin gambar PNG manual: modelnya dirender kecil dengan latar transparan.

const ICON_SIZE := 128

var _cache: Dictionary = {}  # path model -> Texture2D


func get_icon(model_path: String) -> Texture2D:
	if _cache.has(model_path):
		return _cache[model_path]
	var texture := _build_icon(model_path)
	_cache[model_path] = texture
	return texture


func _build_icon(model_path: String) -> Texture2D:
	var packed := load(model_path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	if model == null:
		return null

	var box := _model_aabb(model)
	var center := box.get_center()
	var diagonal := box.size.length()
	if diagonal <= 0.0:
		diagonal = 1.0

	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	viewport.add_child(model)

	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	light.rotation_degrees = Vector3(-40.0, -35.0, 0.0)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.7

	var camera := Camera3D.new()
	camera.environment = env
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = diagonal * 1.05
	var distance := diagonal * 3.0
	camera.near = distance * 0.02
	camera.far = distance * 3.0
	viewport.add_child(camera)

	var view_dir := Vector3(0.6, 0.5, 1.0).normalized()
	camera.look_at_from_position(center + view_dir * distance, center, Vector3.UP)
	camera.make_current()

	return viewport.get_texture()


# Menghitung kotak pembatas gabungan semua mesh di dalam model.
func _model_aabb(root: Node3D) -> AABB:
	var stack: Array = [[root, Transform3D.IDENTITY]]
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
				var box: AABB = xf * mesh_instance.mesh.get_aabb()
				if has_any:
					merged = merged.merge(box)
				else:
					merged = box
					has_any = true
		for child in node.get_children():
			stack.append([child, xf])
	return merged
