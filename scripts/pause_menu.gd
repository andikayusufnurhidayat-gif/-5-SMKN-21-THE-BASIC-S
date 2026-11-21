extends CanvasLayer
## Menu pause. Tampilan ada di pause_menu.tscn (bisa diedit di editor); gayanya mengikuti menu utama
## lewat res://MAIN MENU/menu_theme.tres. Tekan ESC untuk pause / lanjut.
## Di editor semua node kelihatan; saat game jalan menu tersembunyi sampai ESC ditekan.

@onready var _root: Control = %Root
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(resume)
	_menu_button.pressed.connect(go_to_menu)
	_quit_button.pressed.connect(get_tree().quit)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if get_tree().paused:
			resume()
		else:
			pause()
		get_viewport().set_input_as_handled()


func pause() -> void:
	get_tree().paused = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# muncul perlahan (node ini process_mode = Always, jadi tween tetap jalan saat game di-pause)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	_resume_button.grab_focus()


func resume() -> void:
	get_tree().paused = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func go_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://MAIN MENU/SCENE/MainMenu.tscn")
