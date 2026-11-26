@tool
extends Node2D
## Pagar: batang vertikal + 2 palang horizontal, digambar sekali (ringan). Ada celah untuk gerbang.

@export var length := 1000.0
@export var top := 645.0
@export var bottom := 698.0
@export var spacing := 13.0
@export var gap_from := 410.0
@export var gap_to := 590.0
@export var color := Color(0.22, 0.25, 0.34, 1.0)


func _draw() -> void:
	var x := 0.0
	while x < length:
		if x < gap_from or x > gap_to:
			draw_rect(Rect2(x, top, 3.0, bottom - top), color)
		x += spacing
	for y in [top + 10.0, bottom - 10.0]:
		draw_rect(Rect2(0.0, y, gap_from, 4.0), color)
		draw_rect(Rect2(gap_to, y, length - gap_to, 4.0), color)
