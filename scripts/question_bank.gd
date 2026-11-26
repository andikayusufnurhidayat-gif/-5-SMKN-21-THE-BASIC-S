class_name QuestionBank
extends RefCounted
## Bank soal. 3 soal per buku, dipakai papan hijau muda (think_pad.gd).
##  - Buku BIASA (3 dari 7): 3 soal penjumlahan 1-10 yang gampang (mis. 7 + 6).
##  - Buku RUSAK (4 dari 7, diacak tiap game): soal 1 dan 2 penjumlahan 1-10, soal 3 = soal RUSAK (tulisan dicoret-coret
##    bertumpuk). Soal rusak nggak punya jawaban benar, apa pun jawabannya dianggap salah.

const NOISE := "#%&?@!*<>/|~^0123456789XZQ"

## Jumlah buku total (diisi game_flow.gd lewat roll_broken_books), dipakai judul layar soal.
static var total_books := 7
## Nomor buku (1..total) yang termasuk buku susah (berisi soal rusak). Diacak ulang tiap game dimulai.
static var broken_books: Array[int] = []


static func roll_broken_books(total := 7, hard_count := 4) -> void:
	total_books = total
	var all: Array[int] = []
	for i in range(1, total + 1):
		all.append(i)
	all.shuffle()
	broken_books.assign(all.slice(0, mini(hard_count, total)))
	print("QuestionBank: buku susah (ada soal rusak) = ", broken_books)


static func make_quiz(book_number: int) -> Array[Dictionary]:
	if broken_books.is_empty():
		roll_broken_books()
	var quiz: Array[Dictionary] = []
	# Semua soal biasa = penjumlahan gampang (1..10 + 1..10), tanpa soal kembar dalam satu buku.
	var used := {}
	var normal_count := 2 if broken_books.has(book_number) else 3
	while quiz.size() < normal_count:
		var q := _make("add_easy", false)
		if used.has(q["text"]):
			continue
		used[q["text"]] = true
		quiz.append(q)
	# Buku "susah": soal 3 (terakhir) adalah soal rusak (nggak ada jawaban benar), total tetap 3 soal.
	if broken_books.has(book_number):
		quiz.append(broken())
	return quiz


## Soal rusak ala Baldi asli: deretan angka/desimal/tanda kurung yang kepanjangan dan TERTUMPUK
## (3 lapis teks tercetak di tempat yang sama). Nggak ada jawaban benar.
static func broken() -> Dictionary:
	var layers: Array[String] = []
	for i in 3:
		layers.append(_garble(randi_range(28, 40)) + "\n" + _garble(randi_range(7, 12)) + " =")
	return {"text": layers[0], "layers": layers, "answer": 0, "broken": true}


static func _garble(n: int) -> String:
	var s := ""
	while s.length() < n:
		match randi() % 7:
			0, 1, 2:
				s += str(randi_range(1, 99999999))
			3:
				s += "%d.%d" % [randi_range(1, 9999), randi_range(1, 999)]
			4:
				s += ["+", "-", "×", "÷", "X", "+(", "-("][randi() % 7]
			5:
				s += "("
			6:
				s += ".."
	return s.substr(0, n)


static func _q(text: String, answer: int) -> Dictionary:
	return {"text": text, "answer": answer, "broken": false}


static func _make(kind: String, _hard: bool) -> Dictionary:
	match kind:
		"add_easy":
			var a := randi_range(1, 10)
			var b := randi_range(1, 10)
			return _q("%d + %d = ?" % [a, b], a + b)
		"add_teen":
			var a := randi_range(10, 19)
			var b := randi_range(10, 19)
			return _q("%d + %d = ?" % [a, b], a + b)
		"add":
			var a := randi_range(2, 20)
			var b := randi_range(2, 20)
			return _q("%d + %d = ?" % [a, b], a + b)
		"sub":
			var a := randi_range(8, 30)
			var b := randi_range(1, a - 1)
			return _q("%d - %d = ?" % [a, b], a - b)
		"mul_easy":
			var a := randi_range(2, 5)
			var b := randi_range(2, 5)
			return _q("%d × %d = ?" % [a, b], a * b)
		"biggest":
			var nums: Array[int] = []
			while nums.size() < 3:
				var n := randi_range(3, 40)
				if not nums.has(n):
					nums.append(n)
			return _q("Which number is the biggest?\n%d,   %d,   %d" % [nums[0], nums[1], nums[2]], int(nums.max()))
		# --- soal susah ---
		"mul":
			var a := randi_range(7, 15)
			var b := randi_range(6, 12)
			return _q("%d × %d = ?" % [a, b], a * b)
		"div":
			var b := randi_range(4, 12)
			var r := randi_range(7, 16)
			return _q("%d ÷ %d = ?" % [b * r, b], r)
		"order":
			var a := randi_range(10, 60)
			var b := randi_range(3, 9)
			var c := randi_range(3, 9)
			return _q("%d + %d × %d = ?" % [a, b, c], a + b * c)
		"arith_seq":
			var s := randi_range(5, 40)
			var d := randi_range(4, 11)
			var items := PackedStringArray()
			for i in 4:
				items.append(str(s + d * i))
			return _q("Continue the pattern:  %s, ?" % ", ".join(items), s + d * 4)
		"geo_seq":
			var s := randi_range(2, 5)
			var r := randi_range(2, 3)
			var items := PackedStringArray()
			var v := s
			for i in 4:
				items.append(str(v))
				v *= r
			return _q("Continue the pattern:  %s, ?" % ", ".join(items), v)
	return _q("1 + 1 = ?", 2)
