extends Node

## Tiny built-in localisation (autoload "Loc"): English + Bahasa Indonesia.
## Usage: Loc.t("menu.play"), Loc.t("game.best", [UITheme.format_number(n)]),
## Loc.fruit_name(level), Loc.fruit_plural(level), Loc.prop_name(prop).
## To add a language: add its code to LANGUAGES / LANGUAGE_NAMES and a block to STRINGS.
## Missing keys fall back to English, then to the key itself.

signal language_changed(code: String)

const LANGUAGES: Array[String] = ["en", "id"]
const LANGUAGE_NAMES := {
	"en": "English",
	"id": "Bahasa Indonesia",
}

const STRINGS := {
	"en": {
		"app.title": "Fruityzer",
		"app.tagline": "Drop it. Merge it. Grow it!",

		"boot.subtitle": "A juicy fruit merging game",
		"boot.washing": "Washing the fruits...",
		"boot.ready": "Ready!",

		"load.default": "Loading...",
		"load.opening": "Opening the orchard...",
		"load.filling": "Filling the jar...",
		"load.charging": "Charging power-ups...",
		"load.home": "Heading home...",
		"tip.1": "Drop a fruit on its twin to merge them into a bigger fruit.",
		"tip.2": "Two Watermelons merge into a giant bonus!",
		"tip.3": "Keep your biggest fruits in a corner to leave room.",
		"tip.4": "Don't let fruits stay above the pink line for too long!",
		"tip.5": "Quick merges in a row make a combo.",
		"tip.6": "Discover all 15 fruits to complete your collection.",
		"tip.7": "Frenzy mode drops power-ups like Bombs and Sticky fruits.",
		"tip.8": "Charged fruits bounce like crazy. Aim them carefully!",
		"tip.9": "The next fruit is shown in the bubble at the top right.",

		"menu.play": "Play",
		"menu.frenzy": "Frenzy",
		"menu.powerups": "Power-ups",
		"menu.best": "Best %s",
		"menu.frenzy_best": "Frenzy %s",
		"menu.collection": "Fruit Collection",
		"menu.tap_hint": "Tap a fruit to see its name",
		"menu.complete": "Collection complete! You're a true fruit master.",
		"menu.tier_name": "Tier %d  ·  %s",
		"menu.tier_hint_prev": "Tier %d  ·  Merge two %s to find it!",
		"menu.tier_hint": "Tier %d  ·  Keep merging to find it!",
		"menu.quit": "Quit",
		"menu.language": "Language",

		"pu.title": "Power-ups",
		"pu.subtitle": "Only in Frenzy mode. About 1 in 5 drops gets a power-up.\nFruits destroyed by power-ups give no points.",
		"pu.ok": "Got it!",
		"pu.sticky.desc": "Glues itself to the first thing it touches: a wall, the floor or another fruit.",
		"pu.bomb.desc": "Goes boom 10 seconds after it drops and clears the fruits around it.",
		"pu.nuclear.desc": "Merge it to set off a giant blast. The new fruit survives!",
		"pu.concrete.desc": "Smashes straight to the floor, crushing every fruit in its way.",
		"pu.charged.desc": "Super bouncy! Springs off everything it hits.",
		"pu.sticky.tip": "Sticks to the first thing it touches.",
		"pu.bomb.tip": "Explodes 10s after it drops.",
		"pu.nuclear.tip": "Merge it for a giant blast!",
		"pu.concrete.tip": "Crushes everything below it.",
		"pu.charged.tip": "Bounces like crazy!",

		"prop.sticky": "Sticky",
		"prop.bomb": "Bomb",
		"prop.nuclear": "Nuclear",
		"prop.concrete": "Concrete",
		"prop.charged": "Charged",
		"prop.sticky.short": "STICKY",
		"prop.bomb.short": "BOMB",
		"prop.nuclear.short": "NUKE",
		"prop.concrete.short": "CONCRETE",
		"prop.charged.short": "CHARGED",

		"mode.normal": "Normal",
		"mode.frenzy": "Frenzy",

		"game.next": "NEXT",
		"game.best": "Best %s",
		"game.frenzy_best": "Frenzy best %s",
		"game.paused": "Paused",
		"game.resume": "Resume",
		"game.restart": "Restart",
		"game.sound_on": "Sound on",
		"game.sound_off": "Sound off",
		"game.home": "Home",
		"game.play_again": "Play again",
		"game.too_full": "Too full!  %.1fs",
		"game.over": "Jar's full!",
		"game.record": "New record!",
		"game.new_best_badge": "NEW BEST!",
		"game.final_best": "Best %s",
		"game.biggest": "Biggest fruit: %s",
		"game.discoveries": "New discoveries: %d  ·  Collection %d / %d",
		"game.next_discover": "Next to discover: merge two %s!",
		"game.complete": "Collection complete. You're a fruit master!",
		"game.merges": "Merges this run: %d",
		"game.combo": "Combo x%d!",

		"toast.combo_sub": "Chain reaction! So satisfying.",
		"toast.best": "New best score!",
		"toast.best_sub": "You beat %s. Keep going!",
		"toast.points": "%s points!",
		"toast.cheer1": "Juicy start!",
		"toast.cheer2": "You're on fire!",
		"toast.cheer3": "Unstoppable!",
		"toast.cheer4": "Fruit legend!",
		"toast.powerup": "New power-up: %s",
		"toast.smash": "%s Smash!",
		"toast.smash_sub": "+%s bonus points",
		"toast.complete": "Collection complete!",
		"toast.complete_sub": "You found all %d fruits. Legend!",
		"toast.new_fruit": "New fruit: %s!",
		"toast.new_fruit_sub": "%d / %d discovered. What's next?",
		"toast.wow": "Wow, a %s!",
		"toast.tier": "Tier %d of %d",
		"toast.phew": "Phew! Close one",
		"toast.phew_sub": "The jar is safe... for now.",
		"toast.drops": "Bigger drops unlocked!",
		"toast.drops_sub": "Bigger fruits drop more often now.",
		"toast.drops_new": "%s can now drop. Game on!",

		"guide.title": "Fruit Guide",
		"guide.found": "%d / %d found",
		"guide.new": "NEW!",

		"fruit.blueberry": "Blueberry",
		"fruit.cherry": "Cherry",
		"fruit.strawberry": "Strawberry",
		"fruit.grape": "Grape",
		"fruit.kiwi": "Kiwi",
		"fruit.lime": "Lime",
		"fruit.orange": "Orange",
		"fruit.persimmon": "Persimmon",
		"fruit.apple": "Apple",
		"fruit.pear": "Pear",
		"fruit.peach": "Peach",
		"fruit.dragonfruit": "Dragonfruit",
		"fruit.pineapple": "Pineapple",
		"fruit.melon": "Melon",
		"fruit.watermelon": "Watermelon",
	},
	"id": {
		"app.title": "Fruityzer",
		"app.tagline": "Jatuhkan. Gabungkan. Besarkan!",

		"boot.subtitle": "Game gabung buah yang segar",
		"boot.washing": "Mencuci buah-buahan...",
		"boot.ready": "Siap!",

		"load.default": "Memuat...",
		"load.opening": "Membuka kebun buah...",
		"load.filling": "Mengisi toples...",
		"load.charging": "Mengisi power-up...",
		"load.home": "Kembali ke menu...",
		"tip.1": "Jatuhkan buah ke kembarannya untuk menggabungkannya jadi buah yang lebih besar.",
		"tip.2": "Dua Semangka bergabung jadi bonus raksasa!",
		"tip.3": "Taruh buah terbesar di pojok supaya masih ada ruang.",
		"tip.4": "Jangan biarkan buah terlalu lama di atas garis merah muda!",
		"tip.5": "Gabungkan beruntun dengan cepat untuk membuat kombo.",
		"tip.6": "Temukan ke-15 buah untuk melengkapi koleksimu.",
		"tip.7": "Mode Frenzy menjatuhkan power-up seperti Bom dan buah Lengket.",
		"tip.8": "Buah Listrik memantul gila-gilaan. Bidik dengan hati-hati!",
		"tip.9": "Buah berikutnya terlihat di gelembung kanan atas.",

		"menu.play": "Main",
		"menu.frenzy": "Frenzy",
		"menu.powerups": "Power-up",
		"menu.best": "Terbaik %s",
		"menu.frenzy_best": "Frenzy %s",
		"menu.collection": "Koleksi Buah",
		"menu.tap_hint": "Ketuk buah untuk melihat namanya",
		"menu.complete": "Koleksi lengkap! Kamu master buah sejati.",
		"menu.tier_name": "Tingkat %d  ·  %s",
		"menu.tier_hint_prev": "Tingkat %d  ·  Gabungkan dua %s untuk menemukannya!",
		"menu.tier_hint": "Tingkat %d  ·  Terus gabungkan untuk menemukannya!",
		"menu.quit": "Keluar",
		"menu.language": "Bahasa",

		"pu.title": "Power-up",
		"pu.subtitle": "Hanya di mode Frenzy. Sekitar 1 dari 5 buah membawa power-up.\nBuah yang hancur karena power-up tidak memberi poin.",
		"pu.ok": "Oke, paham!",
		"pu.sticky.desc": "Menempel pada benda pertama yang disentuhnya: dinding, lantai, atau buah lain.",
		"pu.bomb.desc": "Meledak 10 detik setelah dijatuhkan dan menghancurkan buah di sekitarnya.",
		"pu.nuclear.desc": "Gabungkan untuk memicu ledakan raksasa. Buah barunya tetap selamat!",
		"pu.concrete.desc": "Menghantam langsung ke lantai dan meremukkan semua buah di jalurnya.",
		"pu.charged.desc": "Super memantul! Terpental dari apa pun yang ditabraknya.",
		"pu.sticky.tip": "Menempel pada benda pertama yang disentuh.",
		"pu.bomb.tip": "Meledak 10 detik setelah dijatuhkan.",
		"pu.nuclear.tip": "Gabungkan untuk ledakan raksasa!",
		"pu.concrete.tip": "Meremukkan semua yang ada di bawahnya.",
		"pu.charged.tip": "Memantul gila-gilaan!",

		"prop.sticky": "Lengket",
		"prop.bomb": "Bom",
		"prop.nuclear": "Nuklir",
		"prop.concrete": "Beton",
		"prop.charged": "Listrik",
		"prop.sticky.short": "LENGKET",
		"prop.bomb.short": "BOM",
		"prop.nuclear.short": "NUKLIR",
		"prop.concrete.short": "BETON",
		"prop.charged.short": "LISTRIK",

		"mode.normal": "Normal",
		"mode.frenzy": "Frenzy",

		"game.next": "BERIKUT",
		"game.best": "Terbaik %s",
		"game.frenzy_best": "Terbaik Frenzy %s",
		"game.paused": "Jeda",
		"game.resume": "Lanjut",
		"game.restart": "Ulangi",
		"game.sound_on": "Suara nyala",
		"game.sound_off": "Suara mati",
		"game.home": "Menu",
		"game.play_again": "Main lagi",
		"game.too_full": "Hampir penuh!  %.1fd",
		"game.over": "Toplesnya penuh!",
		"game.record": "Rekor baru!",
		"game.new_best_badge": "REKOR BARU!",
		"game.final_best": "Terbaik %s",
		"game.biggest": "Buah terbesar: %s",
		"game.discoveries": "Penemuan baru: %d  ·  Koleksi %d / %d",
		"game.next_discover": "Berikutnya: gabungkan dua %s!",
		"game.complete": "Koleksi lengkap. Kamu master buah!",
		"game.merges": "Penggabungan ronde ini: %d",
		"game.combo": "Kombo x%d!",

		"toast.combo_sub": "Reaksi berantai! Puas banget.",
		"toast.best": "Skor terbaik baru!",
		"toast.best_sub": "Kamu melewati %s. Terus!",
		"toast.points": "%s poin!",
		"toast.cheer1": "Awal yang segar!",
		"toast.cheer2": "Kamu lagi panas!",
		"toast.cheer3": "Tak terhentikan!",
		"toast.cheer4": "Legenda buah!",
		"toast.powerup": "Power-up baru: %s",
		"toast.smash": "Hantaman %s!",
		"toast.smash_sub": "+%s poin bonus",
		"toast.complete": "Koleksi lengkap!",
		"toast.complete_sub": "Kamu menemukan semua %d buah. Legenda!",
		"toast.new_fruit": "Buah baru: %s!",
		"toast.new_fruit_sub": "%d / %d ditemukan. Apa selanjutnya?",
		"toast.wow": "Wah, %s!",
		"toast.tier": "Tingkat %d dari %d",
		"toast.phew": "Fiuh! Nyaris saja",
		"toast.phew_sub": "Toplesnya aman... untuk sekarang.",
		"toast.drops": "Buah jatuhan makin besar!",
		"toast.drops_sub": "Buah besar sekarang lebih sering jatuh.",
		"toast.drops_new": "%s sekarang bisa jatuh. Ayo!",

		"guide.title": "Panduan Buah",
		"guide.found": "%d / %d ditemukan",
		"guide.new": "BARU!",

		"fruit.blueberry": "Bluberi",
		"fruit.cherry": "Ceri",
		"fruit.strawberry": "Stroberi",
		"fruit.grape": "Anggur",
		"fruit.kiwi": "Kiwi",
		"fruit.lime": "Jeruk Nipis",
		"fruit.orange": "Jeruk",
		"fruit.persimmon": "Kesemek",
		"fruit.apple": "Apel",
		"fruit.pear": "Pir",
		"fruit.peach": "Persik",
		"fruit.dragonfruit": "Buah Naga",
		"fruit.pineapple": "Nanas",
		"fruit.melon": "Melon",
		"fruit.watermelon": "Semangka",
	},
}

const TIP_COUNT := 9

var language: String = "en"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved := SaveManager.get_language()
	if saved.is_empty():
		# First launch: follow the device language.
		saved = "id" if OS.get_locale_language() == "id" else "en"
	_apply(saved)


func t(key: String, args: Array = []) -> String:
	var table: Dictionary = STRINGS.get(language, STRINGS["en"])
	var text := String(table.get(key, STRINGS["en"].get(key, key)))
	if args.is_empty():
		return text
	return text % args


func set_language(code: String) -> void:
	if not LANGUAGES.has(code) or code == language:
		return
	_apply(code)
	SaveManager.set_language(code)
	language_changed.emit(code)


## Cycles to the next language (EN -> ID -> EN...).
func next_language() -> void:
	var idx := LANGUAGES.find(language)
	set_language(LANGUAGES[(idx + 1) % LANGUAGES.size()])


func get_language_name(code: String = "") -> String:
	var c := language if code.is_empty() else code
	return String(LANGUAGE_NAMES.get(c, c))


func fruit_name(level: int) -> String:
	var def := FruitRegistry.catalog.get_fruit(level)
	if def == null:
		return "?"
	var key := "fruit.%s" % String(def.id)
	var text := t(key)
	return def.display_name if text == key else text


## Name as used after "two ..." ("Merge two Cherries" / "Gabungkan dua Ceri").
func fruit_plural(level: int) -> String:
	var fname := fruit_name(level)
	if language == "en":
		return UITheme.pluralize(fname)
	return fname


func prop_key(prop: int) -> String:
	match prop:
		FruitProperty.Type.STICKY:
			return "sticky"
		FruitProperty.Type.BOMB:
			return "bomb"
		FruitProperty.Type.NUCLEAR:
			return "nuclear"
		FruitProperty.Type.CONCRETE:
			return "concrete"
		FruitProperty.Type.CHARGED:
			return "charged"
		_:
			return ""


func prop_name(prop: int) -> String:
	var k := prop_key(prop)
	return "" if k.is_empty() else t("prop." + k)


func prop_short(prop: int) -> String:
	var k := prop_key(prop)
	return "" if k.is_empty() else t("prop.%s.short" % k)


func random_tip() -> String:
	return t("tip.%d" % (randi() % TIP_COUNT + 1))


func _apply(code: String) -> void:
	language = code if LANGUAGES.has(code) else "en"
	TranslationServer.set_locale(language)
