extends Node
## Autoload "GameState": inventory (3 slot, bisa jadi 4 lewat Tas Ransel), katalog item, sinyal stamina untuk HUD.
## Daftarkan di Project Settings > Globals (Autoload) dengan nama: GameState

signal inventory_changed
signal selected_changed(index: int)
signal item_used(item_id: String)
signal stamina_changed(value: float, max_value: float)
signal notice(text: String)

const SLOT_COUNT := 3       ## jumlah slot awal
const MAX_SLOT_COUNT := 4   ## slot maksimal (slot ke-4 dibuka oleh Tas Ransel)

## Barang yang keluar dari mesin kantin kalau beli pakai 1 koin.
const VENDING_PRODUCT := "baking_soda"

## KATALOG ITEM: satu tempat buat semua info item.
##  name        = nama yang tampil di HUD
##  icon        = gambar png buat slot (kosongkan kalau mau ikon otomatis dari model)
##  model       = file model 3D (.glb). Semua item sekarang pakai GLB di res://items/models/. Kalau filenya belum ada, item muncul sebagai kotak warna.
##  scale       = pembesar model di dunia
##  spawn_count = jumlah item ini yang disebar acak tiap game dimulai
##  rooms       = (opsional) awalan nama ruangan tempat item ini muncul, misalnya ["kelas"]. Kosong = di mana saja.
##  usable      = true kalau efeknya sudah jalan. false = item tetap di slot dan muncul pesan use_hint
##  effect      = (opsional) efek khusus yang diatur item_effects.gd:
##                "throw" (dilempar), "whistle" (peluit), "trap" (lem di lantai), "highlight" (sorot buku),
##                "key" (buka loker), "gate_key" (buka gerbang), "backpack" (langsung tambah slot saat diambil, nggak masuk slot)
##  color       = warna kotak pengganti
## Koin spesial: klik kanan dekat mesin kantin bakal beli (lihat _use_coin).
const ITEMS := {
	"baking_soda": {
		"name": "Baking Soda", "icon": "", "model": "res://items/models/baking_soda.glb",
		"scale": 1.0, "spawn_count": 4, "usable": true, "effect": "throw",
		"use_hint": "", "color": Color(0.91, 0.89, 0.82)},
	"chocolate": {
		"name": "Chocolate", "icon": "", "model": "res://items/models/chocolate.glb",
		"scale": 1.0, "spawn_count": 4, "usable": true,
		"use_hint": "", "color": Color(0.42, 0.25, 0.14)},
	"koin": {
		"name": "Coin", "icon": "", "model": "res://items/models/koin.glb",
		"scale": 1.0, "spawn_count": 6, "usable": false,
		"use_hint": "get close to the vending machine, face it, then right-click", "color": Color(0.88, 0.71, 0.23)},
	"es_teh": {
		"name": "Iced Tea", "icon": "", "model": "res://items/models/es_teh.glb",
		"scale": 1.0, "spawn_count": 3, "usable": true,
		"use_hint": "", "color": Color(0.76, 0.44, 0.14)},
	"stabilo": {
		"name": "Highlighter", "icon": "", "model": "res://items/models/stabilo.glb",
		"scale": 1.0, "spawn_count": 3, "rooms": ["kelas", "ruang guru"], "usable": true, "effect": "highlight",
		"use_hint": "", "color": Color(0.98, 0.92, 0.10)},
	"ransel": {
		"name": "Backpack", "icon": "", "model": "res://items/models/ransel.glb",
		"scale": 1.0, "spawn_count": 1, "usable": false, "effect": "backpack",
		"use_hint": "", "color": Color(0.80, 0.15, 0.15)},
	"kunci_loker": {
		"name": "Locker Key", "icon": "", "model": "res://items/models/kunci_loker.glb",
		"scale": 1.0, "spawn_count": 2, "rooms": ["toilet", "ruang lab"], "usable": true, "effect": "key",
		"use_hint": "", "color": Color(0.90, 0.72, 0.20)},
	"peluit": {
		"name": "Whistle", "icon": "", "model": "res://items/models/peluit.glb",
		"scale": 1.0, "spawn_count": 3, "rooms": ["ruang guru"], "usable": true, "effect": "whistle",
		"use_hint": "", "color": Color(0.85, 0.12, 0.12)},
	"penghapus": {
		"name": "Chalkboard Eraser", "icon": "", "model": "res://items/models/penghapus.glb",
		"scale": 1.0, "spawn_count": 5, "rooms": ["kelas"], "usable": true, "effect": "throw",
		"use_hint": "", "color": Color(0.55, 0.34, 0.16)},
	"lem": {
		"name": "Glue", "icon": "", "model": "res://items/models/lem.glb",
		"scale": 1.0, "spawn_count": 3, "rooms": ["ruang lab", "toilet"], "usable": true, "effect": "trap",
		"use_hint": "", "color": Color(0.15, 0.45, 0.90)},
	"kunci_gerbang": {
		"name": "Gate Key", "icon": "res://items/icons/kunci_gerbang.png", "model": "res://items/models/kunci_gerbang.glb",
		"scale": 1.0, "spawn_count": 0, "usable": true, "effect": "gate_key",
		"use_hint": "", "color": Color(1.0, 0.85, 0.1)},
}

## Buku (notebook): bukan item slot, tapi hitungan x/7. Disebar acak juga.
const NOTEBOOK := {
	"name": "Notebook", "model": "res://items/models/notebook.glb",
	"scale": 1.0, "count": 7, "color": Color(0.25, 0.45, 0.9)}

var slots: Array[String] = []
var selected_slot := 0
var slot_count := SLOT_COUNT   ## jumlah slot yang terbuka sekarang
var effects: Node              ## pengatur efek item (item_effects.gd)


func _ready() -> void:
	# Dimuat saat jalan (bukan preload) supaya item_effects.gd boleh memanggil GameState tanpa saling mengunci.
	effects = (load("res://scripts/item_effects.gd") as GDScript).new()
	effects.name = "ItemEffects"
	add_child(effects)
	reset()
	_ensure_action("slot_1", [_key(KEY_1)])
	_ensure_action("slot_2", [_key(KEY_2)])
	_ensure_action("slot_3", [_key(KEY_3)])
	_ensure_action("slot_4", [_key(KEY_4)])
	_ensure_action("use_item", [_key(KEY_F), _mouse(MOUSE_BUTTON_RIGHT)])


## Panggil saat game/level dimulai ulang supaya inventory kosong lagi.
func reset() -> void:
	slots.clear()
	for i in MAX_SLOT_COUNT:
		slots.append("")
	slot_count = SLOT_COUNT
	selected_slot = 0
	inventory_changed.emit()
	selected_changed.emit(selected_slot)


func _first_empty() -> int:
	for i in slot_count:
		if slots[i] == "":
			return i
	return -1


## Mengembalikan true kalau item berhasil masuk, false kalau inventory penuh.
func add_item(item_id: String) -> bool:
	if not ITEMS.has(item_id):
		push_warning("Item tidak dikenal: %s" % item_id)
		return false
	# Tas Ransel nggak masuk slot: langsung nambah slot permanen.
	if ITEMS[item_id].get("effect", "") == "backpack":
		if slot_count >= MAX_SLOT_COUNT:
			notice.emit("You already have a backpack")
			return false
		slot_count += 1
		inventory_changed.emit()
		notice.emit("Backpack: inventory slot added!")
		return true
	var idx := _first_empty()
	if idx == -1:
		notice.emit("Inventory full")
		return false
	# Kalau slot yang lagi dipilih masih kosong, pindahkan pilihan ke item baru.
	var selected_was_empty := slots[selected_slot] == ""
	slots[idx] = item_id
	if selected_was_empty:
		selected_slot = idx
	inventory_changed.emit()
	selected_changed.emit(selected_slot)
	return true


## Memakai item di slot terpilih. Kalau efeknya sudah jalan (usable = true), item hilang dari slot
## dan sinyal item_used dikirim supaya script lain bisa memberi efeknya.
## Item dengan "effect" diatur item_effects.gd dan cuma hilang kalau efeknya benar-benar terpakai.
## Kalau belum bisa (usable = false), item tetap di slot dan muncul pesan.
func use_selected() -> void:
	var id := slots[selected_slot]
	if id == "":
		return
	if id == "koin":
		_use_coin()
		return
	var data: Dictionary = ITEMS[id]
	var effect: String = data.get("effect", "")
	if effect != "":
		if effects.use_effect(id, effect, data):
			slots[selected_slot] = ""
			inventory_changed.emit()
			item_used.emit(id)
		return
	if not data.get("usable", true):
		notice.emit("%s: %s" % [data.get("name", id), data.get("use_hint", "cannot be used yet")])
		return
	slots[selected_slot] = ""
	inventory_changed.emit()
	item_used.emit(id)


## Koin dipakai: cari mesin kantin yang lagi dihadap dan cukup dekat, lalu beli.
func _use_coin() -> void:
	var cam := get_viewport().get_camera_3d()
	for machine in get_tree().get_nodes_in_group("vending_machine"):
		if machine.has_method("can_use") and machine.can_use(cam):
			try_buy_with_coin(machine)
			return
	notice.emit("Coin: %s" % ITEMS["koin"]["use_hint"])


## Beli 1 barang dengan koin yang lagi terpilih. Koin berubah langsung jadi barangnya di slot yang sama,
## jadi tetap jalan walau inventory lagi penuh. Mengembalikan true kalau berhasil.
func try_buy_with_coin(machine: Node = null) -> bool:
	if slots[selected_slot] != "koin":
		notice.emit("Select a coin in a slot first")
		return false
	if machine == null:
		machine = get_tree().get_first_node_in_group("vending_machine")
	# Barang yang keluar = pilihan di mesin (selected_product), bawaannya VENDING_PRODUCT.
	var product := VENDING_PRODUCT
	if machine != null:
		var chosen: Variant = machine.get("selected_product")
		if chosen is String and ITEMS.has(chosen):
			product = chosen
	slots[selected_slot] = product
	inventory_changed.emit()
	notice.emit("Got %s (1 coin used)" % ITEMS[product].get("name", product))
	if machine != null and machine.has_method("on_purchase"):
		machine.on_purchase()
	return true


func select_slot(index: int) -> void:
	if effects != null:
		effects.cancel_aim()   # ganti slot = batal membidik
	selected_slot = wrapi(index, 0, slot_count)
	selected_changed.emit(selected_slot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("slot_1"):
		select_slot(0)
	elif event.is_action_pressed("slot_2"):
		select_slot(1)
	elif event.is_action_pressed("slot_3"):
		select_slot(2)
	elif event.is_action_pressed("slot_4"):
		if slot_count >= 4:
			select_slot(3)
	elif event.is_action_pressed("use_item"):
		var id := slots[selected_slot]
		if id != "" and ITEMS[id].get("effect", "") == "throw":
			effects.begin_aim(id)   # item lempar: bidik dulu, dilempar saat tombol dilepas
		else:
			use_selected()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_slot(selected_slot - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_slot(selected_slot + 1)


## Bidik lemparan: begitu tombol dilepas, item dilempar. Dicek tiap frame supaya tidak ada release yang terlewat.
func _process(_delta: float) -> void:
	if effects != null and effects.is_aiming() and not Input.is_action_pressed("use_item"):
		_release_aim()


func _release_aim() -> void:
	var id := slots[selected_slot]
	if id == "":
		effects.cancel_aim()
		return
	if effects.release_aim(id, ITEMS[id]):
		slots[selected_slot] = ""
		inventory_changed.emit()
		item_used.emit(id)


# Action dibuat otomatis kalau belum ada di Input Map.
# Kalau lu sudah bikin action dengan nama sama di Input Map, punya lu yang dipakai.
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
