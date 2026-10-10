class_name GameUI
extends CanvasLayer

const INK = Color("101a21")
const PANEL = Color("15232b")
const LINE = Color("34464a")
const TEXT = Color("e2e8dc")
const MUTED = Color("96a9a8")
const GOLD = Color("e8b779")
const MINT = Color("8bd2bc")
var game: Node2D
var root: Control
var hud: Control
var overlay: Control
var home: Control
var overlay_kind = ""
var listening = ""
var location: Label
var phase: Label
var health: ProgressBar
var hp_label: Label
var weapon_label: Label
var flask_label: Label
var currency_label: Label
var boss_label: Label
var boss_bar: ProgressBar
var boss_poise: ProgressBar
var boss_intent: Label
var prompt: Label
var toast: Label
var toast_time = 0.0
var selected_index = 0
var selected_cell = 0
var swap_source = -1
var inventory_details: VBoxContainer
var inventory_cells: Array[Button] = []
var map_canvas: Control
var inventory_status: Label
var font: Font

func _ready() -> void:
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans CJK JP", "Yu Gothic", "sans-serif"])
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_stylebox("normal", "Button", style(PANEL, LINE))
	theme.set_stylebox("hover", "Button", style(Color("24373c"), GOLD))
	theme.set_stylebox("pressed", "Button", style(Color("334942"), MINT))
	theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), GOLD, 2))
	theme.set_stylebox("disabled", "Button", style(Color("111b21"), Color("223136")))
	theme.set_color("font_disabled_color", "Button", Color("617172"))
	root.theme = theme
	create_hud()
	toast = label(root, "", 18, GOLD)
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast.offset_left = 140
	toast.offset_right = -140
	toast.offset_top = 105
	toast.offset_bottom = 146
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 2)

func style(background: Color, border: Color = LINE, width: int = 1) -> StyleBoxFlat:
	var skin = StyleBoxFlat.new()
	skin.bg_color = background
	skin.border_color = border
	skin.set_border_width_all(width)
	skin.set_corner_radius_all(4)
	skin.content_margin_left = 16
	skin.content_margin_right = 16
	skin.content_margin_top = 10
	skin.content_margin_bottom = 10
	return skin

func label(parent: Node, text: String, size: int = 16, color: Color = TEXT) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable, height: float = 42) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = height
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func box(parent: Node, rect: Rect2, background: Color = PANEL) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", style(background))
	parent.add_child(panel)
	return panel

func column(parent: Node, separation: int = 12) -> VBoxContainer:
	var node = VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

func row(parent: Node, separation: int = 12) -> HBoxContainer:
	var node = HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

func spacer(parent: Node, height: float = 16) -> void:
	var node = Control.new()
	node.custom_minimum_size.y = height
	parent.add_child(node)

func create_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top = box(hud, Rect2(24, 20, 1392, 78), Color(0.06, 0.1, 0.13, 0.95))
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 20
	top.offset_bottom = 98
	var top_row = row(top, 24)
	var brand = column(top_row, 0)
	label(brand, "U M B R U S T", 23, GOLD)
	label(brand, "灰の先へ、灯火を。", 11, MUTED)
	var separator = VSeparator.new()
	top_row.add_child(separator)
	var place = column(top_row, 4)
	place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	location = label(place, "", 19)
	phase = label(place, "", 13, MUTED)
	var vitality = column(top_row, 4)
	vitality.custom_minimum_size.x = 280
	hp_label = label(vitality, "", 14, MINT)
	health = ProgressBar.new()
	health.custom_minimum_size = Vector2(280, 9)
	health.show_percentage = false
	health.add_theme_stylebox_override("background", style(Color("293337"), Color.TRANSPARENT, 0))
	health.add_theme_stylebox_override("fill", style(MINT, Color.TRANSPARENT, 0))
	vitality.add_child(health)
	currency_label = label(top_row, "", 15, GOLD)
	var bottom = box(hud, Rect2(24, 798, 1392, 80), Color(0.06, 0.1, 0.13, 0.95))
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -102
	bottom.offset_bottom = -22
	var bottom_row = row(bottom, 28)
	weapon_label = label(bottom_row, "", 15)
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flask_label = label(bottom_row, "", 14, MINT)
	var commands = column(bottom_row, 1)
	button(commands, "武器管理 / Tab · Y", show_inventory, 28).focus_mode = Control.FOCUS_NONE
	button(commands, "全体マップ / M · View", show_map, 28).focus_mode = Control.FOCUS_NONE
	prompt = label(hud, "", 17, GOLD)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -149
	prompt.offset_bottom = -112
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label = label(hud, "", 18, GOLD)
	boss_label.position = Vector2(490, 153)
	boss_label.size.x = 460
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(490, 185)
	boss_bar.size = Vector2(460, 8)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("fill", style(Color("ce8567"), Color.TRANSPARENT, 0))
	boss_bar.add_theme_stylebox_override("background", style(INK, Color.TRANSPARENT, 0))
	hud.add_child(boss_bar)
	boss_poise = ProgressBar.new()
	boss_poise.position = Vector2(490, 217)
	boss_poise.size = Vector2(460, 5)
	boss_poise.show_percentage = false
	var poise_fill = StyleBoxFlat.new()
	poise_fill.bg_color = MINT
	var poise_back = StyleBoxFlat.new()
	poise_back.bg_color = LINE
	boss_poise.add_theme_stylebox_override("fill", poise_fill)
	boss_poise.add_theme_stylebox_override("background", poise_back)
	hud.add_child(boss_poise)
	boss_poise.size = Vector2(460, 5)
	boss_intent = label(hud, "", 14, GOLD)
	boss_intent.position = Vector2(370, 229)
	boss_intent.size.x = 700
	boss_intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func show_home() -> void:
	close_overlay()
	if is_instance_valid(home): home.queue_free()
	hud.hide()
	home = Control.new()
	home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(home)
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.05, 0.07, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home.add_child(shade)
	var layout = HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 90
	layout.offset_right = -90
	layout.offset_top = 80
	layout.offset_bottom = -75
	layout.add_theme_constant_override("separation", 70)
	home.add_child(layout)
	var left = column(layout, 12)
	left.custom_minimum_size.x = 640
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(left, "A S H   /   I R O N   /   E M B E R", 14, GOLD)
	spacer(left, 36)
	label(left, "UMBRUST", 79, TEXT)
	label(left, "アンブラスト", 18, GOLD)
	spacer(left, 16)
	label(left, "黒錆が、夜を連れてくる。", 29)
	label(left, "6本の武器に、土地の記憶を宿す。\n鐘楼を登るか、廃坑を掘り進むか。\n灯火が消える前に、帰還の炉へ。", 18, MUTED)
	spacer(left, 28)
	var start = button(left, "探索に出発する    →", func(): game.start_run(), 61)
	start.add_theme_font_size_override("font_size", 22)
	start.grab_focus()
	button(left, "短縮テストで出発  /  70秒で夜", func(): game.start_run(true), 42)
	var actions = row(left)
	button(actions, "操作設定", show_settings).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(actions, "ゲーム終了", func(): get_tree().quit()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(left, "矢印キー：選択を移動   /   Enter：決定", 14, MUTED)
	label(left, "PROTOTYPE 0.2   /   COMBAT UPDATE   /   SOLO", 12, MUTED)
	var right_panel = PanelContainer.new()
	right_panel.custom_minimum_size.x = 420
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", style(Color(0.08, 0.13, 0.16, 0.95)))
	layout.add_child(right_panel)
	var right = column(right_panel, 12)
	var character_header = row(right, 14)
	var portrait = TextureRect.new()
	portrait.texture = RunnerVisual.portrait()
	portrait.custom_minimum_size = Vector2(76, 86)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	character_header.add_child(portrait)
	var identity = column(character_header, 7)
	label(identity, "出発の準備 / 疾走者", 21, GOLD)
	label(identity, "灯火を携え、黒錆を駆ける。", 14, MUTED)
	label(identity, "残火の欠片   %d" % game.profile.currency, 19, MINT)
	spacer(right, 4)
	label(right, "01  初期武器", 16)
	for kind in Armory.TYPES:
		var unlocked: bool = kind in game.profile.unlocked
		var text = ("● " if game.profile.selected == kind else "○ ") + Armory.NAMES[kind]
		if not unlocked: text += "   解放 / 20欠片"
		var b = button(right, text, func():
			if kind in game.profile.unlocked:
				game.profile.selected = kind
			elif game.profile.currency >= 20:
				game.profile.currency -= 20
				game.profile.unlocked.append(kind)
				game.profile.selected = kind
			game.profile.save_data()
			show_home())
		b.disabled = not unlocked and game.profile.currency < 20
	label(right, "コモン / 固定付与：攻撃力・最大HP +6%", 12, MUTED)
	spacer(right, 4)
	label(right, "02  永続効果  /  最大3つ", 16)
	for stat in ["attack", "hp", "speed"]:
		var r = row(right, 7)
		var toggle = button(r, ("● " if stat in game.profile.equipped else "○ ") + Armory.EFFECTS[stat] + " +%d%%" % game.profile.levels[stat], func():
			if stat in game.profile.equipped: game.profile.equipped.erase(stat)
			elif game.profile.equipped.size() < 3: game.profile.equipped.append(stat)
			game.profile.save_data()
			show_home())
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var upgrade = button(r, "+1%% / %d" % game.profile.upgrade_cost(stat) if game.profile.levels[stat] < 5 else "MAX", func():
			game.profile.buy_upgrade(stat)
			show_home())
		upgrade.disabled = game.profile.levels[stat] >= 5 or game.profile.currency < game.profile.upgrade_cost(stat)
	label(right, "各ステータスの永続補正は最大 +5%。\n周回で集めた欠片は、敗北しても残ります。", 13, MUTED)
	spacer(right, 4)
	label(right, "03  周回の流れ", 16)
	label(right, "昼：探索7分 → 夜：炉跡で決戦\n4分に予告 / 5分に侵食開始\n夜ボスに制限時間はありません。", 14, MUTED)

func show_run() -> void:
	if is_instance_valid(home):
		home.queue_free()
		home = null
	close_overlay()
	hud.show()

func new_overlay(kind: String, rect: Rect2) -> VBoxContainer:
	close_overlay(false)
	overlay_kind = kind
	game.player.ui_captures_input = true
	game.player.ui_allows_movement = kind == "inventory"
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	var panel = box(overlay, rect, Color(0.055, 0.09, 0.12, 0.98))
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	var content = column(scroll, 9)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content

func close_overlay(clear_pickup: bool = true) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
		overlay = null
	overlay_kind = ""
	listening = ""
	map_canvas = null
	inventory_status = null
	inventory_details = null
	inventory_cells.clear()
	game.player.ui_captures_input = false
	game.player.ui_allows_movement = false
	if clear_pickup: swap_source = -1
	if clear_pickup: game.pickup = {}

func show_inventory() -> void:
	if not game.running: return
	game.player.sync_weapon_slots()
	var content = new_overlay("inventory", Rect2(170, 151, 1225, 624))
	var header = row(content)
	label(header, "武器管理", 24, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "閉じる / Tab", close_overlay, 35)
	inventory_status = label(content, "", 13, Color("ec967a"))
	label(content, "A / D：キャラクター移動  ·  矢印キー：枠を選択  ·  Enter：持ち上げ / 入れ替え  ·  Esc：取消", 13, MUTED)
	label(content, "左上＝武器A / 左下＝武器B  ·  所持 %d / 6本すべての付与効果が有効" % game.player.inventory.size(), 13, MINT)
	var columns = row(content, 22)
	var grid_column = column(columns, 14)
	grid_column.custom_minimum_size.x = 650
	grid_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	grid_column.add_child(grid)
	inventory_details = column(columns, 10)
	inventory_details.custom_minimum_size.x = 445
	for cell in 6:
		var index: int = game.player.weapon_slots[cell]
		var title = "武器A  /  " + game.key_hint("attack_a") if cell == 0 else ("武器B  /  " + game.key_hint("attack_b") if cell == 3 else "所持枠")
		var text = title + "\n\n"
		if index >= 0:
			var weapon: Dictionary = game.player.inventory[index]
			text += Armory.NAMES[weapon.kind] + "\n" + Armory.RARITIES[weapon.rarity] + "  /  威力 %d" % Armory.damage(weapon)
		else:
			text += "空き枠\n移動先に選択できます"
		if swap_source == cell: text += "\n移動元"
		var b = button(grid, text, func(): activate_inventory_cell(cell), 143)
		b.name = "WeaponCell%d" % cell
		b.custom_minimum_size.x = 210
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", style(Color("243332") if cell in [0, 3] else PANEL, GOLD if swap_source == cell else LINE, 2 if swap_source == cell else 1))
		b.focus_entered.connect(func():
			selected_cell = cell
			selected_index = game.player.weapon_slots[cell]
			refresh_inventory_details())
		inventory_cells.append(b)
	for cell in 6:
		var b = inventory_cells[cell]
		if cell % 3 > 0: b.focus_neighbor_left = b.get_path_to(inventory_cells[cell - 1])
		if cell % 3 < 2: b.focus_neighbor_right = b.get_path_to(inventory_cells[cell + 1])
		if cell >= 3: b.focus_neighbor_top = b.get_path_to(inventory_cells[cell - 3])
		else: b.focus_neighbor_bottom = b.get_path_to(inventory_cells[cell + 3])
	label(grid_column, "武器を選んでEnter → 移動先を選んでEnter。\nマウスでも2つの枠を順にクリックして入れ替えられます。\nパッド：左スティックで移動 / 十字キーで選択 / Aで決定。", 13, MUTED)
	if swap_source >= 0:
		button(grid_column, "入れ替えを取り消す / Esc", cancel_inventory_swap, 35)
	selected_cell = clampi(selected_cell, 0, 5)
	inventory_cells[selected_cell].grab_focus()

func activate_inventory_cell(cell: int) -> void:
	if swap_source < 0:
		if game.player.weapon_slots[cell] < 0: return
		swap_source = cell
	else:
		game.player.swap_weapon_slots(swap_source, cell)
		swap_source = -1
	selected_cell = cell
	show_inventory()

func cancel_inventory_swap() -> void:
	swap_source = -1
	show_inventory()

func refresh_inventory_details() -> void:
	if not is_instance_valid(inventory_details): return
	for child in inventory_details.get_children():
		inventory_details.remove_child(child)
		child.queue_free()
	var side = inventory_details
	var selected: Dictionary = game.player.inventory[selected_index] if selected_index >= 0 else {}
	if not selected.is_empty():
		label(side, Armory.NAMES[selected.kind] + "  /  " + Armory.RARITIES[selected.rarity], 17, GOLD)
		label(side, Armory.describe(selected), 13, MUTED)
		label(side, Armory.ROLES[selected.kind], 13, MINT)
	else:
		label(side, "空き枠", 17, MUTED)
	if not game.pickup.is_empty():
		var weapon: Dictionary = game.pickup.weapon
		label(side, "拾う武器：%s · %s · 威力%d" % [Armory.NAMES[weapon.kind], Armory.RARITIES[weapon.rarity], Armory.damage(weapon)], 15, GOLD)
		label(side, Armory.describe(weapon), 13)
		var proposed: Array = game.player.inventory.duplicate()
		var full: bool = proposed.size() >= 6
		if full: proposed[selected_index] = weapon
		else: proposed.append(weapon)
		var next = Armory.totals(proposed, game.player.permanent)
		var stats: Dictionary = game.player.stats
		var comparison = "交換後：" if full else "取得後："
		comparison += "\n攻撃 %+.1f%% / HP %+.1f%% / 速度 %+.1f%%" % [(next.attack - stats.attack) * 100, (next.hp - stats.hp) * 100, (next.speed - stats.speed) * 100]
		if full: comparison += "\n武器威力 %+.0f" % (Armory.damage(weapon) - Armory.damage(selected))
		label(side, comparison, 13, MINT)
		var lost = PackedStringArray()
		for effect in ["double_jump", "wall_break"]:
			if stats[effect] and not next[effect]: lost.append(Armory.EFFECTS[effect])
		label(side, "失う移動能力：" + ("なし" if lost.is_empty() else " / ".join(lost)), 13, GOLD if lost.is_empty() else Color("ed8b75"))
		button(side, "選択中の枠と交換" if full else "武器を拾う", func():
			swap_source = -1
			game.take_pickup(selected_index), 38)
	elif not selected.is_empty():
		button(side, "選択中の武器を地面に置く", func():
			swap_source = -1
			game.drop_weapon(selected_index), 35)
	var totals: Dictionary = game.player.stats
	label(side, "所持武器の合計  攻撃 +%.1f%% / HP +%.1f%% / 速度 +%.1f%%" % [totals.attack * 100, totals.hp * 100, totals.speed * 100], 12, MINT)
	label(side, "能力：" + ("二段ジャンプ  " if totals.double_jump else "") + ("壁破壊" if totals.wall_break else "") + ("なし" if not totals.double_jump and not totals.wall_break else ""), 13, MINT)
	label(side, "管理中も移動でき、敵・時間・侵食は止まりません。\n攻撃・回避・回復は画面を閉じてから行います。\n手放した武器は地面に残り、再取得できます。", 12, MUTED)

func show_map() -> void:
	if not game.running: return
	var content = new_overlay("map", Rect2(215, 155, 1010, 596))
	var header = row(content)
	label(header, "土地の記憶", 26, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "閉じる / M", close_overlay, 36).grab_focus()
	label(content, "青緑：安全  /  黄：侵食予告  /  赤：侵食済み  /  点線：能力を使う寄り道", 14, MUTED)
	var canvas = MapCanvas.new()
	canvas.game = game
	canvas.font = font
	canvas.custom_minimum_size = Vector2(950, 325)
	content.add_child(canvas)
	map_canvas = canvas
	var info = row(content, 35)
	label(info, "廃坑\n壁破壊・最大HP\n横道と分岐を探索", 15, MUTED)
	label(info, "炉跡\n攻撃力・最大HP（弱い偏り）\n出発と夜の決戦", 15, GOLD)
	label(info, "鐘楼\n二段ジャンプ・速度・攻撃力\n高所の寄り道 / 任意の強ボス", 15, MUTED)
	label(content, "地図を開いていても時間は進む。夜は自動転送されません。", 14, Color("e6997c"))

func show_settings() -> void:
	var content = new_overlay("settings", Rect2(300, 117, 840, 674))
	var header = row(content)
	label(header, "操作設定", 25, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "閉じる / Esc", close_overlay, 36).grab_focus()
	label(content, "変更を押し、キー / パッドボタン / スティックを入力。Escで取消。", 14, MUTED)
	label(content, "探索中は、この画面でも時間・敵・黒錆が進みます。", 14, Color("e6997c"))
	var shake_toggle = CheckButton.new()
	shake_toggle.text = "打撃時の画面揺れ"
	shake_toggle.button_pressed = game.profile.screen_shake
	shake_toggle.toggled.connect(func(enabled):
		game.profile.screen_shake = enabled
		game.profile.save_data())
	content.add_child(shake_toggle)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 7)
	content.add_child(grid)
	for action in game.INPUTS:
		var events = PackedStringArray()
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: events.append(OS.get_keycode_string(event.physical_keycode))
			elif event is InputEventJoypadButton: events.append("Pad %d" % event.button_index)
			else: events.append("Stick")
		label(grid, game.INPUTS[action][0] + "   " + " / ".join(events), 14).custom_minimum_size.x = 520
		var b = button(grid, "変更", func(): pass, 32)
		b.pressed.connect(func():
			listening = action
			b.text = "入力待ち…")
	var actions = row(content)
	button(actions, "初期配置へ戻す", func():
		game.profile.bindings.clear()
		game.profile.save_data()
		game.setup_input()
		show_settings()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if game.running:
		button(actions, "周回を終了して帰還", func(): game.finish_run(false)).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func handle_inventory_input(event: InputEvent) -> bool:
	if overlay_kind != "inventory" or listening != "": return false
	# Keep the left stick for movement; only the D-pad navigates the UI.
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]: return true
	if event is InputEventKey:
		if event.keycode == KEY_SPACE: return true
		if event.pressed and event.keycode == KEY_ESCAPE:
			if swap_source >= 0: cancel_inventory_swap()
			else: close_overlay()
			return true
	return false

func _input(event: InputEvent) -> void:
	if listening == "": return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		listening = ""
		show_settings()
		get_viewport().set_input_as_handled()
	elif (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.7):
		game.rebind(listening, event)
		listening = ""
		show_settings()
		get_viewport().set_input_as_handled()

func show_result(won: bool) -> void:
	var content = new_overlay("result", Rect2(405, 220, 630, 440))
	label(content, "D A W N   B E Y O N D   R U S T" if won else "E M B E R S   R E M A I N", 13, GOLD)
	spacer(content)
	label(content, "黒錆の夜を越えた" if won else "灯火は、まだ消えない", 30)
	label(content, "CLEAR  /  黒錆の王を撃破" if won else "周回終了  /  集めた欠片を持ち帰った", 17, MUTED)
	spacer(content)
	label(content, "持ち帰った残火の欠片    +%d" % game.run_currency, 23, MINT)
	label(content, "撃破 %d体  ·  探索時計 %02d:%02d  ·  所持武器 %d本" % [game.defeated_count, floori(game.elapsed / 60.0), int(game.elapsed) % 60, game.player.inventory.size()], 15, MUTED)
	label(content, "武器・付与効果・回復回数の増加は次の周回でリセット。", 13, MUTED)
	spacer(content)
	button(content, "出発の準備へ    →", game.go_home, 49).grab_focus()

func notify(message: String, duration: float = 3.5) -> void:
	toast.text = message
	toast_time = duration
	root.move_child(toast, root.get_child_count() - 1)

func set_interaction(near: Dictionary) -> void:
	if near.is_empty() or overlay_kind != "":
		prompt.text = ""
		return
	var message = {"weapon": "武器を比較・取得", "chest": "宝箱を開く", "rest": "休憩 / 全回復・回数補充", "flask": "回復回数の上限を増やす", "currency": "残火の欠片を拾う", "exit": "拠点を移動"}.get(near.type, "")
	if near.type == "exit": message = near.door[2]
	prompt.text = "[ %s / Pad X ]  %s" % [game.key_hint("interact"), message]

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	toast.visible = toast_time > 0
	if not game.running: return
	var p: Runner = game.player
	location.text = game.current.data.name
	var danger = Atlas.is_rusted(game.current_id, game.elapsed)
	var status = "黒錆の中 / 毎秒 HP -3%" if danger else ("夜 / 炉跡で決戦" if game.is_night() else "昼 / 夜まで %02d:%02d" % [floori(maxf(0, 420 - game.elapsed) / 60.0), int(maxf(0, 420 - game.elapsed)) % 60])
	phase.text = status + ("  ·  短縮テスト ×6" if game.speed_factor > 1 else "")
	phase.add_theme_color_override("font_color", Color("ed9679") if danger else MUTED)
	health.max_value = p.max_hp
	health.value = p.hp
	hp_label.text = "疾走者    HP %d / %d" % [ceili(p.hp), ceili(p.max_hp)]
	currency_label.text = "残火 +%d\n所持 %d / 6" % [game.run_currency, p.inventory.size()]
	var weapon_text = PackedStringArray()
	for slot in 2:
		var index: int = p.equipped[slot]
		var title = Armory.NAMES[p.inventory[index].kind] if index >= 0 else "未セット"
		weapon_text.append("%s [%s]  %s" % ["A" if slot == 0 else "B", game.key_hint("attack_a" if slot == 0 else "attack_b"), title])
	weapon_label.text = "     /     ".join(weapon_text) + "\n[%s] 回避   [%s] 疾走 %.1fs   [Space] ジャンプ" % [game.key_hint("dodge"), game.key_hint("skill"), p.skill_cooldown]
	flask_label.text = "[%s] 回復  %d / %d\n移動能力：%s%s" % [game.key_hint("heal"), p.flasks, p.flask_capacity, "二段 " if p.stats.double_jump else "", "壁破壊" if p.stats.wall_break else "—"]
	var boss: RustEnemy = null
	for enemy in game.current.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.data.size > 1.5:
			boss = enemy
			break
	boss_bar.visible = boss != null
	boss_label.visible = boss != null
	boss_poise.visible = boss != null
	boss_intent.visible = boss != null
	if boss != null:
		boss_label.text = boss.data.name + (" / 第二形態" if boss.phase == 2 else "")
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
		boss_poise.max_value = boss.poise_max
		boss_poise.value = boss.poise
		if boss.state in ["windup", "strike"]: boss_intent.text = boss.plan.name
		elif boss.state == "broken": boss_intent.text = "BREAK / 攻撃の好機・与ダメージ +20%"
		elif boss.state == "enrage": boss_intent.text = "第二形態へ移行 / 攻撃に備える"
		else: boss_intent.text = "体勢を崩して攻撃の好機をつくる"
	if is_instance_valid(map_canvas): map_canvas.queue_redraw()
	if is_instance_valid(inventory_status): inventory_status.text = "時間は進行中  ·  HP %d / %d  ·  %s" % [ceili(p.hp), ceili(p.max_hp), status]

class MapCanvas extends Control:
	var game: Node2D
	var font: Font
	func point(id: String) -> Vector2:
		return Vector2(450, 218) + Atlas.ROOMS[id].map * Vector2(115, 84)
	func _draw() -> void:
		var drawn: Array = []
		for id in Atlas.ROOMS:
			for door in Atlas.ROOMS[id].exits:
				var pair: Array = [id, door[1]]
				pair.sort()
				if pair in drawn: continue
				drawn.append(pair)
				var gated: bool = door[3] != "" or Atlas.ROOMS[door[1]].exits.any(func(e): return e[1] == id and e[3] != "")
				if gated: draw_dashed_line(point(id), point(door[1]), Color("bba16a"), 2, 7)
				else: draw_line(point(id), point(door[1]), Color("3b5356"), 2)
		for id in Atlas.ROOMS:
			var data: Dictionary = Atlas.ROOMS[id]
			var p = point(id)
			var c = Color("87c7b6")
			if Atlas.is_rusted(id, game.elapsed): c = Color("dc7967")
			elif game.elapsed >= 240 and id != "forge": c = Color("dcb76e")
			if id == game.current_id: draw_circle(p, 20, Color(c, 0.16))
			draw_circle(p, 9 if id == "forge" else 6, c)
			if id == game.current_id: draw_arc(p, 14, 0, TAU, 32, c, 2)
			var text: String = data.name.split(" / ")[1]
			draw_string(font, p + Vector2(-43, 30), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dce3d7"))
			if id == "forge": draw_string(font, p + Vector2(-30, -22), "帰還 / 決戦", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e8b779"))
