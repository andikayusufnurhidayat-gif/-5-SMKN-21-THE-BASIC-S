extends Camera3D

@export var mouse_sensitivity := 0.02
@export var key_look_speed := 2.0
@export var max_pitch := 80.0


func _ready() -> void:
	current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel = event.relative.limit_length(40.0)  # batasi loncatan touchpad
		get_parent().rotate_y(-rel.x * mouse_sensitivity)  # badan Player nengok kiri-kanan
		rotation.x = clamp(rotation.x - rel.y * mouse_sensitivity, deg_to_rad(-max_pitch), deg_to_rad(max_pitch))
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	# nengok pakai tombol panah (enak untuk touchpad)
	if Input.is_key_pressed(KEY_LEFT):  get_parent().rotate_y(key_look_speed * delta)
	if Input.is_key_pressed(KEY_RIGHT): get_parent().rotate_y(-key_look_speed * delta)
	if Input.is_key_pressed(KEY_UP):    rotation.x += key_look_speed * delta
	if Input.is_key_pressed(KEY_DOWN):  rotation.x -= key_look_speed * delta
	rotation.x = clamp(rotation.x, deg_to_rad(-max_pitch), deg_to_rad(max_pitch))
