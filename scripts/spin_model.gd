extends Node3D
## Memutar node ini pelan-pelan (dipakai model item yang mau berputar).
@export var speed := 1.6
func _process(delta: float) -> void:
	rotation.y += speed * delta
