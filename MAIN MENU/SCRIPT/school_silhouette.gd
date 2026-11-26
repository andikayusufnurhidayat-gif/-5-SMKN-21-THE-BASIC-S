@tool
extends Control
## Siluet sekolah dilihat dari luar gerbang: gerbang lengkung, pagar, atap-atap bangunan, ring basket, bulan.
## Semua bentuk adalah node Polygon2D di dalam "Shapes" (bisa diedit/digeser di editor).
## Ukuran desain 1000 x 720; script ini hanya menskalakan & menempelkannya ke pojok kanan-bawah.

const DESIGN := Vector2(1000, 720)

@onready var _shapes: Node2D = $Shapes

var _next_flicker := 3.0


func _ready() -> void:
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	if _shapes == null:
		return
	var s := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_shapes.scale = Vector2(s, s)
	_shapes.position = Vector2(size.x - DESIGN.x * s, size.y - DESIGN.y * s)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Sesekali satu jendela berkedip (lampu rusak)
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_next_flicker = randf_range(3.0, 7.0)
		var wins := _shapes.find_children("Window*", "Polygon2D", true, false)
		if not wins.is_empty():
			var w: Node2D = wins.pick_random()
			var tw := create_tween()
			tw.tween_property(w, "modulate:a", 0.1, 0.05)
			tw.tween_property(w, "modulate:a", 1.0, 0.08)
			tw.tween_property(w, "modulate:a", 0.2, 0.05)
			tw.tween_property(w, "modulate:a", 1.0, 0.12)
