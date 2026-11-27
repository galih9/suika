extends Node

## Built-in localisation (autoload "Loc").
## Usage: Loc.t("menu.play"), Loc.t("game.best", [UITheme.format_number(n)]),
## Loc.fruit_name(level), Loc.fruit_plural(level), Loc.prop_name(prop).
## To add a language: add its code to LANGUAGES / LANGUAGE_NAMES / LANGUAGE_SUBTITLES / TABLES
## and add a translation table script under res://scripts/data/translations/.
## Missing keys fall back to English, then to the key itself.

signal language_changed(code: String)

const LANGUAGES: Array[String] = ["en", "id", "ru", "ja", "sk", "cs", "pl", "ms"]

const LANGUAGE_NAMES := {
	"en": "English",
	"id": "Bahasa Indonesia",
	"ru": "Русский",
	"ja": "日本語",
	"sk": "Slovenčina",
	"cs": "Čeština",
	"pl": "Polski",
	"ms": "Bahasa Melayu",
}

const LANGUAGE_SUBTITLES := {
	"en": "EN",
	"id": "Indonesian",
	"ru": "Russian",
	"ja": "Japanese",
	"sk": "Slovak",
	"cs": "Czech",
	"pl": "Polish",
	"ms": "Malay",
}

const LOCALE_ALIASES := {
	"in": "id",
	"jp": "ja",
	"cz": "cs",
	"zsm": "ms",
}

const TABLES := {
	"en": preload("res://scripts/data/translations/en.gd"),
	"id": preload("res://scripts/data/translations/id.gd"),
	"ru": preload("res://scripts/data/translations/ru.gd"),
	"ja": preload("res://scripts/data/translations/ja.gd"),
	"sk": preload("res://scripts/data/translations/sk.gd"),
	"cs": preload("res://scripts/data/translations/cs.gd"),
	"pl": preload("res://scripts/data/translations/pl.gd"),
	"ms": preload("res://scripts/data/translations/ms.gd"),
}

const TIP_COUNT := 9

var language: String = "en"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved := SaveManager.get_language()
	if saved.is_empty():
		# First launch: follow the device language.
		saved = resolve_device_language(OS.get_locale_language())
	_apply(saved)


func get_strings(code: String) -> Dictionary:
	var tbl: Variant = TABLES.get(code, TABLES["en"])
	return tbl.STRINGS


func resolve_device_language(locale_lang: String) -> String:
	var norm := locale_lang.strip_edges().to_lower().split("_")[0].split("-")[0]
	if LOCALE_ALIASES.has(norm):
		norm = String(LOCALE_ALIASES[norm])
	return norm if LANGUAGES.has(norm) else "en"


func t(key: String, args: Array = []) -> String:
	var en_table := get_strings("en")
	var table := get_strings(language)
	var text := String(table.get(key, en_table.get(key, key)))
	if args.is_empty():
		return text
	return text % args


func set_language(code: String) -> bool:
	if not LANGUAGES.has(code) or code == language:
		return false
	_apply(code)
	SaveManager.set_language(code)
	language_changed.emit(code)
	return true


## Cycles to the next language in LANGUAGES.
func next_language() -> void:
	var idx := LANGUAGES.find(language)
	set_language(LANGUAGES[(idx + 1) % LANGUAGES.size()])


func get_language_name(code: String = "") -> String:
	var c := language if code.is_empty() else code
	return String(LANGUAGE_NAMES.get(c, c))


func get_language_subtitle(code: String = "") -> String:
	var c := language if code.is_empty() else code
	return String(LANGUAGE_SUBTITLES.get(c, c.to_upper()))


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
		FruitProperty.Type.LOW_GRAVITY:
			return "low_gravity"
		FruitProperty.Type.SHADOW:
			return "shadow"
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
