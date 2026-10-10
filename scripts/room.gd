class_name RustRoom
extends Node2D

@export var room_id = "forge"
var game: Node2D
var data: Dictionary
var objects: Array = []
var drops: Array = []
var opened: Array = []
var enemies: Array = []
var rusted = false
var warned = false
var animation = 0.0
var font: Font
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	data = Atlas.ROOMS[room_id]
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans CJK JP", "Yu Gothic", "sans-serif"])
	rng.seed = room_id.hash()
	add_solid(Rect2(0, 690, 1800, 210))
	add_solid(Rect2(-30, 0, 30, 900))
	add_solid(Rect2(1800, 0, 30, 900))
	for platform in data.platforms:
		add_solid(Rect2(platform[0], platform[1], platform[2], 18), true)
	for entry in data.objects:
		objects.append({"type": entry[0], "position": Vector2(entry[1], 660), "used": false})
	for entry in data.enemies:
		spawn_enemy(entry[0], Vector2(entry[1], 685))

func add_solid(rect: Rect2, one_way: bool = false) -> void:
	var body = StaticBody2D.new()
	body.collision_layer = 1
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.get_center()
	collider.one_way_collision = one_way
	body.add_child(collider)
	add_child(body)

func spawn_enemy(kind: String, point: Vector2) -> RustEnemy:
	var enemy = RustEnemy.new()
	enemy.kind = kind
	enemy.target = game.player
	enemy.position = point
	enemy.defeated.connect(func(e): game.enemy_defeated(e, self))
	enemy.projectile.connect(game.spawn_projectile)
	enemy.hazard.connect(game.spawn_hazard)
	enemy.phase_changed.connect(game.on_phase_changed)
	add_child(enemy)
	enemies.append(enemy)
	return enemy

func _process(delta: float) -> void:
	animation += delta
	rusted = Atlas.is_rusted(room_id, game.elapsed)
	warned = game.elapsed >= 240 and not rusted and room_id != "forge"
	queue_redraw()

func nearest(point: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var best = 95.0
	for drop in drops:
		var distance = point.distance_to(drop.position)
		if distance < best:
			best = distance
			result = {"type": "weapon", "item": drop, "position": drop.position}
	for obj in objects:
		if obj.used and obj.type != "rest": continue
		var distance = point.distance_to(obj.position)
		if distance < best:
			best = distance
			result = obj
	for door in data.exits:
		var pos = Vector2(door[0], door[4] if door.size() > 4 else 640)
		var distance = point.distance_to(pos)
		if distance < best:
			best = distance
			result = {"type": "exit", "door": door, "position": pos}
	return result

func add_drop(weapon: Dictionary, point: Vector2) -> Dictionary:
	var drop = {"weapon": weapon, "position": Vector2(clampf(point.x, 80, 1720), minf(point.y, 654))}
	drops.append(drop)
	return drop

func _draw() -> void:
	if data == null: return
	var tint: Color = {"forge": Color("bd8456"), "tower": Color("72a6ad"), "mine": Color("929b73")}[data.region]
	draw_rect(Rect2(0, 0, 1800, 900), Color("0c151d"))
	# Layered sky, monolithic silhouettes and broken arches; no external assets.
	for i in 12:
		draw_rect(Rect2(0, i * 60, 1800, 61), Color("15242c").lerp(Color("0d141c"), i / 12.0))
	draw_circle(Vector2(1290, 190), 82, Color(tint, 0.065))
	draw_circle(Vector2(1290, 190), 57, Color(tint, 0.08))
	draw_circle(Vector2(1290, 190), 41, Color("566365") if not game.is_night() else Color("746458"))
	for i in 15:
		var x = i * 137.0 + 12
		var top = 310 + sin(i * 8.7 + data.depth) * 100
		draw_rect(Rect2(x, top, 70 + i % 3 * 19, 690 - top), Color("142028"))
		draw_line(Vector2(x - 12, top), Vector2(x + 90, top), Color("1d3037"), 3)
		if data.region == "tower":
			draw_line(Vector2(x + 35, top), Vector2(x + 35, top - 90), Color("1d3037"), 4)
	for i in 6:
		var x = i * 340.0 - 60
		draw_rect(Rect2(x, 235, 38, 455), Color("1e2b30"))
		draw_rect(Rect2(x - 7, 225, 53, 16), Color("29393d"))
		if data.region != "mine":
			draw_arc(Vector2(x + 170, 265), 150, PI, TAU, 30, Color("26363b"), 19)
			draw_line(Vector2(x + 170, 115), Vector2(x + 170, 10), Color("273238"), 2)
		else:
			draw_line(Vector2(x + 22, 250), Vector2(x + 300, 210), Color("34403b"), 18)
			draw_line(Vector2(x + 24, 360), Vector2(x + 110, 235), Color("303a36"), 12)
	# Hanging lanterns and ambient embers.
	for i in 7:
		var x = 250 + i * 238
		var y = 310 + sin(i * 9.0) * 65
		draw_line(Vector2(x, 190), Vector2(x, y), Color("46504b"), 1)
		draw_circle(Vector2(x, y), 38, Color(tint, 0.035))
		draw_circle(Vector2(x, y), 18, Color(tint, 0.08))
		draw_rect(Rect2(x - 3, y - 6, 6, 12), tint)
	for i in 48:
		var p = Vector2(fposmod(i * 197.0 + animation * (4 + i % 4), 1800), fposmod(i * 137.0 - animation * 8, 640))
		draw_circle(p, 1 if i % 3 else 2, Color(tint, 0.15 + sin(animation + i) * 0.08))
	draw_rect(Rect2(0, 690, 1800, 210), Color("131c21"))
	draw_line(Vector2(0, 690), Vector2(1800, 690), Color("64716a"), 3)
	for i in 36:
		var x = i * 53
		draw_line(Vector2(x, 696), Vector2(x + 17, 725 + i % 5 * 13), Color("28352f"), 2)
	for platform in data.platforms:
		var r = Rect2(platform[0], platform[1], platform[2], 18)
		draw_rect(r, Color("34433f"))
		draw_line(r.position, r.position + Vector2(r.size.x, 0), tint.darkened(0.15), 2)
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(10, 18), r.position + Vector2(r.size.x - 10, 18), r.position + Vector2(r.size.x - 36, 40), r.position + Vector2(34, 32)]), Color("1c2a2c"))
	for door in data.exits:
		var p = Vector2(door[0], door[4] if door.size() > 4 else 640)
		var locked: bool = door[3] != "" and door[1] not in opened
		var c = Color("91c4bc") if not locked else Color("c59a63")
		draw_rect(Rect2(p.x - 28, p.y - 45, 56, 93), Color(c, 0.08))
		draw_line(p + Vector2(-28, 48), p + Vector2(-28, -45), c.darkened(0.3), 3)
		draw_line(p + Vector2(28, 48), p + Vector2(28, -45), c.darkened(0.3), 3)
		draw_line(p + Vector2(-28, -45), p + Vector2(28, -45), c.darkened(0.3), 3)
		if locked:
			if door[3] == "wall_break":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-23, 46), p + Vector2(-21, -22), p + Vector2(4, -40), p + Vector2(23, -12), p + Vector2(23, 46)]), Color("62645a"))
				draw_line(p + Vector2(3, -30), p + Vector2(-6, 20), Color("232d2c"), 4)
			else:
				draw_line(p + Vector2(0, 20), p + Vector2(0, -16), c, 2)
				draw_line(p + Vector2(0, -16), p + Vector2(-9, -5), c, 2)
		var text_pos = p + Vector2(-font.get_string_size(door[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x / 2, 74)
		draw_string(font, text_pos, door[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)
		if locked: draw_string(font, p + Vector2(-38, -57), Armory.EFFECTS[door[3]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
	for obj in objects:
		var p: Vector2 = obj.position
		if obj.type == "rest":
			var c = Color("f5ba72") if not rusted and not game.boss_started else Color("565d59")
			draw_circle(p + Vector2(0, -10), 52, Color(c, 0.045))
			draw_rect(Rect2(p.x - 23, p.y + 8, 46, 22), Color("55625c"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 8), p + Vector2(-8, -16), p + Vector2(1, -37 - sin(animation * 5) * 4), p + Vector2(13, -9), p + Vector2(18, 8)]), c)
			draw_string(font, p + Vector2(-30, 56), "休憩の火", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
		elif obj.type == "chest":
			draw_rect(Rect2(p.x - 23, p.y - 3, 46, 30), Color("414841") if obj.used else Color("aa8054"))
			draw_rect(Rect2(p.x - 25, p.y - 10 - (12 if obj.used else 0), 50, 13), Color("535d52") if obj.used else Color("d1a875"))
			draw_rect(Rect2(p.x - 3, p.y, 6, 14), Color("202c2b"))
		elif not obj.used:
			var c = Color("94d6b4") if obj.type == "flask" else Color("e3b971")
			draw_circle(p + Vector2(0, -10), 28, Color(c, 0.08))
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -32), p + Vector2(12, -10), p + Vector2(0, 8), p + Vector2(-12, -10)]), c)
			draw_string(font, p + Vector2(-36, 56), "回復上限 +1" if obj.type == "flask" else "残火の欠片", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
	for drop in drops:
		var p: Vector2 = drop.position + Vector2(0, sin(animation * 3) * 4)
		var c: Color = Armory.COLORS[drop.weapon.rarity]
		draw_line(p + Vector2(0, 22), p + Vector2(0, -54), Color(c, 0.2), 3)
		draw_circle(p, 22, Color(c, 0.09))
		draw_line(p + Vector2(-11, 12), p + Vector2(11, -18), c, 4)
		draw_line(p + Vector2(-13, 0), p + Vector2(1, 10), c, 3)
		draw_string(font, p + Vector2(-40, -35), Armory.NAMES[drop.weapon.kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
	if rusted:
		draw_rect(Rect2(0, 0, 1800, 900), Color(0.27, 0.10, 0.16, 0.14))
		for i in 35:
			var x = i * 57.0
			var points = PackedVector2Array([Vector2(x, 900), Vector2(x + 23, 680), Vector2(x - 15, 620), Vector2(x + 32, 540 - i % 4 * 65)])
			draw_polyline(points, Color("080d13"), 7)
			draw_polyline(points, Color(0.65, 0.24, 0.26, 0.5), 1)
