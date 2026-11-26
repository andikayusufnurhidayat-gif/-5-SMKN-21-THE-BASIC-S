extends Node
## Musik latar adaptif. Dibuat otomatis oleh game_flow.gd (nggak perlu dipasang manual).
## Tiga lapis yang diputar bersamaan dan dicampur halus mengikuti suasana:
##   calm  = tenang: kotak musik "Happy Polka" (Jennifer lagi patroli, kamu nggak lagi dikejar atau bersembunyi)
##   tense = horor: kamu SEMBUNYI dan Jennifer dekat / lagi mencari (horror_loop)
##   chase = kejar: Jennifer ngejar kamu atau lagi ngamuk dan kamu nggak sembunyi (scary piano)
## File ada di res://audio/music/ (lihat TRACKS).
## Volume dasar sengaja pelan (base_db); TRACK_DB menyamakan keras-pelan tiap lagu.
## Lagu menu (autoload, mis. AudioManager) yang masih main saat game dimulai otomatis dihentikan.

const TRACKS := {
	"calm": "res://audio/music/musicbox4_happy_polka.ogg",
	"tense": "res://audio/music/horror_loop.mp3",
	"chase": "res://audio/music/chase_scary_piano.mp3",
}
## Koreksi volume per lagu (dB) supaya ketiganya terasa sama keras. Scary piano aslinya jauh lebih keras, jadi diturunkan.
const TRACK_DB := {"calm": -1.5, "tense": 1.0, "chase": -5.0}

@export var base_db := -17.0          ## volume dasar (makin kecil makin pelan; -17 itu pelan)
@export var fade_per_second := 0.45   ## kecepatan perpindahan antar lapisan
@export var stop_foreign_music := true
@export var hide_near_distance := 14.0   ## sembunyi + Jennifer sedekat ini (meter) = musik horor

## Lagu menu yang nggak boleh terdengar di gameplay, di node mana pun (autoload maupun di dalam scene level).
const MENU_SONGS := [
	"res://audio/musicbox3_sad_tune.ogg",
	"res://audio/SMKN21_MainMenu_Horror_Piano_Loop.wav",
]

var _players := {}
var _vol := {"calm": 0.0, "tense": 0.0, "chase": 0.0}
var _target := {"calm": 1.0, "tense": 0.0, "chase": 0.0}
var _check := 0.0
var _foreign_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in TRACKS:
		var path: String = TRACKS[k]
		if not ResourceLoader.exists(path):
			push_warning("MusicDirector: %s belum ada." % path)
			continue
		var st := load(path) as AudioStream
		if st is AudioStreamWAV:
			var w := st as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / 2   # 16-bit mono
		elif st is AudioStreamOggVorbis:
			(st as AudioStreamOggVorbis).loop = true
		elif st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		var p := AudioStreamPlayer.new()
		p.bus = "Music"   # bus dibuat AudioManager; ikut slider Volume Musik
		p.stream = st
		p.volume_db = -60.0
		add_child(p)
		p.play()
		_players[k] = p


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		_evaluate()
	for k in _players:
		_vol[k] = move_toward(float(_vol[k]), float(_target[k]), fade_per_second * delta)
		var v: float = _vol[k]
		(_players[k] as AudioStreamPlayer).volume_db = -60.0 if v <= 0.001 else base_db + float(TRACK_DB.get(k, 0.0)) + linear_to_db(v)
	_foreign_t -= delta
	if stop_foreign_music and _foreign_t <= 0.0:
		_foreign_t = 1.0
		_stop_foreign()


func _evaluate() -> void:
	var t := get_tree().get_first_node_in_group("teacher") as Node3D
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var calm := 1.0
	var tense := 0.0
	var chase := 0.0
	if t != null and p != null:
		var dist := t.global_position.distance_to(p.global_position)
		var hunting: bool = t.has_method("is_hunting") and bool(t.call("is_hunting"))
		var rage: bool = t.has_method("is_rage") and bool(t.call("is_rage"))
		var hidden := bool(p.get_meta("hidden", false))
		if hidden:
			# kamu sembunyi: horor kalau Jennifer dekat / lagi mencari, selain itu tetap tenang
			if dist < hide_near_distance or hunting or rage:
				calm = 0.0
				tense = 1.0
		elif hunting or rage:
			# lagi dikejar
			calm = 0.0
			chase = 1.0
	var quiet := 0.55 if get_tree().paused else 1.0   # saat soal terbuka musiknya lebih pelan
	_target = {"calm": calm * quiet, "tense": tense * quiet, "chase": chase * quiet}


# Hentikan lagu latar lain yang masih main (lagu menu dari autoload). Efek suara biasa nggak disentuh.
func _stop_foreign() -> void:
	var root := get_tree().root
	for n in root.find_children("*", "AudioStreamPlayer", true, false):
		var pl := n as AudioStreamPlayer
		if pl == null or not pl.playing or is_ancestor_of(pl):
			continue
		if pl.stream != null and MENU_SONGS.has(pl.stream.resource_path):
			pl.stop()   # lagu menu di mana pun posisinya
			continue
		var par := pl.get_parent()
		if par != root and par.get_parent() != root:
			continue   # hanya node autoload dan anak-anaknya
		if _is_music(pl.stream):
			pl.stop()


func _is_music(stream: AudioStream) -> bool:
	if stream == null:
		return false
	if stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop:
		return true
	if stream is AudioStreamMP3 and (stream as AudioStreamMP3).loop:
		return true
	if stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return true
	return stream.get_length() > 45.0
