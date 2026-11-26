extends CanvasLayer
## HUD: kotak inventory 3 slot di kanan atas + bar stamina di bawah tengah.
## Seluruh UI dibuat lewat kode, jadi scene-nya cukup satu CanvasLayer kosong.

@export_group("Warna")
@export var panel_color := Color("2f9e44")
@export var panel_border := Color("1b5e28")
@export var slot_color := Color("e9f5e1")
@export var slot_selected_border := Color("ffd43b")
@export var stamina_color := Color("63e06b")
@export var stamina_low_color := Color("e03131")

const SLOT_SIZE := 64

var _slot_panels: Array[PanelContainer] = []
var _slot_fallbacks: Array[ColorRect] = []
var _slot_letters: Array[Label] = []
var _slot_icons: Array[TextureRect] = []
var _item_name: Label
var _notice: Label
var _stamina_bar: ProgressBar
var _stamina_fill: StyleBoxFlat
var _bar_visible := false
var _bar_tween: Tween
var _notice_tween: Tween
var _icons: ItemIcons


func _ready() -> void:
	layer = 10

	# Satu wadah seukuran layar; tiap elemen menempel ke pojoknya lewat size flags.
	var wrapper := MarginContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		wrapper.add_theme_constant_override("margin_" + side, 16)
	add_child(wrapper)

	_icons = ItemIcons.new()
	add_child(_icons)
	_build_inventory(wrapper)
	_build_stamina(wrapper)
	_build_notice(wrapper)

	GameState.inventory_changed.connect(_refresh_slots)
	GameState.selected_changed.connect(_on_selected_changed)
	GameState.stamina_changed.connect(_on_stamina_changed)
	GameState.notice.connect(_show_notice)
	_refresh_slots()


# ---------------------------------------------------------------- inventory

func _build_inventory(parent: Control) -> void:
	var holder := VBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_END
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	holder.add_theme_constant_override("separation", 4)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(panel_color, panel_border, 3, 14))
	holder.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	for i in GameState.MAX_SLOT_COUNT:
		row.add_child(_make_slot(i))

	# Nama item terpilih, tampil di bawah kotak.
	_item_name = Label.new()
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name.add_theme_font_size_override("font_size", 18)
	_item_name.add_theme_color_override("font_color", Color.WHITE)
	_item_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_item_name.add_theme_constant_override("outline_size", 6)
	holder.add_child(_item_name)

	parent.add_child(holder)


func _make_slot(index: int) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _box(slot_color, panel_border, 3, 10))

	var inner := MarginContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 6)
	slot.add_child(inner)

	# Dipakai kalau item belum punya gambar: kotak warna + huruf pertama nama item.
	var fallback := ColorRect.new()
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback.visible = false
	inner.add_child(fallback)

	var letter := Label.new()
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 26)
	letter.add_theme_color_override("font_color", Color.WHITE)
	letter.add_theme_color_override("font_outline_color", Color.BLACK)
	letter.add_theme_constant_override("outline_size", 6)
	fallback.add_child(letter)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.visible = false
	inner.add_child(icon)

	# Angka kecil di pojok kiri atas (petunjuk tombol 1/2/3).
	var hint := Label.new()
	hint.text = str(index + 1)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0, 0, 0, 0.6))
	inner.add_child(hint)

	_slot_panels.append(slot)
	_slot_fallbacks.append(fallback)
	_slot_letters.append(letter)
	_slot_icons.append(icon)
	return slot


func _refresh_slots() -> void:
	for i in GameState.MAX_SLOT_COUNT:
		_slot_panels[i].visible = i < GameState.slot_count  # slot ke-4 baru muncul setelah ambil Tas Ransel
		var id: String = GameState.slots[i]
		_slot_icons[i].visible = false
		_slot_fallbacks[i].visible = false
		if id == "":
			continue
		var data: Dictionary = GameState.ITEMS[id]
		var icon_path: String = data.get("icon", "")
		var model_path: String = data.get("model", "")
		if icon_path != "" and ResourceLoader.exists(icon_path):
			_slot_icons[i].texture = load(icon_path)
			_slot_icons[i].visible = true
		elif model_path != "" and ResourceLoader.exists(model_path) and _icons.get_icon(model_path) != null:
			_slot_icons[i].texture = _icons.get_icon(model_path)
			_slot_icons[i].visible = true
		else:
			_slot_fallbacks[i].color = data.get("color", Color.GRAY)
			var item_name: String = data.get("name", "?")
			_slot_letters[i].text = item_name.left(1).to_upper()
			_slot_fallbacks[i].visible = true
	_update_selection()


func _on_selected_changed(_index: int) -> void:
	_update_selection()


func _update_selection() -> void:
	for i in _slot_panels.size():
		var selected := i == GameState.selected_slot
		var border := slot_selected_border if selected else panel_border
		var width := 5 if selected else 3
		_slot_panels[i].add_theme_stylebox_override("panel", _box(slot_color, border, width, 10))

	var id: String = GameState.slots[GameState.selected_slot]
	if id == "":
		_item_name.text = ""
	else:
		var data: Dictionary = GameState.ITEMS[id]
		_item_name.text = data.get("name", "")


# ------------------------------------------------------------------ stamina

func _build_stamina(parent: Control) -> void:
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(280, 14)
	_stamina_bar.show_percentage = false
	_stamina_bar.min_value = 0.0
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_END
	_stamina_bar.modulate.a = 0.0  # sembunyi saat stamina penuh
	_stamina_bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.55), panel_border, 2, 7))
	_stamina_fill = _box(stamina_color, Color(0, 0, 0, 0), 0, 7)
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill)
	parent.add_child(_stamina_bar)


func _on_stamina_changed(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value
	var ratio := (value / max_value) if max_value > 0.0 else 0.0
	_stamina_fill.bg_color = stamina_low_color if ratio < 0.25 else stamina_color

	var should_show := ratio < 0.999
	if should_show != _bar_visible:
		_bar_visible = should_show
		if _bar_tween:
			_bar_tween.kill()
		_bar_tween = create_tween()
		_bar_tween.tween_property(_stamina_bar, "modulate:a", 1.0 if should_show else 0.0, 0.25)


# ------------------------------------------------------------------- notice

func _build_notice(parent: Control) -> void:
	_notice = Label.new()
	_notice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_notice.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_notice.add_theme_font_size_override("font_size", 22)
	_notice.add_theme_color_override("font_color", Color.WHITE)
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 8)
	_notice.modulate.a = 0.0
	parent.add_child(_notice)


func _show_notice(text: String) -> void:
	_notice.text = text
	if _notice_tween:
		_notice_tween.kill()
	_notice.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(1.5)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.4)


# ------------------------------------------------------------------- helper

func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	return s
