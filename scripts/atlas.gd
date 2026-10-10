class_name Atlas
extends RefCounted

# All mandatory edges lie on the floor. Skill gates only lead to optional leaves.
const ROOMS = {
	"forge": {"name": "炉跡 / 帰還の炉", "region": "forge", "depth": 0, "map": Vector2(0, 0), "exits": [[160, "mine_entry", "← 廃坑へ", ""], [1630, "forge_road", "鐘楼への街道 →", ""], [1310, "water_entry", "↓ 沈水路へ", ""]], "enemies": [], "objects": [["rest", 600], ["chest", 1050]], "platforms": [[850, 560, 240], [1190, 455, 220]]},
	"forge_road": {"name": "炉跡 / 灰の街道", "region": "forge", "depth": 1, "map": Vector2(1, 0), "exits": [[120, "forge", "← 帰還の炉", ""], [1660, "tower_base", "鐘楼 →", ""]], "enemies": [["crawler", 620], ["guard", 1220]], "objects": [["chest", 950]], "platforms": [[470, 555, 220], [1000, 505, 240]]},
	"tower_base": {"name": "鐘楼 / 風の回廊", "region": "tower", "depth": 2, "map": Vector2(2, 0), "exits": [[120, "forge_road", "← 炉跡への道", ""], [1660, "tower_mid", "上層へ →", "", 170], [1250, "tower_gallery", "回廊の分岐 →", ""]], "enemies": [["wisp", 600], ["crawler", 1150]], "objects": [["rest", 330], ["chest", 1380]], "platforms": [[400, 565, 240], [710, 450, 240], [1020, 335, 240], [1330, 220, 390]]},
	"tower_mid": {"name": "鐘楼 / 鐘守の間", "region": "tower", "depth": 3, "map": Vector2(2, -1), "exits": [[120, "tower_base", "← 風の回廊", ""], [1660, "tower_top", "頂の祭壇 →", ""], [880, "tower_bonus", "↑ 風渡りの書庫", "double_jump", 395]], "enemies": [["bellkeeper", 1270]], "objects": [["flask", 440]], "platforms": [[660, 445, 410]]},
	"tower_top": {"name": "鐘楼 / 頂の祭壇", "region": "tower", "depth": 4, "map": Vector2(2, -2), "exits": [[120, "tower_mid", "← 鐘守の間", ""]], "enemies": [["strong", 1160]], "objects": [["chest", 1560]], "platforms": [[450, 550, 220], [1370, 530, 230]]},
	"tower_bonus": {"name": "鐘楼 / 風渡りの書庫", "region": "tower", "depth": 4, "map": Vector2(3, -1), "exits": [[120, "tower_mid", "← 基本移動で帰還", ""]], "enemies": [["wisp", 960]], "objects": [["chest", 1380], ["currency", 650]], "platforms": [[600, 550, 240], [1020, 440, 240]]},
	"mine_entry": {"name": "廃坑 / 砕けた坑道", "region": "mine", "depth": 1, "map": Vector2(-1, 0), "exits": [[1660, "forge", "帰還の炉 →", ""], [120, "mine_cross", "← 掘削跡", ""], [1160, "mine_siding", "↓ 運搬線へ", ""]], "enemies": [["guard", 580], ["crawler", 1030]], "objects": [["rest", 1410], ["chest", 790]], "platforms": [[380, 555, 240], [980, 510, 300]]},
	"mine_cross": {"name": "廃坑 / 掘削跡", "region": "mine", "depth": 2, "map": Vector2(-2, 0), "exits": [[1660, "mine_entry", "砕けた坑道 →", ""], [120, "mine_deep", "← 鉱脈の底", ""], [860, "mine_bonus", "↓ 黒岩の宝物庫", "wall_break"]], "enemies": [["guard", 470], ["wisp", 1250]], "objects": [["flask", 1470]], "platforms": [[330, 535, 250], [1050, 500, 260]]},
	"mine_deep": {"name": "廃坑 / 鉱脈の底", "region": "mine", "depth": 3, "map": Vector2(-3, 0), "exits": [[1660, "mine_cross", "掘削跡 →", ""]], "enemies": [["foreman", 800]], "objects": [["chest", 300]], "platforms": [[440, 540, 220], [1180, 540, 240]]},
	"mine_bonus": {"name": "廃坑 / 黒岩の宝物庫", "region": "mine", "depth": 3, "map": Vector2(-2, 1), "exits": [[1660, "mine_cross", "基本移動で帰還 →", ""]], "enemies": [["crawler", 880]], "objects": [["chest", 410], ["currency", 630]], "platforms": [[1020, 535, 260]]},
	"tower_gallery": {"name": "鐘楼 / 風切り回廊", "region": "tower", "width": 2200, "depth": 3, "map": Vector2(3, 0), "exits": [[120, "tower_base", "← 風の回廊", ""], [2060, "tower_bridge", "外鐘橋 →", ""]], "enemies": [["crawler", 820], ["wisp", 1340], ["guard", 1800]], "objects": [["cache", 430, "dagger"], ["chest", 1580]], "platforms": [[580, 560, 280], [960, 445, 260], [1430, 530, 320]]},
	"tower_bridge": {"name": "鐘楼 / 外鐘橋", "region": "tower", "width": 2600, "depth": 4, "map": Vector2(4, 0), "exits": [[120, "tower_gallery", "← 風切り回廊", ""]], "enemies": [["wisp", 760], ["bellkeeper", 1700], ["wisp", 2300]], "objects": [["currency", 500], ["chest", 2460]], "platforms": [[550, 550, 340], [1090, 430, 310], [1670, 545, 320], [2160, 475, 280]]},
	"mine_siding": {"name": "廃坑 / 錆びた運搬線", "region": "mine", "width": 2300, "depth": 2, "map": Vector2(-1, 1), "exits": [[2160, "mine_entry", "砕けた坑道 →", ""], [120, "mine_foundry", "← 地底鋳造所", ""]], "enemies": [["guard", 1650], ["crawler", 1200], ["crawler", 630]], "objects": [["cache", 1950, "hammer"], ["currency", 940]], "platforms": [[450, 550, 320], [1030, 470, 300], [1600, 560, 310]]},
	"mine_foundry": {"name": "廃坑 / 地底鋳造所", "region": "mine", "width": 2400, "depth": 3, "map": Vector2(-1, 2), "exits": [[2260, "mine_siding", "運搬線へ →", ""]], "enemies": [["guard", 1800], ["foreman", 980]], "objects": [["rest", 2060], ["chest", 350], ["currency", 600]], "platforms": [[380, 540, 310], [1040, 440, 300], [1640, 550, 280]]},
	"water_entry": {"name": "沈水路 / 葦の堤道", "region": "water", "width": 2000, "depth": 1, "map": Vector2(0, 1), "exits": [[120, "forge", "← 帰還の炉", ""], [1860, "water_junction", "水門分岐 →", ""]], "enemies": [["crawler", 1050], ["wisp", 1500]], "objects": [["rest", 330], ["cache", 630, "bow"]], "platforms": [[820, 550, 280], [1250, 445, 260], [1600, 560, 240]]},
	"water_junction": {"name": "沈水路 / 水門分岐", "region": "water", "width": 2400, "depth": 2, "map": Vector2(1, 1), "exits": [[120, "water_entry", "← 葦の堤道", ""], [2260, "water_sluice", "沈んだ水門 →", ""]], "enemies": [["guard", 720], ["wisp", 1330], ["crawler", 1900]], "objects": [["chest", 1050], ["currency", 2090]], "platforms": [[430, 565, 310], [930, 450, 310], [1460, 335, 300], [1850, 550, 310]]},
	"water_sluice": {"name": "沈水路 / 沈んだ水門", "region": "water", "width": 2200, "depth": 3, "map": Vector2(2, 1), "exits": [[120, "water_junction", "← 水門分岐", ""], [1720, "water_bonus", "↑ 貯水礼拝堂", "double_jump", 395]], "enemies": [["foreman", 1000], ["wisp", 1950]], "objects": [["rest", 350], ["chest", 1400]], "platforms": [[620, 550, 260], [1520, 445, 430]]},
	"water_bonus": {"name": "沈水路 / 貯水礼拝堂", "region": "water", "depth": 4, "map": Vector2(2, 2), "exits": [[120, "water_sluice", "← 基本移動で帰還", ""]], "enemies": [["wisp", 920]], "objects": [["chest", 1370], ["chest", 1600], ["currency", 650]], "platforms": [[550, 550, 270], [990, 440, 300]]},
}

static func rust_time(room_id: String) -> float:
	var depth: int = ROOMS[room_id].depth
	return INF if depth == 0 else 300.0 + (4 - depth) * 30.0

static func is_rusted(room_id: String, elapsed: float) -> bool:
	return elapsed >= rust_time(room_id)

static func room_width(id: String) -> float:
	return float(ROOMS[id].get("width", 1800))

static func reachable(start: String, allow_gates: bool = false) -> Array:
	var visited: Array = [start]
	var pending: Array = [start]
	while not pending.is_empty():
		var id = pending.pop_front()
		for door in ROOMS[id].exits:
			if (allow_gates or door[3] == "") and door[1] not in visited:
				visited.append(door[1])
				pending.append(door[1])
	return visited

static func validate_routes() -> bool:
	for id in ROOMS:
		for door in ROOMS[id].exits:
			if not ROOMS.has(door[1]): return false
			if door[0] < 60 or door[0] > room_width(id) - 60: return false
	var mandatory = reachable("forge")
	if reachable("forge", true).size() != ROOMS.size(): return false
	for id in ROOMS:
		if "bonus" not in id and id not in mandatory: return false
		if "forge" not in reachable(id): return false
	return true
