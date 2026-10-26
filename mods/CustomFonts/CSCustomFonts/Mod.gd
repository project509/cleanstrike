# Custom Fonts: shared helpers used by this mod's scripts.
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_custom_fonts"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"font": "Play",
}

const FONTS := ["Play", "Rubik", "Inter", "Exo 2", "Jost", "Geologica", "Literata", "Lora (game)"]
const THEME := "res://UI/Themes/Theme.tres"
const LORA := "res://Fonts/Lora-Regular.ttf"

static var _fonts := {}


static func font_for(name: String) -> Font:
	if name.begins_with("Lora") or not (name in FONTS):
		return load(LORA)
	if not _fonts.has(name):
		var f := FontFile.new()
		var err := f.load_dynamic_font("res://CSCustomFonts/Fonts/%s.ttf" % name.replace(" ", ""))
		_fonts[name] = f if err == OK else load(LORA)
	return _fonts[name]


# Put the chosen font everywhere the game's theme names a font, and make it
# the fallback for anything without a theme (other mods' panels).
static func apply() -> Font:
	var name := str(setting("font")) if active() else "Lora (game)"
	var f := font_for(name)
	var theme: Theme = load(THEME)
	theme.default_font = f
	for t in theme.get_font_type_list():
		for n in theme.get_font_list(t):
			theme.set_font(n, t, f)
	ThemeDB.fallback_font = f
	return f


static func release() -> void:
	_fonts.clear()

# Self-test hook: values here win over the player's settings.
static var overrides := {}


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


# False when Cleanstrike rolled this mod back: stay vanilla.
static func active() -> bool:
	var c := cs()
	return c == null or c.is_loaded(MOD_ID)


static func setting(key: String):
	if overrides.has(key):
		return overrides[key]
	var fallback = DEFAULTS.get(key)
	var c := cs()
	if c == null:
		return fallback
	var v = c.get_setting(MOD_ID, key, fallback)
	# Settings files store every number as a float: convert to the default's type.
	if typeof(fallback) == TYPE_INT and typeof(v) == TYPE_FLOAT:
		return int(round(v))
	if typeof(fallback) == TYPE_FLOAT and typeof(v) == TYPE_INT:
		return float(v)
	return v if typeof(v) == typeof(fallback) else fallback


static func say(text: String) -> void:
	var c := cs()
	if c:
		c.log_message(MOD_ID, text)
	else:
		print("[%s] %s" % [MOD_ID, text])
