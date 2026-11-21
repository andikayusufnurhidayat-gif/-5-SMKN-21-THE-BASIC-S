extends CharacterBody3D

@export var speed := 5.0
@export var sprint_speed := 10.0
@export var max_step_height := 0.3

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var stamina: Stamina = get_node_or_null("Stamina") as Stamina

## Pengali kecepatan sementara (dipakai Es Teh). 1.0 = normal.
var speed_multiplier := 1.0
var _boost_tween: Tween

func _ready():
	add_to_group("player")
	print("NEW FOLDER PLAYER JALAN")


## Dipanggil Stamina saat Es Teh diminum: kecepatan dikali multiplier selama seconds detik.
func apply_speed_boost(multiplier: float, seconds: float) -> void:
	if _boost_tween != null:
		_boost_tween.kill()
	speed_multiplier = multiplier
	_boost_tween = create_tween()
	_boost_tween.tween_interval(seconds)
	_boost_tween.tween_callback(func(): speed_multiplier = 1.0)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var wants_sprint := Input.is_key_pressed(KEY_SHIFT)
	var sprinting := wants_sprint
	if stamina:
		sprinting = stamina.process_sprint(delta, wants_sprint, direction != Vector3.ZERO)
	var current_speed = (sprint_speed if sprinting else speed) * speed_multiplier

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	_try_step_up(delta)
	move_and_slide()

func _try_step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length() < 0.01:
		return
	var motion := horizontal.normalized() * maxf(horizontal.length() * delta, 0.1)
	if not test_move(global_transform, motion):
		return
	var up := Vector3.UP * max_step_height
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, motion):
		return
	var ahead := raised.translated(motion)
	var col := KinematicCollision3D.new()
	if not test_move(ahead, -up, col):
		return
	if col.get_normal().y < cos(floor_max_angle):
		return
	var step_height := max_step_height - col.get_travel().length()
	if step_height > 0.005:
		global_position.y += step_height + 0.01
