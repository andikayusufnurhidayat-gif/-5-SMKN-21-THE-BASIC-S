extends Camera3D

@export var mouse_sensitivity := 0.0008
@export var key_look_speed := 2.0
@export var max_pitch := 80.0

func _ready() -> void:
	current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel = event.relative.limit_length(40.0)  # batasi loncatan touchpad
		var sens: float = mouse_sensitivity * _sens_multiplier()  # dari menu Options
		get_parent().rotate_y(-rel.x * sens)  # badan Player nengok kiri-kanan
		rotation.x = clamp(rotation.x - rel.y * sens, deg_to_rad(-max_pitch), deg_to_rad(max_pitch))

func _process(delta: float) -> void:
	# nengok pakai tombol panah (enak untuk touchpad)
	if Input.is_key_pressed(KEY_LEFT):  get_parent().rotate_y(key_look_speed * delta)
	if Input.is_key_pressed(KEY_RIGHT): get_parent().rotate_y(-key_look_speed * delta)
	if Input.is_key_pressed(KEY_UP):    rotation.x += key_look_speed * delta
	if Input.is_key_pressed(KEY_DOWN):  rotation.x -= key_look_speed * delta
	rotation.x = clamp(rotation.x, deg_to_rad(-max_pitch), deg_to_rad(max_pitch))


func _sens_multiplier() -> float:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and "mouse_sens" in am:
		return am.mouse_sens
	return 1.0
