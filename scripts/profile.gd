class_name Profile
extends RefCounted

var currency = 0
var unlocked: Array = ["sword"]
var levels = {"attack": 0, "hp": 0, "speed": 0}
var equipped: Array = ["attack", "hp", "speed"]
var selected = "sword"
var clears = 0
var bindings: Dictionary = {}
var screen_shake = true
var path = "user://profile.cfg"

func load_data() -> void:
	var file = ConfigFile.new()
	if file.load(path) != OK: return
	currency = maxi(0, int(file.get_value("profile", "currency", 0)))
	unlocked = file.get_value("profile", "unlocked", ["sword"]).filter(func(k): return k in Armory.TYPES)
	if "sword" not in unlocked: unlocked.append("sword")
	selected = str(file.get_value("profile", "selected", "sword"))
	if selected not in unlocked: selected = "sword"
	var stored = file.get_value("profile", "levels", {})
	for stat in levels: levels[stat] = clampi(int(stored.get(stat, 0)), 0, 5)
	equipped = file.get_value("profile", "equipped", ["attack", "hp", "speed"]).filter(func(k): return k in levels).slice(0, 3)
	clears = int(file.get_value("profile", "clears", 0))
	bindings = file.get_value("controls", "bindings", {})
	screen_shake = bool(file.get_value("display", "screen_shake", true))

func save_data() -> Error:
	var file = ConfigFile.new()
	for key in ["currency", "unlocked", "selected", "levels", "equipped", "clears"]:
		file.set_value("profile", key, get(key))
	file.set_value("controls", "bindings", bindings)
	file.set_value("display", "screen_shake", screen_shake)
	return file.save(path)

func bonuses() -> Dictionary:
	var result = {}
	for stat in levels: result[stat] = levels[stat] * 0.01 if stat in equipped else 0.0
	return result

func upgrade_cost(stat: String) -> int:
	return 15 + levels[stat] * 10

func buy_upgrade(stat: String) -> bool:
	if levels[stat] >= 5 or currency < upgrade_cost(stat): return false
	currency -= upgrade_cost(stat)
	levels[stat] += 1
	save_data()
	return true
