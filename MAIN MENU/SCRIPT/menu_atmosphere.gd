extends Control
## Latar belakang "hidup" untuk main menu & credits (tanpa butuh gambar):
## gradasi gelap, kabut yang bergerak pelan, debu melayang, cahaya senter yang mengikuti mouse, dan vignette.
## Juga berisi helper gaya tombol (static) yang dipakai menu & credits.

const BONE := Color(0.93, 0.91, 0.86)
const BLOOD := Color(0.62, 0.07, 0.09)
const BLOOD_BRIGHT := Color(0.92, 0.18, 0.18)

## Cahaya senter ngikutin mouse (di credits dimatikan, cahayanya melayang sendiri).
@export var follow_mouse := true

var _t := 0.0
var _fog: Array[TextureRect] = []
var _glow: TextureRect
var _glow_pos := Vector2.ZERO
var _dust: CPUParticles2D
var _effects := true


# ------------------------------------------------------------------ helper static

static func radial(inner: Color, outer: Color, from: Vector2, to: Vector2, inner_at := 0.0) -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([inner, outer])
	g.offsets = PackedFloat32Array([inner_at, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = from
	t.fill_to = to
	t.width = 512
	t.height = 512
	return t


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


static func box(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_w
	s.content_margin_left = 26
	s.content_margin_right = 20
	s.content_margin_top = 11
	s.content_margin_bottom = 11
	s.set_corner_radius_all(2)
	return s


## Gaya tombol horor: gelap, garis merah di kiri, hover/focus jadi merah + tanda panah.
static func style_button(b: Button, primary := false, font_size := 26, arrow := true) -> void:
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.82, 0.8, 0.76))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.8, 0.8))
	var normal := box(Color(0, 0, 0, 0.38), BLOOD if primary else Color(0.3, 0.06, 0.08), 3)
	var hover := box(Color(0.38, 0.04, 0.07, 0.8), BLOOD_BRIGHT, 7)
	var pressed := box(Color(0.22, 0.02, 0.04, 0.9), BLOOD_BRIGHT, 7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	if arrow:
		var base := b.text
		b.focus_entered.connect(func(): b.text = "›  " + base)
		b.focus_exited.connect(func(): b.text = base)
	b.mouse_entered.connect(b.grab_focus)


# ------------------------------------------------------------------ build

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Dipakai sebagai scene (atmosphere.tscn): node sudah ada, tinggal diambil.
	# Dipakai lewat kode (Atmosphere.new(), mis. di credits): node dibuat oleh _build().
	if get_child_count() > 0:
		_bind()
	else:
		_build()
	resized.connect(_layout)
	_layout()


func _noise_fog(seed_value: int, tint: Color, freq: float) -> TextureRect:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	n.seed = seed_value
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(tint, 0.0), Color(tint, 0.6)])
	ramp.offsets = PackedFloat32Array([0.42, 0.9])
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.color_ramp = ramp
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build() -> void:
	# 1) dasar gelap kemerahan
	var base := TextureRect.new()
	base.texture = radial(Color(0.17, 0.03, 0.05), Color(0.012, 0.008, 0.02), Vector2(0.3, 0.5), Vector2(1.0, 1.0))
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 2) kabut dua lapis (dingin & kemerahan), bergerak pelan
	var f1 := _noise_fog(11, Color(0.62, 0.68, 0.85), 0.006)
	f1.modulate.a = 0.55
	add_child(f1)
	_fog.append(f1)
	var f2 := _noise_fog(73, Color(0.85, 0.4, 0.45), 0.009)
	f2.modulate.a = 0.4
	add_child(f2)
	_fog.append(f2)

	# 3) debu melayang
	_dust = CPUParticles2D.new()
	_dust.amount = 80
	_dust.lifetime = 14.0
	_dust.preprocess = 14.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(600, 340)
	_dust.direction = Vector2(0.3, -1.0)
	_dust.spread = 30.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 5.0
	_dust.initial_velocity_max = 18.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.8
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 0.92, 0.92, 0.0), Color(1, 0.92, 0.92, 0.24), Color(1, 0.92, 0.92, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_dust.color_ramp = ramp
	add_child(_dust)

	# 4) cahaya senter hangat (additive)
	_glow = TextureRect.new()
	_glow.texture = radial(Color(1.0, 0.45, 0.3, 0.26), Color(1.0, 0.45, 0.3, 0.0), Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.size = Vector2(1000, 1000)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = additive()
	add_child(_glow)

	# 5) vignette
	var vig := TextureRect.new()
	vig.texture = radial(Color(0, 0, 0, 0), Color(0, 0, 0, 0.93), Vector2(0.5, 0.5), Vector2(1.0, 0.5), 0.42)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_glow_pos = size * 0.5
	_apply_saved_effects()


## Versi scene: ambil node yang sudah dibuat di atmosphere.tscn.
func _bind() -> void:
	_fog.clear()
	_fog.append($Fog1 as TextureRect)
	_fog.append($Fog2 as TextureRect)
	_dust = $Dust
	_glow = $Glow
	_glow_pos = size * 0.5
	_apply_saved_effects()


# Opsi "Efek Menu" (kabut & debu) dibaca dari AudioManager; mati = lebih ringan buat laptop spek rendah.
func _apply_saved_effects() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and "menu_effects" in am:
		set_effects(am.menu_effects)


## Nyalakan / matikan kabut & debu (bagian yang paling "berat"). Senter & vignette tetap ada.
func set_effects(on: bool) -> void:
	_effects = on
	for f in _fog:
		f.visible = on
	if _dust != null:
		_dust.visible = on
		_dust.emitting = on


func _layout() -> void:
	if _dust == null:
		return
	_dust.position = size * 0.5
	_dust.emission_rect_extents = size * 0.5
	for f in _fog:
		f.size = size * 1.5


func _process(delta: float) -> void:
	_t += delta
	# kabut bergeser pelan bolak-balik
	for i in (_fog.size() if _effects else 0):
		var k := float(i + 1)
		_fog[i].position = Vector2(
			-size.x * 0.25 + sin(_t * 0.05 * k + k * 2.0) * size.x * 0.2,
			-size.y * 0.25 + cos(_t * 0.035 * k + k) * size.y * 0.15
		)
	# senter: ikut mouse (menu) atau melayang sendiri (credits)
	var target := size * 0.5 + Vector2(sin(_t * 0.4) * size.x * 0.2, cos(_t * 0.31) * size.y * 0.15)
	if follow_mouse and Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		target = get_local_mouse_position()
	_glow_pos = _glow_pos.lerp(target, 1.0 - exp(-3.5 * delta))
	_glow.position = _glow_pos - _glow.size * 0.5
	_glow.modulate.a = 0.85 + 0.15 * sin(_t * 7.0) * sin(_t * 2.3)
