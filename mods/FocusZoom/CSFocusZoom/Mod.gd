# Focus Zoom: shared helpers (settings, the focus key, zoom maths).
# Static, so it works without an autoload and survives scene changes.
extends RefCounted

const MOD_ID := "cs_focus_zoom"
const VERSION := "1.0.0"

# Defaults; each can be changed in the Cleanstrike app (cleanstrike.settings.json).
const DEFAULTS := {
	"focus_key": "Mouse4",
	"toggle": false,
	"focus_zoom": 1.8,
	"sprint_zoom": 1.3,
	"ads_zoom": 1.2,
	"zoom_while_ads": true,
	"in_shelters": true,
	"scale_sensitivity": true,
}

const MOUSE_KEYS := {
	"mouse4": MOUSE_BUTTON_XBUTTON1, "mouse5": MOUSE_BUTTON_XBUTTON2,
	"middlemouse": MOUSE_BUTTON_MIDDLE, "middle": MOUSE_BUTTON_MIDDLE,
}

# Self-test hooks: values here win over the player's settings.
static var overrides := {}
static var toggled := false   # toggle mode: currently focused


static func cs() -> Object:
	return Engine.get_meta("Cleanstrike") if Engine.has_meta("Cleanstrike") else null


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


# ---------------------------------------------------------------- the key

static func key_down() -> bool:
	if overrides.has("held"):
		return bool(overrides["held"])
	var name := str(setting("focus_key")).strip_edges()
	var mouse = MOUSE_KEYS.get(name.to_lower().replace(" ", ""))
	if mouse != null:
		return Input.is_mouse_button_pressed(mouse)
	var code := OS.find_keycode_from_string(name)
	return code != KEY_NONE and Input.is_key_pressed(code)


# Is the player focusing right now? (Not in menus, the inventory, decor or
# placement mode, optionally not in shelters, not through a magnified scope.)
static func focusing(gd) -> bool:
	if not active():
		return false
	if gd.interface or gd.settings or gd.decor or gd.isPlacing or gd.freeze:
		return false
	if gd.shelter and not bool(setting("in_shelters")):
		return false
	if gd.isAiming and magnified(gd):
		return false
	if bool(setting("toggle")):
		return toggled
	return key_down()


static func magnified(gd) -> bool:
	return gd.isScoped and float(gd.aimFOV) < float(gd.baseFOV) - 0.5


# ---------------------------------------------------------------- zoom maths

# The field of view the camera should head for. aim_target: what the game
# itself wants (aimFOV while aiming, baseFOV otherwise).
static func target_fov(gd, aim_target: float, focus: bool) -> float:
	var fov := aim_target
	if gd.isAiming and not magnified(gd) and bool(setting("zoom_while_ads")):
		fov /= maxf(1.0, float(setting("ads_zoom")))
	if focus:
		var mult := float(setting("sprint_zoom")) if gd.isRunning else float(setting("focus_zoom"))
		fov /= maxf(1.0, mult)
	return clampf(fov, 5.0, 179.0)


# Mouse sensitivity follows the zoom (focal length), so aiming feels the same.
static func sensitivity_factor(fov: float, base: float) -> float:
	if base <= 0.0:
		return 1.0
	return tan(deg_to_rad(fov) * 0.5) / tan(deg_to_rad(base) * 0.5)
