class_name Armory
extends RefCounted

const TYPES = ["sword", "spear", "axe", "dagger", "hammer", "bow"]
const NAMES = {"sword": "残火の剣", "spear": "鐘守の槍", "axe": "坑夫の斧", "dagger": "風切りの短剣", "hammer": "炉砕きの大槌", "bow": "葦守の弓"}
const RARITIES = ["COMMON", "UNCOMMON", "RARE"]
const COLORS = [Color("bac7c6"), Color("7bd6bb"), Color("edb868")]
const EFFECTS = {"attack": "攻撃力", "hp": "最大HP", "speed": "移動速度", "double_jump": "二段ジャンプ", "wall_break": "壁破壊"}
const CAPS = {"attack": 0.60, "hp": 0.50, "speed": 0.35}
const BASE = {
	"sword": {"damage": 22.0, "reach": 88.0, "duration": 0.36, "hit": 0.10, "impact": 18.0, "height": 56.0},
	"spear": {"damage": 28.0, "reach": 156.0, "duration": 0.52, "hit": 0.17, "impact": 24.0, "height": 28.0},
	"axe": {"damage": 42.0, "reach": 104.0, "duration": 0.72, "hit": 0.26, "impact": 65.0, "height": 82.0},
	"dagger": {"damage": 13.0, "reach": 60.0, "duration": 0.23, "hit": 0.06, "impact": 8.0, "height": 42.0},
	"hammer": {"damage": 58.0, "reach": 80.0, "duration": 0.96, "hit": 0.38, "impact": 110.0, "height": 108.0},
	"bow": {"damage": 24.0, "reach": 900.0, "duration": 0.65, "hit": 0.22, "impact": 10.0, "height": 12.0, "projectile_speed": 900.0},
}
const ROLES = {"sword": "三連撃 / 三段目は威力・崩し強化", "spear": "長い突き / 穂先で威力 +20%", "axe": "重い薙ぎ払い / 盾と体勢を崩す", "dagger": "素早い二連撃 / 二段目の威力 +35%", "hammer": "短射程の振り下ろし / 最大の体勢崩し", "bow": "水平射撃 / 射程900・最初の敵に命中"}

static func attack_profile(weapon: Dictionary, stage: int = 0) -> Dictionary:
	var result: Dictionary = BASE[weapon.kind].duplicate()
	result["kind"] = weapon.kind
	result["stage"] = stage
	result["damage"] = damage(weapon)
	if weapon.kind == "sword" and stage == 2:
		result.damage *= 1.45
		result.impact = 38.0
		result.duration = 0.46
		result.reach = 103.0
	if weapon.kind == "dagger" and stage == 1:
		result.damage *= 1.35
	return result

static func make_weapon(kind: String, rarity: int, region: String, rng: RandomNumberGenerator) -> Dictionary:
	var effects: Array = []
	var all = ["attack", "hp", "speed", "double_jump", "wall_break"]
	var favored = {"forge": ["attack", "hp"], "tower": ["double_jump", "speed", "attack"], "mine": ["wall_break", "hp"], "water": ["speed", "hp", "double_jump"]}.get(region, ["attack", "hp"])
	for slot in 2:
		var candidates: Array = []
		var source: Array = favored if rng.randf() < 0.60 else all.filter(func(e): return e not in favored)
		for effect in source:
			if valid_effect(effect, effects):
				candidates.append(effect)
		if candidates.is_empty():
			for effect in all:
				if valid_effect(effect, effects): candidates.append(effect)
		var picked = candidates[rng.randi_range(0, candidates.size() - 1)]
		effects.append({"id": picked, "value": (0.06 + rarity * 0.035) if picked in CAPS else 1.0})
	return {"kind": kind, "rarity": rarity, "effects": effects}

static func valid_effect(id: String, existing: Array) -> bool:
	for e in existing:
		if e.id == id: return false
		if id not in CAPS and e.id not in CAPS: return false
	return true

static func starter(kind: String) -> Dictionary:
	return {"kind": kind, "rarity": 0, "effects": [{"id": "attack", "value": 0.06}, {"id": "hp", "value": 0.06}]}

static func totals(inventory: Array, permanent: Dictionary = {}) -> Dictionary:
	var result = {"attack": 0.0, "hp": 0.0, "speed": 0.0, "double_jump": false, "wall_break": false}
	for weapon in inventory:
		for effect in weapon.effects:
			if effect.id in CAPS: result[effect.id] += effect.value
			else: result[effect.id] = true
	for stat in CAPS:
		result[stat] = minf(result[stat], CAPS[stat]) + permanent.get(stat, 0.0)
	return result

static func damage(weapon: Dictionary) -> float:
	return BASE[weapon.kind].damage * (1.0 + weapon.rarity * 0.25)

static func describe(weapon: Dictionary) -> String:
	var parts = PackedStringArray()
	for e in weapon.effects:
		parts.append(EFFECTS[e.id] + (" +%s%%" % snappedf(e.value * 100, 0.1) if e.id in CAPS else ""))
	return " / ".join(parts)
