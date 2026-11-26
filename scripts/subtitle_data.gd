extends RefCounted
## Teks subtitle untuk suara/dialog Bu Jennifer dalam 4 bahasa. Bahasa & on/off diatur di Options (disimpan AudioManager).
## Cara tambah baris baru: tambah satu entri di LINES (kunci = id suara, mis. "greet"), isi en / id / pt / zh.
## Kalau id nggak ada di tabel, game memakai teks Inggris bawaan dari kode.

const LANG_CODES := ["en", "id", "pt", "zh"]
const LANG_NAMES := ["English", "Bahasa Indonesia", "Português", "中文"]

const LINES := {
	"greet": {"en": "Ready?", "id": "Siap?", "pt": "Prontos?", "zh": "准备好了吗？"},
	"intro1": {"en": "Good evening.", "id": "Selamat malam.", "pt": "Boa noite.", "zh": "晚上好。"},
	"intro2": {"en": "How are you feeling today?", "id": "Bagaimana perasaanmu hari ini?", "pt": "Como você está se sentindo hoje?", "zh": "你今天感觉怎么样？"},
	"intro3":    {"en": "Finished? You may go home. Happy studying!", "id": "Selesai? Kamu boleh pulang. Selamat belajar!",
				  "pt": "Terminou? Pode ir para casa. Bons estudos!", "zh": "完成了吗？你可以回家了。好好学习！"},
	"good": {"en": "Correct.", "id": "Benar.", "pt": "Correto.", "zh": "正确。"},
	"wrong": {"en": "Wrong!", "id": "Salah!", "pt": "Errado!", "zh": "错了！"},
	"rage": {"en": "[Screams]", "id": "[Berteriak]", "pt": "[Grita]", "zh": "[尖叫]"},
	"saw_you": {"en": "Target engaged.", "id": "Target terkunci.", "pt": "Alvo engajado.", "zh": "锁定目标。"},
	"where": {"en": "Where?", "id": "Dimana?", "pt": "Onde?", "zh": "在哪儿？"},
	"gave_up": {"en": "Time over.", "id": "Waktu habis.", "pt": "Tempo esgotado.", "zh": "时间到。"},
	"calm_down": {"en": "[Annoyed grumble]", "id": "[Menggerutu kesal]", "pt": "[Resmunga irritada]", "zh": "[不耐烦地嘟囔]"},
	"cough": {"en": "[Coughs]", "id": "[Batuk]", "pt": "[Tosse]", "zh": "[咳嗽]"},
	"glue": {"en": "[Grunts in pain]", "id": "[Mengerang kesakitan]", "pt": "[Grunhe de dor]", "zh": "[痛苦地哼了一声]"},

	# --- Cutscene ending 1: tertangkap (caught_cutscene.gd) ---
	"c_bell":    {"en": "The final bell rang hours ago.", "id": "Bel pulang sudah berbunyi berjam-jam yang lalu.",
				  "pt": "O último sinal tocou há horas.", "zh": "放学铃声早在几个小时前就响过了。"},
	"c_leave": {"en": "Hold!", "id": "Berhenti!", "pt": "Parado!", "zh": "站住！"},
	"c_notdone": {"en": "Game over.", "id": "Permainan berakhir.", "pt": "Fim de jogo.", "zh": "游戏结束。"},
	"c_remedial": {"en": "You lose.", "id": "Kamu kalah.", "pt": "Você perdeu.", "zh": "你输了。"},
	"c_write": {"en": "Hurry up.", "id": "Cepat.", "pt": "Depressa.", "zh": "快点。"},
	"c_board":   {"en": "I WILL NOT RUN FROM CLASS.", "id": "AKU TIDAK AKAN KABUR DARI KELAS.",
				  "pt": "NÃO VOU FUGIR DA AULA.", "zh": "我不会逃课。"},
	"c_see": {"en": "See you later.", "id": "Sampai nanti.", "pt": "Até logo.", "zh": "回头见。"},
	"c_end1":    {"en": "ENDING 1 OF 2", "id": "AKHIR 1 DARI 2", "pt": "FINAL 1 DE 2", "zh": "结局 1 / 2"},
	"c_end_title": {"en": "DETENTION FOREVER", "id": "REMEDIAL SELAMANYA", "pt": "CASTIGO ETERNO", "zh": "永远的补习"},
	"c_end_sub": {"en": "The bell never rings for you.", "id": "Bel itu tidak pernah berbunyi untukmu.",
				  "pt": "O sinal nunca toca para você.", "zh": "下课铃永远不会为你响起。"},
	# --- Cutscene ending 2: berhasil kabur (escape_cutscene.gd) ---
	"e_card":    {"en": "Seven notebooks. One key. One gate.", "id": "Tujuh buku. Satu kunci. Satu gerbang.",
				  "pt": "Sete cadernos. Uma chave. Um portão.", "zh": "七本笔记本。一把钥匙。一道大门。"},
	"e_hurry":   {"en": "Come on... come on...", "id": "Ayo... ayo...",
				  "pt": "Vamos... vamos...", "zh": "快点……快点……"},
	"e_back":    {"en": "GET BACK HERE!", "id": "KEMBALI KE SINI!",
				  "pt": "VOLTE AQUI!", "zh": "给我回来！"},
	"e_free":    {"en": "...I made it. I'm actually out.", "id": "...Aku berhasil. Aku benar-benar keluar.",
				  "pt": "...Consegui. Eu realmente saí.", "zh": "……我做到了。我真的出来了。"},
	"e_tomorrow": {"en": "Goodbye.", "id": "Selamat tinggal.", "pt": "Adeus.", "zh": "再见。"},
	"e_end2":    {"en": "ENDING 2 OF 2", "id": "AKHIR 2 DARI 2", "pt": "FINAL 2 DE 2", "zh": "结局 2 / 2"},
	"e_end_title": {"en": "SCHOOL'S OUT", "id": "SEKOLAH USAI", "pt": "AULA ENCERRADA", "zh": "放学了"},
	"e_end_sub": {"en": "The bell finally rang for you.", "id": "Akhirnya bel itu berbunyi untukmu.",
				  "pt": "Finalmente o sinal tocou para você.", "zh": "下课铃终于为你响起了。"},
	"c_skip":    {"en": "Press SPACE to skip", "id": "Tekan SPASI untuk lewati",
				  "pt": "Pressione ESPAÇO para pular", "zh": "按空格键跳过"},
}


static func _audio_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("AudioManager")
	return null


static func enabled() -> bool:
	var am := _audio_manager()
	return am == null or not ("subtitles_on" in am) or am.subtitles_on


## Diisi sementara oleh cutscene (mis. opening_cutscene.gd) supaya semua subtitle Jennifer selama cutscene
## selalu satu bahasa (mis. "en"), apa pun pilihan di Options. Kosong ("") = ikut Options. Wajib dikosongkan lagi setelah cutscene.
static var forced_lang := ""


static func lang_code() -> String:
	if forced_lang != "" and LANG_CODES.has(forced_lang):
		return forced_lang
	var am := _audio_manager()
	var i := 0
	if am != null and "subtitle_lang" in am:
		i = clampi(am.subtitle_lang, 0, LANG_CODES.size() - 1)
	return LANG_CODES[i]


## Teks subtitle untuk id tertentu dalam bahasa pilihan pemain. Nggak ada di tabel -> pakai fallback.
static func line(id: String, fallback := "") -> String:
	if LINES.has(id):
		var d: Dictionary = LINES[id]
		return d.get(lang_code(), d["en"])
	return fallback
