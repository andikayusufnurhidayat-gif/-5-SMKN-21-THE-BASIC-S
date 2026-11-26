class_name PlayerActions
extends Node
## Taruh sebagai child node dari Player (CharacterBody3D), namai "PlayerActions".
##
## LIHAT BELAKANG: tahan "look_back" (Spasi), kamera langsung ke belakang dan terkunci.
##   Lepas tombol = balik ke kamera depan.
##
## INTERAKSI / AMBIL ITEM: tekan "interact" (E). Nggak perlu bidik pas: item yang paling
##   dekat dengan arah pandangan (dalam sudut aim_assist_degrees) dan nggak terhalang dinding
##   akan diambil. Benda yang bisa diinteraksi = Area3D yang punya fungsi interact()
##   (misal pickup_item.gd).

@export var hold_to_look := true          ## true = tahan tombol. false = tekan sekali pindah, tekan lagi balik.
@export var lock_mouse_while_back := true ## true = gerakan mouse diabaikan selama lihat belakang.
@export var interact_distance := 4.0      ## jarak maksimal buat ambil/interaksi.
@export var aim_assist_degrees := 40.0    ## makin besar makin gampang. 180 = arah mana pun.
@export var check_line_of_sight := true   ## true = item di balik dinding nggak bisa diambil.

var _player: CollisionObject3D
var _main_cam: Camera3D
var _rear_cam: Camera3D
var _rear_basis := Basis.IDENTITY
var _looking_back := false


func _ready() -> void:
	process_priority = 100  # jalan belakangan supaya posisi kamera belakang nggak telat
	_player = get_parent() as CollisionObject3D
	_ensure_action("look_back", [_key(KEY_SPACE)])
	_ensure_action("interact", [_mouse(MOUSE_BUTTON_LEFT)])


func _process(_delta: float) -> void:
	var want_back := _looking_back
	if hold_to_look:
		want_back = Input.is_action_pressed("look_back")
	elif Input.is_action_just_pressed("look_back"):
		want_back = not _looking_back

	if want_back and not _looking_back:
		_start_look_back()
	elif not want_back and _looking_back:
		_stop_look_back()

	if _looking_back:
		_follow_position()


func _input(event: InputEvent) -> void:
	# Selama lihat belakang, gerakan mouse dibuang supaya pandangan nggak bisa digeser manual.
	if _looking_back and lock_mouse_while_back and event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()


# ------------------------------------------------------------- lihat belakang

func _start_look_back() -> void:
	_main_cam = get_viewport().get_camera_3d()
	if _main_cam == null:
		return

	# Arah depan sekarang, diratakan (tanpa mendongak/menunduk), lalu dibalik 180 derajat.
	var forward := -_main_cam.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.05 and _player != null:
		forward = -_player.global_basis.z
		forward.y = 0.0
	if forward.length() < 0.001:
		return
	forward = forward.normalized()
	_rear_basis = Basis.looking_at(-forward, Vector3.UP)

	if _rear_cam == null:
		_rear_cam = Camera3D.new()
		_rear_cam.name = "RearCamera"
		add_child(_rear_cam)
	_rear_cam.projection = _main_cam.projection
	_rear_cam.fov = _main_cam.fov
	_rear_cam.size = _main_cam.size
	_rear_cam.near = _main_cam.near
	_rear_cam.far = _main_cam.far
	_rear_cam.keep_aspect = _main_cam.keep_aspect
	_rear_cam.cull_mask = _main_cam.cull_mask
	_rear_cam.environment = _main_cam.environment
	_rear_cam.attributes = _main_cam.attributes

	_follow_position()
	_rear_cam.make_current()
	_looking_back = true


func _stop_look_back() -> void:
	_looking_back = false
	if is_instance_valid(_main_cam):
		_main_cam.make_current()


# Arah kamera belakang tetap (terkunci), posisinya ikut kamera utama.
func _follow_position() -> void:
	if not is_instance_valid(_main_cam):
		_looking_back = false
		return
	_rear_cam.global_transform = Transform3D(_rear_basis, _main_cam.global_position)


# ------------------------------------------------------------------ interaksi

func _interact() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		return
	var target := _find_target(cam)
	if target != null:
		target.call("interact")


# Cari benda interaksi terbaik: dekat, searah pandangan (dengan toleransi), dan tidak terhalang.
func _find_target(cam: Camera3D) -> Node:
	var origin := cam.global_position
	var forward := -cam.global_basis.z.normalized()
	var space := _player.get_world_3d().direct_space_state

	var sphere := SphereShape3D.new()
	sphere.radius = interact_distance
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.exclude = [_player.get_rid()]

	var min_dot := cos(deg_to_rad(aim_assist_degrees))
	var best: Node = null
	var best_score := INF

	for result in space.intersect_shape(params, 32):
		var interactable := _find_interactable(result["collider"] as Node)
		if interactable == null or not (interactable is Node3D):
			continue
		var point := (result["collider"] as Node3D).global_position
		var to_target := point - origin
		var dist := to_target.length()
		if dist < 0.001 or dist > interact_distance:
			continue
		var dot := forward.dot(to_target / dist)
		if dot < min_dot:
			continue
		if check_line_of_sight and _is_blocked(space, origin, point):
			continue
		var score := (1.0 - dot) * 10.0 + dist * 0.1
		if score < best_score:
			best_score = score
			best = interactable
	return best


func _find_interactable(node: Node) -> Node:
	while node != null:
		if node.has_method("interact"):
			return node
		node = node.get_parent()
	return null


func _is_blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	if from.distance_to(to) <= 0.4:
		return false
	var dir := (to - from).normalized()
	var end := to - dir * 0.3 + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(from, end)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_player.get_rid()]
	return not space.intersect_ray(query).is_empty()


# ------------------------------------------------------------------- helper
# Action dibuat otomatis kalau belum ada di Input Map.

func _ensure_action(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for e in events:
		InputMap.action_add_event(action, e)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e
func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e
