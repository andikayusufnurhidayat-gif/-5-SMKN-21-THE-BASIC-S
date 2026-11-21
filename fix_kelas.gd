@tool
extends EditorScript

const T := -0.5

func _run():
	var root = get_scene()
	for n in root.get_children():
		if n.name.begins_with("kelas"):
			n.rotation.x = 0.0
			n.rotation.z = 0.0
			n.position.y = T
			print("fixed ", n.name)
