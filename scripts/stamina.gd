class_name Stamina
extends Node
## Taruh sebagai child node dari Player (node "Stamina").
## Di script player, panggil process_sprint() tiap frame fisika.
##
## Lamanya diatur dalam DETIK (bukan tergantung kecepatan lari):
##  - lari terus dari stamina penuh habis dalam max_stamina / drain_per_second = sekitar 14 detik
##  - pulih penuh dalam max_stamina / regen_per_second = sekitar 10 detik (setelah jeda regen_delay)

@export var max_stamina := 100.0
@export var drain_per_second := 7.0   ## makin kecil = lari makin lama (dulu 22)
@export var regen_per_second := 10.0  ## makin besar = pulih makin cepat (dulu 14)
@export var regen_delay := 1.5        ## jeda (detik) setelah lari sebelum stamina mulai pulih
@export var min_to_resume := 15.0     ## setelah habis, stamina harus pulih segini baru boleh lari lagi

@export_group("Es Teh")
@export var es_teh_restore := 50.0           ## stamina yang ditambah
@export var es_teh_speed_multiplier := 1.3   ## pengali kecepatan jalan/lari
@export var es_teh_seconds := 8.0            ## lama efek cepat

var value := 100.0
var exhausted := false

var _delay_left := 0.0
var _last_sent := -1.0


func _ready() -> void:
	value = max_stamina
	_ensure_sprint_action()
	GameState.item_used.connect(_on_item_used)
	_send()


## Mengembalikan true kalau player boleh lari di frame ini.
func process_sprint(delta: float, wants_sprint: bool, is_moving: bool) -> bool:
	var sprinting := wants_sprint and is_moving and not exhausted and value > 0.0

	if sprinting:
		value = maxf(value - drain_per_second * delta, 0.0)
		_delay_left = regen_delay
		if value <= 0.0:
			exhausted = true
	else:
		if _delay_left > 0.0:
			_delay_left -= delta
		else:
			value = minf(value + regen_per_second * delta, max_stamina)
		if exhausted and value >= min_to_resume:
			exhausted = false

	_send()
	return sprinting


func refill() -> void:
	value = max_stamina
	exhausted = false
	_send()


func _on_item_used(item_id: String) -> void:
	match item_id:
		"chocolate":
			refill()
		"es_teh":
			value = minf(value + es_teh_restore, max_stamina)
			if exhausted and value >= min_to_resume:
				exhausted = false
			_send()
			var body := get_parent()
			if body != null and body.has_method("apply_speed_boost"):
				body.call("apply_speed_boost", es_teh_speed_multiplier, es_teh_seconds)
			GameState.notice.emit("Es Teh: stamina nambah, jalan lebih cepat sebentar")


func _send() -> void:
	if not is_equal_approx(value, _last_sent):
		_last_sent = value
		GameState.stamina_changed.emit(value, max_stamina)


# Tombol lari (Shift) dibuat otomatis kalau action "sprint" belum ada di Input Map.
func _ensure_sprint_action() -> void:
	if InputMap.has_action("sprint"):
		return
	InputMap.add_action("sprint")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_SHIFT
	InputMap.action_add_event("sprint", e)
