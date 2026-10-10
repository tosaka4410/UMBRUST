class_name RunnerVisual
extends Node2D

const BODY = preload("res://assets/characters/runner-v1/runner-atlas.png")
const WEAPONS = preload("res://assets/characters/runner-v1/weapons-atlas.png")
const CONCEPT = preload("res://assets/characters/runner-v1/concept.png")
const ART_SCALE = 0.20
# Hand-curated atlas cells; the generated atlas is not an exact uniform grid.
# Regions only select from the original transparent PNG, without modifying it.
const REGIONS = [
	Rect2(35, 8, 239, 310), Rect2(368, 8, 231, 310), Rect2(667, 9, 237, 309), Rect2(996, 9, 225, 309),
	Rect2(42, 321, 265, 292), Rect2(333, 325, 260, 289), Rect2(661, 327, 279, 287), Rect2(960, 325, 280, 289),
	Rect2(43, 617, 254, 270), Rect2(342, 624, 247, 287), Rect2(644, 700, 309, 211), Rect2(969, 638, 269, 272),
	Rect2(37, 907, 259, 322), Rect2(333, 921, 298, 308), Rect2(668, 920, 254, 309), Rect2(1005, 919, 211, 312),
]
const PIVOTS = [
	Vector2(211, 314), Vector2(528, 314), Vector2(836, 314), Vector2(1150, 314),
	Vector2(209, 610), Vector2(520, 610), Vector2(836, 610), Vector2(1140, 610),
	Vector2(201, 894), Vector2(522, 908), Vector2(830, 908), Vector2(1127, 906),
	Vector2(201, 1226), Vector2(526, 1226), Vector2(833, 1226), Vector2(1138, 1228),
]
const WEAPON_REGIONS = {"sword": Rect2(37, 132, 1181, 272), "spear": Rect2(31, 572, 1193, 185), "axe": Rect2(56, 800, 1143, 378)}
const WEAPON_GRIPS = {"sword": Vector2(245, 272), "spear": Vector2(290, 632), "axe": Vector2(280, 964)}
const HANDS = [
	Vector2(8, -35), Vector2(10, -35), Vector2(10, -35), Vector2(11, -35),
	Vector2(14, -36), Vector2(11, -36), Vector2(15, -35), Vector2(15, -35),
	Vector2(14, -32), Vector2(10, -34), Vector2(12, -22), Vector2(0, -30),
	Vector2(-12, -57), Vector2(18, -49), Vector2(13, -33), Vector2(0, -35),
]
const ANIMATIONS = {
	"idle": {"frames": [0, 1, 2, 3], "fps": 5.0},
	"run": {"frames": [4, 5, 6, 7], "fps": 11.0},
	"rise": {"frames": [8], "fps": 1.0}, "fall": {"frames": [9], "fps": 1.0},
	"dodge": {"frames": [10], "fps": 1.0}, "hurt": {"frames": [11], "fps": 1.0},
	"attack": {"frames": [12, 13, 14], "fps": 10.0}, "heal": {"frames": [15], "fps": 1.0},
}
var runner: Node2D
var current_animation = "idle"
var frame_index = 0
var animation_clock = 0.0
# Optional art-preview state; never affects the player or combat simulation.
var preview_animation = ""
var preview_weapon = "sword"
var preview_facing = 1.0
var show_weapon = true

func _process(delta: float) -> void:
	var desired = preview_animation if preview_animation != "" else choose_animation()
	if desired != current_animation:
		current_animation = desired
		animation_clock = 0
	elif not is_instance_valid(runner) or runner.hit_pause <= 0: animation_clock += delta
	var spec: Dictionary = ANIMATIONS[current_animation]
	frame_index = spec.frames[int(animation_clock * spec.fps) % spec.frames.size()]
	if current_animation == "attack" and preview_animation == "" and is_instance_valid(runner):
		var progress: float = 1.0 - runner.attack_clock / maxf(0.001, runner.attack_total)
		frame_index = 12 if progress < 0.25 else (13 if progress < 0.65 else 14)
	queue_redraw()

func choose_animation() -> String:
	if not is_instance_valid(runner): return "idle"
	if runner.hurt_flash > 0.10: return "hurt"
	if runner.heal_clock > 0: return "heal"
	if runner.dodge_clock > 0 or runner.skill_clock > 0: return "dodge"
	if runner.attack_clock > 0: return "attack"
	if runner.active and not runner.is_on_floor(): return "rise" if runner.velocity.y < -20 else "fall"
	if absf(runner.velocity.x) > 35: return "run"
	return "idle"

func _draw() -> void:
	var direction: float = runner.facing if is_instance_valid(runner) and preview_animation == "" else preview_facing
	var color = Color.WHITE
	if is_instance_valid(runner) and preview_animation == "" and runner.hurt_flash > 0:
		color = Color(1.0, 0.55, 0.45)
	var region: Rect2 = REGIONS[frame_index]
	var target = Rect2((region.position - PIVOTS[frame_index]) * ART_SCALE, region.size * ART_SCALE)
	draw_set_transform(Vector2.ZERO, 0, Vector2(direction, 1))
	if current_animation == "dodge" and preview_animation == "":
		for i in range(3, 0, -1):
			draw_texture_rect_region(BODY, Rect2(target.position - Vector2(i * 14, 0), target.size), region, Color(0.6, 0.9, 0.86, 0.16 / i))
	draw_texture_rect_region(BODY, target, region, color)
	if show_weapon and current_animation not in ["heal", "hurt"]:
		var kind = preview_weapon
		var attacking = current_animation == "attack"
		var progress = fposmod(animation_clock, 0.6) / 0.6
		if is_instance_valid(runner) and preview_animation == "":
			if attacking and not runner.attack_weapon.is_empty(): kind = runner.attack_weapon.kind
			else:
				var index: int = runner.equipped[0] if runner.equipped[0] >= 0 else runner.equipped[1]
				if index >= 0: kind = runner.inventory[index].kind
			if attacking: progress = 1 - runner.attack_clock / maxf(0.001, runner.attack_total)
		var grip: Vector2 = HANDS[frame_index]
		var angle = 0.16 if kind == "spear" else 0.35
		var length = 68.0 if kind == "sword" else (125.0 if kind == "spear" else 82.0)
		if attacking:
			angle = 0.0 if kind == "spear" else lerpf(-1.5, 1.2, progress)
			if kind == "spear": grip.x += sin(clampf(progress * 2.3, 0, 1) * PI * 0.8) * 16
			elif is_instance_valid(runner) and runner.combo_stage == 1 and kind == "sword": angle = -angle
		draw_weapon(kind, grip, length, angle, direction)
	draw_set_transform(Vector2.ZERO)

func draw_weapon(kind: String, grip: Vector2, length: float, angle: float, direction: float) -> void:
	var region: Rect2 = WEAPON_REGIONS[kind]
	var source_grip: Vector2 = WEAPON_GRIPS[kind]
	var factor = length / (region.end.x - source_grip.x)
	draw_set_transform(grip * Vector2(direction, 1), angle * direction, Vector2(direction, 1))
	draw_texture_rect_region(WEAPONS, Rect2((region.position - source_grip) * factor, region.size * factor), region)

static func portrait() -> AtlasTexture:
	var result = AtlasTexture.new()
	result.atlas = CONCEPT
	result.region = Rect2(340, 70, 460, 520)
	return result
