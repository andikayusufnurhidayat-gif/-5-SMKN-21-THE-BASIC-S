extends Node
## Alat bantu sementara: rekam titik spawn item dengan jalan-jalan di game.
##
## Cara pakai: pasang node ini di scene lantai 1 (namai SpawnRecorder), jalankan game (F6),
## jalan ke tempat yang boleh jadi lokasi item, lalu tekan:
##   N          = simpan titik di bawah kaki player
##   Backspace  = hapus titik yang terakhir disimpan
## Titik disimpan ke res://spawn_points.json dan ditambahkan ke yang sudah ada.
## Setelah selesai merekam, hapus node ini dari scene.

const SAVE_PATH := "res://spawn_points.json"

var _points: Array = []  # tiap elemen: [x, y, z]


func _ready() -> void:
	_load()
	print("SpawnRecorder: %d titik sudah tersimpan. Tekan N buat nambah, Backspace buat hapus terakhir." % _points.size())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_N:
		_add_point()
	elif event.keycode == KEY_BACKSPACE:
		_remove_last()


func _add_point() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		push_warning("SpawnRecorder: player nggak ketemu (group 'player').")
		return

	# Tembak sinar ke bawah dari sedikit di atas player, supaya dapat titik permukaan yang dipijak.
	var pos := player.global_position
	var from := pos + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		pos = hit["position"]

	_points.append([snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)])
	_save()
	GameState.notice.emit("Titik spawn #%d disimpan" % _points.size())


func _remove_last() -> void:
	if _points.is_empty():
		return
	_points.pop_back()
	_save()
	GameState.notice.emit("Titik terakhir dihapus (sisa %d)" % _points.size())


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Array:
		_points = parsed


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SpawnRecorder: gagal menulis %s (kode error %d)." % [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(_points))
	file.close()
