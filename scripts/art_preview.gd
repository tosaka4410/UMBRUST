extends Control

var font: Font

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans CJK JP", "Yu Gothic", "sans-serif"])
	var backdrop = ColorRect.new()
	backdrop.color = Color("0c151b")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var concept = Sprite2D.new()
	concept.texture = RunnerVisual.CONCEPT
	concept.centered = false
	concept.position = Vector2(28, 28)
	concept.scale = Vector2(430.0 / concept.texture.get_width(), 645.0 / concept.texture.get_height())
	add_child(concept)
	caption("UMBRUST / 疾走者", Vector2(30, 696), 27, Color("e8b475"))
	caption("白い兜、煤色の外套、灯火色のスカーフ。", Vector2(30, 746), 15, Color("a7bbb5"))
	caption("CHARACTER ART 01 / GAME-READY ATLAS", Vector2(30, 780), 11, Color("718b8d"))
	caption("疾走者  /  ANIMATION STUDY", Vector2(503, 30), 29, Color("e4eade"))
	caption("16ポーズ・8状態  /  透過PNGを使用  /  左右反転・武器別レイヤー", Vector2(504, 78), 14, Color("94b0ae"))
	var states = ["idle", "run", "rise", "fall", "dodge", "hurt", "attack", "heal"]
	var names = ["待機", "走行", "上昇", "落下", "回避", "被弾", "攻撃", "回復"]
	for i in states.size():
		var x = 498 + (i % 4) * 232
		var y = 124 + floori(i / 4.0) * 283
		var panel = Panel.new()
		panel.position = Vector2(x, y)
		panel.size = Vector2(220, 266)
		var skin = StyleBoxFlat.new()
		skin.bg_color = Color("15232b")
		skin.border_color = Color("34464a")
		skin.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", skin)
		add_child(panel)
		var actor = RunnerVisual.new()
		actor.preview_animation = states[i]
		actor.show_weapon = false
		actor.position = Vector2(x + 120, y + 216)
		actor.scale = Vector2(2.0, 2.0)
		add_child(actor)
		caption("%02d / %s" % [i + 1, names[i]], Vector2(x + 12, y + 235), 14, Color("c4cfbe"))
	caption("EQUIPMENT / 持ち替え用の透過素材", Vector2(506, 710), 15, Color("e8b475"))
	for i in 3:
		var kind: String = Armory.TYPES[i]
		var atlas = AtlasTexture.new()
		atlas.atlas = RunnerVisual.WEAPONS
		atlas.region = RunnerVisual.WEAPON_REGIONS[kind]
		var item = Sprite2D.new()
		item.texture = atlas
		item.centered = false
		var factor = minf(276.0 / atlas.region.size.x, 89.0 / atlas.region.size.y)
		item.scale = Vector2(factor, factor)
		item.position = Vector2(505 + i * 307, 753 + (89 - atlas.region.size.y * factor) / 2)
		add_child(item)
		caption(Armory.NAMES[kind], Vector2(506 + i * 307, 848), 13, Color("b5c3bc"))
	if "--capture-art" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/private/tmp/umbrust-runner-art.png")
		get_tree().quit()

func caption(text: String, point: Vector2, font_size: int, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
