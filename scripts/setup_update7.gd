@tool
extends EditorScript
## PEMASANG OTOMATIS. Buka lantai 1.tscn di editor, buka script ini di Script Editor,
## lalu File > Run (Ctrl+Shift+X). Dia menambah ke scene yang lagi dibuka:
##   Jennifer (teacher.gd), SchoolGate (school_gate.gd), GameFlow (game_flow.gd), KeyPoint1..3 (Marker3D).
## Aman dijalankan ulang: node yang sudah ada dilewati. Setelah itu: SIMPAN scene (Ctrl+S).

func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("Setup Update7: buka lantai 1.tscn dulu.")
		return

	var player_pos := Vector3.ZERO
	for n in root.find_children("*", "CharacterBody3D", true, true):
		if n.is_in_group("player"):
			player_pos = (n as Node3D).global_position
			break

	var jen := _add(root, "Jennifer", "CharacterBody3D", "res://scripts/teacher.gd")
	if jen != null:
		(jen as Node3D).position = player_pos + Vector3(0, 0, -6)
	var gate := _add(root, "SchoolGate", "Node3D", "res://scripts/school_gate.gd")
	for i in 3:
		var m := _add(root, "KeyPoint%d" % (i + 1), "Marker3D", "")
		if m != null:
			(m as Node3D).position = player_pos + Vector3(4 * (i + 1), 0, 4)
	var flow := _add(root, "GameFlow", "Node", "res://scripts/game_flow.gd")
	if flow != null:
		var pts: Array[NodePath] = [NodePath("../KeyPoint1"), NodePath("../KeyPoint2"), NodePath("../KeyPoint3")]
		flow.set("key_points", pts)

	print("Setup Update7 selesai. LANJUT MANUAL:")
	print(" 1) Pindahkan SchoolGate ke gerbang depan (sisi dalam sekolah = +Z / panah biru). Gerbang lama jangan dihapus dulu, cocokkan ukurannya (Gate Width).")
	print(" 2) Pindahkan KeyPoint1..3 ke lantai di ruang guru / lab / toilet (kunci gerbang muncul di salah satunya).")
	print(" 3) Jennifer sudah ditaruh 6 m di dekat player, geser kalau perlu. Simpan scene (Ctrl+S).")


func _add(root: Node, node_name: String, cls: String, script_path: String) -> Node:
	if root.has_node(node_name):
		print("Dilewati (sudah ada): ", node_name)
		return null
	var n := ClassDB.instantiate(cls) as Node
	n.name = node_name
	if script_path != "":
		n.set_script(load(script_path))
	root.add_child(n)
	n.owner = root
	return n
