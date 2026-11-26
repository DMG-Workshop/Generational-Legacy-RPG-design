## The open world as a screen (roadmap items 39 and 51): a top-down map of the generated ground round the heir, drawn from
## GameSandbox, with the world's input (ui/play/world_input.gd) and the day's light (GameDay). Nothing here works out a
## result: it reads GameSandbox and GameDay, calls them, and draws. While it is open the world clock runs (GameClock), the
## world's own time, so a fight, a succession or an ended saga hands the screen back to the app at once.
## Tap a tile to walk there (a route over the ground as it is now); the keys or the stick walk the heir one tile at a time.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const RadialMenu := preload("res://ui/play/radial_menu.gd")
const ActionSlot := preload("res://ui/play/action_slot.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const UiSkin := preload("res://ui/play/ui_skin.gd")
const HeaderPlate := preload("res://ui/play/header_plate.gd")
const TouchControls := preload("res://ui/play/touch_controls.gd")
const CraftPanel := preload("res://ui/play/craft_panel.gd")
const ShopPanel := preload("res://ui/play/shop_panel.gd")
const TavernPanel := preload("res://ui/play/tavern_panel.gd")
const BoardPanel := preload("res://ui/play/board_panel.gd")
const WorldMapPanel := preload("res://ui/play/world_map_panel.gd")
const TrialsPanel := preload("res://ui/play/trials_panel.gd")
const MerchantPanel := preload("res://ui/play/merchant_panel.gd")
const GatePanel := preload("res://ui/play/gate_panel.gd")
const TalkPanel := preload("res://ui/play/talk_panel.gd")
const PaneKit := preload("res://ui/play/pane_kit.gd")
const StatusPane := preload("res://ui/play/status_pane.gd")
const MinimapPane := preload("res://ui/play/minimap_pane.gd")
const JournalPane := preload("res://ui/play/journal_pane.gd")
const FigurePane := preload("res://ui/play/figure_pane.gd")
const Toast := preload("res://ui/play/toast.gd")
const PausePanel := preload("res://ui/play/pause_panel.gd")
const PackPane := preload("res://ui/play/pack_pane.gd")
const HousePanel := preload("res://ui/play/house_panel.gd")
const Chronicle := preload("res://ui/play/chronicle_panel.gd")
const SkillTreePanel := preload("res://ui/play/skill_tree_panel.gd")
const BattleView := preload("res://ui/play/battle_view.gd")
const MapFight := preload("res://ui/play/map_fight.gd")
const SpriteMotion := preload("res://ui/play/sprite_motion.gd")
const BAR := 56.0

var app: Node
var sb: GameSandbox
var zoom := 1.0           # the view's zoom (WorldInput.zoom_after keeps it within the data's limits)
var cam := Vector2.ZERO   # the view's offset from the heir, in tiles
var facing_dir := Vector2i(0, 1)
var mode := "walk"          # "walk" (the heir moves) or "build" (the stick aims a piece and the bar places it)
var build_kind := "wall"    # the piece the Place button puts down
var _scales := {}           # companions: "id:level" -> their size against a human
var house_size := 3         # the index of the size of house the Raise house button builds (GameSandbox.house_sizes)
var house_preview := false  # whether the house's footprint is drawn (after the size button was pressed)
var house_button: Button
var slots := {}              # the action bar's slots by id (a desktop window with a mouse; empty on a touch screen)
var slot_ids: Array = []     # the numbered ones, in order
var smoke_button: Button    # Smoke, on a touch screen's bar (null on a desktop bar, where the ninth slot is it)
var cast_button: Button     # Cast, shown only in a dungeon: the heir's spells that work outside a fight (GameCasting.self_castable)
var build_bar: HBoxContainer
var orders_panel: VBoxContainer
var fingers := TouchControls.new()   # the stick and the pinch of a touch screen
var actions: VBoxContainer           # Dig and Place under the thumb, shown only with a touch layout
var status: Label
var skinned := false        # the header, the action bar and the ring wear the skin (a wide window with a mouse)
var header_plate: Control   # the heir's name and gold in the header (skinned only)
var map: Control          # clips the tile view to the map area, under the bar and the overlay
var tile_view: TileView   # the ground, as tile chunks
var glow_layer: Control   # over the map: the glow of hearths, forges and lit windows at night (WorldLook)
var sky_layer: Control    # over that: fog, rain, snow and the vignette (WorldLook)
var overlay: Control      # the route, buildings, creatures, heir, ghost and stick, over the tiles
var _figures := {}        # companion id and level -> their figure's texture (SpriteArt)
var _last_x := {}         # creature or companion -> where it was drawn last (the look only)
var _east := {}           # creature or companion -> whether it last moved east
var _last_pos := {}       # key -> where it was drawn last, to tell whether it moves (the walk frames; the look only)
var _moved_at := {}       # key -> the second it last moved
var _fight: Control = null   # the battle screen, hosted over the map while a creature's fight is on
var piece_button: Button
var level_button: Button
var last_line := "" : set = _set_line   # the latest news: a toast says it (the status strip keeps only the place)
var pause_closed_frame := -1   # the frame the pause screen was put away in: that frame's Escape does not open it again
var toast: Control        # the toast layer over everything (Toast)
var _walk_wait := 0.0
var _greet_wait := 0.0
var _name_tag := {}       # what a click just named: {text, point (tiles), until (msec)}; drawn over it for a moment
var _hud_wait := 0.0       # seconds to the next refresh of the panes that show the heir and the ground
var _use_when_there := false   # a double click on something out of reach: use it when the walk gets there
var _double := false      # the press now down was the second of a double click
var _bubbles := {}        # a person's id -> {text, until (msec)}: what they just said, over their head
var _bubble_pos := {}     # a person's id -> where their head was drawn last (screen)
var _banners := {}        # place -> the colour of its gate guards and banners
var _tick_wait := 0.0
var _save_wait := 0.0
var selected_companion := ""   # the companion a click chose (a right click then sends them; the order keys give them an order)
var _radial: Control = null   # the panel ring while it is up
var _radial_down_ms := 0
var _walk_press := Vector2.ZERO   # where and when the walk button went down (a quick click opens a thing's menu, a held one walks)
var _walk_press_ms := 0
var _press := Vector2.ZERO
var _press_ms := 0


static func setting(key: String) -> Variant:
	return GameSandbox.data()["view"][key]


## The map tile under a point of the map area (its own top-left at 0,0), with the heir at the centre of the view.
static func tile_at(p: Vector2, area: Vector2, heir: Vector2i, cam_tiles: Vector2, cell: float) -> Vector2i:
	var t := (p - area * 0.5) / cell + Vector2(heir) + cam_tiles
	return Vector2i(floori(t.x), floori(t.y))


## The step (one of eight) that a move vector means: the dominant direction, zero when it is not moved.
static func step_for(move: Vector2) -> Vector2i:
	if move.length() < float(setting("move_threshold")):
		return Vector2i.ZERO
	return WorldInput.facing(move)


func _ready() -> void:
	if not WorldInput.installed():
		WorldInput.install()   # the app installs them at start; a screen made on its own installs them itself
	sb = GameSandbox.start(app.dynasty)
	_warm_figures()
	map = Control.new()
	map.clip_contents = true
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.position = Vector2(0, BAR)
	map.size = Vector2(size.x, maxf(0.0, size.y - BAR))
	add_child(map)
	tile_view = TileView.new()
	tile_view.setup(app.dynasty)
	map.add_child(tile_view)
	overlay = Overlay.new()
	overlay.screen = self
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art stays crisp
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	glow_layer = WorldLook.make_layer(_paint_glow, true)   # the night's lights, added to the picture
	add_child(glow_layer)
	sky_layer = WorldLook.make_layer(_paint_sky, false)   # fog, rain, snow and the soft dark at the edge
	add_child(sky_layer)
	skinned = UiSkin.hud_active(self)
	if skinned:
		add_child(UiSkin.header_strip(BAR))   # the wooden strip the bar sits on
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, UiSkin.hud("bar_y") if skinned else 4.0)
	bar.size = Vector2(maxf(0.0, size.x - 16.0), UiSkin.hud("slot_px") if skinned else BAR - 8.0)
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	if UiSettings.touch():
		_old_buttons(bar)   # a touch screen keeps its text buttons
	else:
		_make_slots(bar)
	status = Kit.label("", 14, Kit.dim())
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	if skinned:
		status.add_theme_color_override("font_color", UiSkin.pal("wood_text"))
		UiSkin.outline(status)
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status.set_meta("skin_done", true)
	bar.add_child(status)
	if skinned:
		header_plate = HeaderPlate.new()
		header_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bar.add_child(header_plate)
	# The build bar: the pieces the family may build, placing and taking down. Shown only in build mode.
	build_bar = HBoxContainer.new()
	build_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	build_bar.offset_top = -BAR
	build_bar.add_theme_constant_override("separation", 6)
	add_child(build_bar)
	piece_button = Kit.button("", func(): _next_piece(), Vector2(136, BAR - 12))
	build_bar.add_child(piece_button)
	_pick(build_kind)
	level_button = Kit.button("", func(): _next_level(), Vector2(104, BAR - 12))
	build_bar.add_child(level_button)
	_next_level(false)
	build_bar.add_child(Kit.button("Place", func(): _build(), Vector2(88, BAR - 12)))
	build_bar.add_child(Kit.button("Take down", func(): _remove(), Vector2(108, BAR - 12)))
	build_bar.add_child(Kit.button("Repair", func(): _repair(), Vector2(88, BAR - 12)))
	house_button = Kit.button("", func(): _next_house_size(), Vector2(128, BAR - 12))
	build_bar.add_child(house_button)
	_next_house_size(false)
	build_bar.add_child(Kit.button("Raise house", func(): _raise_house(), Vector2(128, BAR - 12)))
	build_bar.visible = false
	# The orders panel: each companion in the party with the order they hold; a tap moves it to the next.
	orders_panel = VBoxContainer.new()
	orders_panel.position = Vector2(maxf(0.0, size.x - 280.0), BAR + 8.0)
	orders_panel.size = Vector2(272, 0)
	orders_panel.add_theme_constant_override("separation", 6)
	add_child(orders_panel)
	orders_panel.visible = false
	_refresh_orders()
	if UiSettings.touch():
		_make_action_buttons()
	_refresh_status()
	_sync_tiles()
	toast = Toast.attach(self)
	_open_hud.call_deferred()   # the panes that stay up (once the screen has its size)


func _process(delta: float) -> void:
	var d: GameDynasty = app.dynasty
	if _fight != null:
		return   # a fight is on over the map: it ends in _fight_over, even if the heir falls in it
	if d.state != "life":
		app.show_state()   # the clock (or the heir) has handed the screen over: a succession, the end
		return
	if d.battle != null:
		_open_fight()   # a creature has caught the heir: the fight is played over the map, which stays where it is
		return
	_hud_wait -= delta
	if _hud_wait <= 0.0:
		_hud_wait = 0.25
		_refresh_panes()
	if _modal_open():
		return   # the workshop is open: the world waits
	var inp := WorldInput.read()
	if int(inp["zoom"]) != 0:
		zoom = WorldInput.zoom_after(zoom, int(inp["zoom"]))
	var look: Vector2 = inp["look"]
	if look.length() > 0.0:
		cam += look * float(setting("cam_tiles_per_second")) * delta
	var mv: Vector2 = inp["move"]
	if fingers.steering() and fingers.move().length() > 0.0:
		mv = fingers.move()   # a finger on the stick steers over the keys
	if mv.length() < 0.001 and mode == "walk" and _walk_held() and not UiSettings.touch():
		mv = _mouse_walk()   # holding the walk button walks toward the cursor
	_walk_wait -= delta
	var stepped := false
	if step_for(mv) != Vector2i.ZERO:
		_use_when_there = false
		sb.cancel_walk()   # any key or stick ends a walk, whole (GameTravel's legs too)
		if mode == "build":
			facing_dir = step_for(mv)   # in build mode the stick aims the piece; the heir stays where they are
		elif _walk_wait <= 0.0:
			facing_dir = step_for(mv)
			sb.move(facing_dir.x, facing_dir.y)
			_walk_wait = float(GameSandbox.setting("walk_seconds"))
			stepped = true
	elif mode == "walk" and not sb.route.is_empty() and _walk_wait <= 0.0:
		sb.walk_one()
		_walk_wait = float(GameSandbox.setting("walk_seconds"))
		stepped = true
		if _use_when_there and sb.route.is_empty():   # a double click out of reach: they have arrived, so use it
			_use_when_there = false
			_use()
	elif _use_when_there and sb.route.is_empty():
		_use_when_there = false
	if stepped:
		cam = Vector2.ZERO   # the view follows the heir while they walk
	_greet_wait -= delta
	if sb.space == "world" and mode == "walk" and (stepped or _greet_wait <= 0.0):
		_greet_wait = 1.0
		var g := sb.greeting()   # someone in the town may call out (never in a fight or with a panel open: both return above)
		if not g.is_empty():
			_say(str(g["who"]["id"]), str(g["text"]))
			last_line = str(g["line"])
	if not sb.dirty.is_empty():
		for c in sb.dirty:
			tile_view.refresh_cell(int(c.x), int(c.y))   # a node gathered, a shaft dug: its tile looks different
		sb.dirty.clear()
	if sb.arrived != "":
		last_line = str(sb.log[sb.log.size() - 1]["text"])   # walked into a place: say so
		sb.arrived = ""
	_tick_wait -= delta
	while _tick_wait <= 0.0:
		sb.step(1)
		_tick_wait += float(GameSandbox.setting("tick_seconds"))
	var lines := GameClock.feed(d, delta * sb.time_flow())
	for e in lines:
		last_line = str(e.get("text", e)) if e is Dictionary else str(e)
	_save_wait -= delta
	if _save_wait <= 0.0:
		_save()
		_save_wait = float(setting("save_seconds"))
	if inp["cancel"] and Engine.get_process_frames() != pause_closed_frame:
		_open_menu()
		return
	if inp["interact"]:
		_use()
	if inp["climb_up"]:
		_climb(-1)
	if inp["climb_down"]:
		_climb(1)
	if inp["dig"]:
		_dig()
	if inp["build"]:
		_build()
	_refresh_status()
	_sync_tiles()
	SpriteArt.begin_batch()
	_warm_frames()   # a creature that has just come into the world: its frames are made before the draw, never in it
	SpriteArt.end_batch()
	overlay.queue_redraw()
	glow_layer.queue_redraw()
	sky_layer.queue_redraw()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var area_size := Vector2(size.x, size.y - BAR)
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		fingers.touch(st.index, st.position - Vector2(0, BAR), st.pressed, area_size)
		queue_redraw()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		fingers.drag(sd.index, sd.position - Vector2(0, BAR))
		zoom = fingers.pinch(zoom)
		queue_redraw()
		return
	if event is InputEventMouseButton and not UiSettings.touch():
		var e := event as InputEventMouseButton
		var area := Vector2(size.x, size.y - BAR)
		if e.button_index == WorldInput.mouse_button("select"):
			if e.pressed:
				_press = e.position
				_press_ms = Time.get_ticks_msec()
				_double = e.double_click
			elif WorldInput.is_tap(_press, e.position, float(Time.get_ticks_msec() - _press_ms) / 1000.0):
				if _double:
					_double_click(e.position - Vector2(0, BAR), area)
				else:
					_tap(e.position - Vector2(0, BAR), area)
		elif e.button_index == WorldInput.mouse_button("walk"):
			if e.pressed:
				_walk_press = e.position
				_walk_press_ms = Time.get_ticks_msec()
			else:
				# a quick click of the walk button on a thing opens what can be done with it (a held one has walked)
				var quick := WorldInput.is_tap(_walk_press, e.position, float(Time.get_ticks_msec() - _walk_press_ms) / 1000.0)
				_walk_press_ms = 0
				if quick:
					_thing_menu(e.position - Vector2(0, BAR), area, e.global_position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var t := event as InputEventMouseButton   # touch emulated as a mouse: a tap, as before
		var tarea := Vector2(size.x, size.y - BAR)
		if t.pressed:
			_press = t.position
			_press_ms = Time.get_ticks_msec()
			_double = false
		elif WorldInput.is_tap(_press, t.position, float(Time.get_ticks_msec() - _press_ms) / 1000.0):
			_tap(t.position - Vector2(0, BAR), tarea)


## The text buttons of the bar, as a touch screen has them.
func _old_buttons(bar: HBoxContainer) -> void:
	bar.add_child(Kit.button("Menu", func(): _open_menu(), Vector2(88, BAR - 12)))
	bar.add_child(Kit.button("Dig", func(): _dig(), Vector2(72, BAR - 12)))
	bar.add_child(Kit.button("Forage", func(): _forage(), Vector2(88, BAR - 12)))
	bar.add_child(Kit.button("Build", func(): _set_mode("walk" if mode == "build" else "build"), Vector2(88, BAR - 12)))
	bar.add_child(Kit.button("Orders", func(): _toggle_orders(), Vector2(96, BAR - 12)))
	bar.add_child(Kit.button("Map", func(): _open_world_map(), Vector2(64, BAR - 12)))
	bar.add_child(Kit.button("Use", func(): _use(), Vector2(64, BAR - 12)))
	cast_button = Kit.button("Cast", func(): _open_cast(), Vector2(64, BAR - 12))
	cast_button.visible = false
	bar.add_child(cast_button)
	bar.add_child(Kit.button("Up", func(): _climb(-1), Vector2(64, BAR - 12)))
	bar.add_child(Kit.button("Down", func(): _climb(1), Vector2(72, BAR - 12)))
	smoke_button = Kit.button("Smoke", func(): _use_smoke(), Vector2(84, BAR - 12))
	bar.add_child(smoke_button)


## The action bar on a desktop window with a mouse: the Menu and the map, then eight numbered slots (data/ui/actionbar.json).
func _make_slots(bar: HBoxContainer) -> void:
	slots.clear()
	slot_ids.clear()
	for def in ActionSlot.data()["extras"]:
		var xid := str(def["id"])
		var extra: Control = ActionSlot.make(def, "", func(): _slot_do(xid), skinned)
		slots[xid] = extra
		bar.add_child(extra)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	bar.add_child(gap)
	var n := 0
	for def in ActionSlot.data()["slots"]:
		n += 1
		var sid := str(def["id"])
		var slot: Control = ActionSlot.make(def, str(n), func(): _slot_do(sid), skinned)
		slots[sid] = slot
		slot_ids.append(sid)
		bar.add_child(slot)


## What a slot does, from its click or its number key.
func _slot_do(id: String) -> void:
	if mode == "build" and id not in ["build", "menu", "map"]:
		return   # the build bar has the controls while building
	match id:
		"menu":
			_open_menu()
		"map":
			_toggle_panel("map")
		"use":
			_use()
		"dig":
			_dig()
		"forage":
			_forage()
		"build":
			_set_mode("walk" if mode == "build" else "build")
		"cast":
			if _can_cast():
				_open_cast()
			else:
				last_line = ActionSlot.text("cast_none")
		"orders":
			_toggle_orders()
		"up":
			_climb(-1)
		"down":
			_climb(1)
		"smoke":
			_use_smoke()
	_refresh_slots()


## The data's entry for a numbered slot.
func _slot_def(id: String) -> Dictionary:
	for def in ActionSlot.data()["slots"]:
		if str(def["id"]) == id:
			return def
	return {}


## Breaks a smoke pot where the heir stands (GameSandbox.use_smoke): from the ninth slot, the touch bar's Smoke button and the pack.
func _use_smoke() -> Dictionary:
	var r: Dictionary = sb.use_smoke()
	last_line = str(r["text"])
	_refresh_status()
	return r


func _can_cast() -> bool:
	return GameDungeons.is_dungeon(sb.space) and not GameCasting.self_castable(app.dynasty).is_empty()


## Dims the slots that do not apply and lights the ones whose mode is on.
func _refresh_slots() -> void:
	if slots.is_empty():
		return
	if slots.has("cast"):
		slots["cast"].set_state(not _can_cast(), false)
	if slots.has("smoke"):   # dimmed when the heir has none; the tooltip counts them
		var pots := GameSmoke.count(app.dynasty.heir)
		slots["smoke"].set_state(pots <= 0, GameSmoke.active(app.dynasty))
		slots["smoke"].set_count(_slot_def("smoke"), str(slot_ids.find("smoke") + 1), pots)
	if slots.has("build"):
		slots["build"].set_state(false, mode == "build")
	if slots.has("orders") and orders_panel != null:
		slots["orders"].set_state(false, orders_panel.visible)


## Whether the walk button has been down long enough to walk: a quick click is for the menu of a thing, so it does not take a step.
func _walk_held() -> bool:
	return _walk_press_ms > 0 and Input.is_mouse_button_pressed(WorldInput.mouse_button("walk")) \
		and float(Time.get_ticks_msec() - _walk_press_ms) / 1000.0 >= WorldInput.setting("walk_hold_seconds")


## The popup of what can be done with the thing under a click of the walk button (GameSandbox.thing_actions): over bare ground
## nothing opens. Choosing walks there, goes and uses it, or opens the heir's character or pack, or gives a companion an order.
func _thing_menu(p: Vector2, area: Vector2, at: Vector2) -> void:
	if p.y < 0.0 or p.y > area.y or mode != "walk" or _modal_open():
		return
	var point := _point_at(p, area)
	var named := sb.name_at(point.x, point.y)
	if selected_companion != "" and _send_selected(named, point):
		return
	var acts := sb.thing_actions(named)
	if acts.is_empty():
		return
	var tile := tile_at(p, area, sb.heir, cam, _cell())
	var menu := PopupMenu.new()
	menu.set_meta("modal", true)
	if skinned:
		UiSkin.dress_popup(menu)
	menu.add_item(str(named["name"]), 1000)
	menu.set_item_disabled(0, true)
	menu.add_separator()
	for i in acts.size():
		menu.add_item(str(acts[i]["label"]), i)
	menu.id_pressed.connect(func(i: int):
		if i < acts.size():
			_thing_act.call_deferred(named, str(acts[i]["id"]), tile))
	menu.popup_hide.connect(func(): menu.queue_free.call_deferred())
	add_child(menu)
	menu.popup(Rect2i(Vector2i(at), Vector2i.ZERO))


## Does one choice of the thing menu.
func _thing_act(named: Dictionary, action: String, tile: Vector2i) -> void:
	match action:
		"character":
			_open_figure()
		"pack":
			_open_pack("")
		"walk", "talk", "use":
			var planned := sb.set_route(tile)
			if planned["ok"]:
				_use_when_there = action != "walk"
				_walk_wait = 0.0
				last_line = str(named["name"])
			else:
				last_line = str(planned["why"])
			cam = Vector2.ZERO
		_:
			var r := sb.give_order(named, action)
			last_line = str(r["text"])
	_refresh_status()
	queue_redraw()


## The direction toward the cursor from the heir while the right button is held (a unit vector; zero close to the heir).
func _mouse_walk() -> Vector2:
	var area := Vector2(size.x, size.y - BAR)
	return walk_toward(get_local_mouse_position() - Vector2(0, BAR), area, cam, _cell(), float(setting("walk_deadzone_cells")))


## The direction from the heir to a point of the map area (the heir is at its centre, less the camera's shift): a unit vector, or zero
## within `dead` cells of the heir.
static func walk_toward(p: Vector2, area: Vector2, cam_tiles: Vector2, cell: float, dead: float) -> Vector2:
	var off := p - area * 0.5 + cam_tiles * -cell
	if off.length() < dead * cell:
		return Vector2.ZERO
	return off.normalized()


## The point of the open world under a screen position, in tiles (fractions kept).
func _point_at(p: Vector2, area: Vector2) -> Vector2:
	return Vector2(sb.heir) + cam + (p - area * 0.5) / _cell() + Vector2(0.5, 0.5)


## A double click, with a mouse: use what is clicked. Beside the heir (or on them), Use at once; further off, walk there and use it
## when they arrive. Nothing is used on bare ground, where it only walks.
func _double_click(p: Vector2, area: Vector2) -> void:
	if p.y < 0.0 or p.y > area.y or mode != "walk":
		return
	var tile := tile_at(p, area, sb.heir, cam, _cell())
	var named := sb.name_at(_point_at(p, area).x, _point_at(p, area).y)
	if named.is_empty():
		_tap(p, area)   # bare ground: a double click only walks there, like a click
		return
	if named["kind"] == "heir":
		_open_figure()   # a double click on yourself opens your character: the figure and what is worn
		return
	if absi(tile.x - sb.heir.x) <= 1 and absi(tile.y - sb.heir.y) <= 1:
		_use()
		return
	var planned := sb.set_route(tile)
	if planned["ok"]:
		_use_when_there = true
		_walk_wait = 0.0
		last_line = str(named["name"])
	else:
		last_line = str(planned["why"])
	cam = Vector2.ZERO
	queue_redraw()


func _tap(p: Vector2, area: Vector2) -> void:
	if p.y < 0.0 or p.y > area.y:
		return
	_use_when_there = false
	var tile := tile_at(p, area, sb.heir, cam, _cell())
	if mode == "walk" and not UiSettings.touch():   # with a mouse, a click on a thing names it, over it, and goes no further
		var point := _point_at(p, area)
		var named := sb.name_at(point.x, point.y)
		if not named.is_empty():
			_name_tag = {"text": _named_text(named), "point": point, "until": Time.get_ticks_msec() + int(float(setting("name_seconds")) * 1000.0)}
			last_line = str(named["name"])
			if str(named["kind"]) == "companion":
				last_line = _select(str(named["id"]), str(named["name"]))
			_refresh_status()
			queue_redraw()
			return
	var dx := tile.x - sb.heir.x
	var dz := tile.y - sb.heir.y
	if mode == "build":
		if absi(dx) <= 1 and absi(dz) <= 1 and (dx != 0 or dz != 0):
			facing_dir = Vector2i(dx, dz)   # a tap beside the heir aims the piece there
		_refresh_status()
		queue_redraw()
		return
	if absi(dx) <= 1 and absi(dz) <= 1 and (dx != 0 or dz != 0):
		sb.cancel_walk()
		var r := sb.move(dx, dz)
		if not r["ok"]:
			last_line = str(r["why"])
	elif tile != sb.heir:
		var planned := sb.set_route(tile)
		if not planned["ok"]:
			last_line = str(planned["why"])
		else:
			_walk_wait = 0.0
	cam = Vector2.ZERO
	_refresh_status()
	queue_redraw()


## Shows a panel over the map as a pane (on a window wide enough for one, see PaneKit): marked so `Kit.overlay` builds it as a window,
## and a panel of the same kind that is already open is raised instead of opened twice.
func _add_pane(panel: Control, suffix: String = "") -> void:
	var key: String = panel.get_script().resource_path.get_file().get_basename() + suffix
	for c in get_children():
		if c.has_meta("pane") and str(c.get_meta("pane")) == key and not c.is_queued_for_deletion():
			c.move_to_front()
			panel.free()
			return
	panel.set_meta("pane", key)
	add_child(panel)


## A click on a companion chooses them, or lets them go if they are the one chosen. The line to say.
func _select(id: String, nm: String) -> String:
	if selected_companion == id:
		selected_companion = ""
		return str(GameSandbox.data()["text"]["deselected"]).format({"name": nm})
	selected_companion = id
	return str(GameSandbox.data()["text"]["selected"]).format({"name": nm})


## A quick click of the walk button with a companion chosen sends them, as in a strategy game: on bare ground they hold that place, on a
## creature they guard it, on the heir they come back to follow. Anything else is the popup as usual. True when it sent them.
func _send_selected(named: Dictionary, point: Vector2) -> bool:
	if not sb.d.party.has_member(selected_companion):
		selected_companion = ""
		return false
	var spot := Vector2(floorf(point.x) + 0.5, floorf(point.y) + 0.5)
	var r: Dictionary
	if named.is_empty():
		r = sb.send_order(selected_companion, "stay", spot.x, spot.y)
	elif str(named["kind"]) == "creature":
		r = sb.send_order(selected_companion, "guard", float(point.x), float(point.y))
	elif str(named["kind"]) == "heir":
		r = sb.send_order(selected_companion, GameCompanions.FOLLOW, 0.0, 0.0)
	else:
		return false
	last_line = str(r["text"])
	if r["ok"]:
		_save()
	_refresh_orders()
	_refresh_status()
	return true


## An order key: the chosen companion, or everyone in the party when none is chosen, takes the order.
func _order_key(order: String) -> void:
	if not sb.d.party.has_member(selected_companion):
		selected_companion = ""
	var lines := sb.order_party(order, selected_companion)
	last_line = " ".join(lines) if not lines.is_empty() else str(GameSandbox.data()["text"]["nobody"])
	if not lines.is_empty():
		_save()
	_refresh_orders()
	_refresh_status()


## The first key a panel answers to, as "  (C)" for a menu label, or "" with none.
func _key_hint(id: String) -> String:
	var keys: Array = WorldInput.keys_of("world_panel_" + id)
	return "  (%s)" % str(keys[0]) if not keys.is_empty() else ""


## The panel keys and the panel ring. A key opens its panel and the same key closes it; the ring key (Tab) opens a ring of the panels round
## the mouse for as long as it is held. Read here, not in `_process`, so they work with a panel open, when the world waits; a key a text
## field has taken never arrives.
func _unhandled_input(event: InputEvent) -> void:
	if _fight != null or not (event is InputEventKey) or (event as InputEventKey).echo:
		return
	if event.is_action_pressed("world_radial"):
		get_viewport().set_input_as_handled()
		if _radial != null:
			_radial_close("")   # the ring left up by a tap: the key again puts it away
		else:
			_radial_open()
		return
	if event.is_action_released("world_radial"):
		_radial_release()
		return
	if not event.is_pressed():
		return
	if not _modal_open():
		for o in GameCompanions.ORDERS:
			if event.is_action_pressed("world_order_" + str(o)):
				get_viewport().set_input_as_handled()
				_order_key(str(o))
				return
		for i in slot_ids.size():
			if event.is_action_pressed("world_slot_%d" % (i + 1)):
				get_viewport().set_input_as_handled()
				_slot_do(str(slot_ids[i]))
				return
	for id in _panel_ids():
		if event.is_action_pressed("world_panel_" + id):
			get_viewport().set_input_as_handled()
			_toggle_panel(id)
			return


## The panels the keys and the ring open, in the ring's order.
func _panel_ids() -> Array:
	return RadialMenu.data()["items"].map(func(it): return str(it["id"])) + ["status", "nearby"]


## A panel's key (or its place in the ring): open it, or close it if it is up.
func _toggle_panel(id: String) -> void:
	match id:
		"character":
			_toggle_pane("figure_pane", func(): _open_figure())
		"pack":
			_toggle_pane("pack_pane", func(): _open_pack(""))
		"house":
			_toggle_pane("house_panel", func(): _open_popup(HousePanel))
		"chronicle":
			_toggle_pane("chronicle_panel", func(): _open_popup(Chronicle))
		"skills":
			_toggle_pane("skill_tree_panel", func(): _open_popup(SkillTreePanel))
		"gear":
			_toggle_pane("shop_panel", func(): _open_gear())
		"status":
			_toggle_hud(StatusPane)
		"nearby":
			_toggle_hud(MinimapPane)
		"journal":
			_toggle_hud(JournalPane)
		"map":
			for c in get_children():
				if c.get_script() == WorldMapPanel and not c.is_queued_for_deletion():
					c.queue_free()
					return
			_open_world_map()


func _toggle_pane(key: String, opener: Callable) -> void:
	for c in get_children():
		if c.has_meta("pane") and str(c.get_meta("pane")) == key and not c.is_queued_for_deletion():
			PaneKit.close(c)
			return
	opener.call()


func _radial_open() -> void:
	if UiSettings.touch():
		return
	_radial = RadialMenu.make(get_local_mouse_position(), size)
	_radial.set_meta("modal", true)   # the world waits while the ring is up
	_radial.chosen.connect(_radial_close)
	_radial_down_ms = Time.get_ticks_msec()
	add_child(_radial)


## The ring key was let go: choose what the mouse is toward, or (a quick tap with nothing chosen) leave the ring up for a click.
func _radial_release() -> void:
	if _radial == null or _radial.sticky:
		return
	var held := float(Time.get_ticks_msec() - _radial_down_ms) / 1000.0
	if _radial.picked() != "" or held >= RadialMenu.setting("tap_seconds"):
		_radial_close(_radial.picked())
	else:
		_radial.sticky = true
		_radial.queue_redraw()


func _radial_close(id: String) -> void:
	if _radial == null:
		return
	var ring := _radial
	_radial = null
	ring.queue_free()
	if id != "":
		_toggle_panel.call_deferred(id)


## The workshop over the map, at the family's forge: while it is open the world waits and the keys do nothing here.
func _open_workshop(forge: String) -> void:
	var panel: Control = CraftPanel.new()
	panel.dynasty = app.dynasty
	panel.on_change = func(): _refresh_status()
	panel.forge = forge
	_add_pane(panel)


## A town's service over the map, from the person who runs it (GamePeople): shop (on its tab), tavern or notice board. The world
## waits while it is open.
func _open_service(kind: String, tab: String) -> void:
	var panel: Control
	match kind:
		"shop":
			panel = ShopPanel.new()
			panel.start_tab = tab
		"tavern":
			panel = TavernPanel.new()
		"board":
			panel = BoardPanel.new()
		_:
			return
	panel.dynasty = app.dynasty
	panel.on_change = func(): _refresh_status()
	panel.set_meta("modal", true)
	_add_pane(panel)


## The Trials panel over the map, from a trial's master at its site: the world waits while it is open. A fight it starts (a master met in battle)
## is handed to the battle screen by the next frame, as any fight in the open world is.
func _open_trials() -> void:
	var panel: Control = TrialsPanel.new()
	panel.dynasty = app.dynasty
	panel.on_change = func(): _refresh_status()
	panel.set_meta("modal", true)
	_add_pane(panel)


## A waygate's panel over the map (GameGates): the world waits while it is open. A trip through it puts the heir in another place, so the view
## is centred on them again afterwards.
func _open_gate(id: String) -> void:
	var panel: Control = GatePanel.new()
	panel.dynasty = app.dynasty
	panel.sandbox = sb
	panel.gate = id
	panel.on_change = func():
		cam = Vector2.ZERO
		if sb.space != "world":
			_warm_figures()
		_refresh_status()
		queue_redraw()
	panel.set_meta("modal", true)
	_add_pane(panel)


## A wilds trader's panel over the map (GameWildsTrade): the world waits while it is open.
func _open_merchant(lm: Dictionary) -> void:
	var panel: Control = MerchantPanel.new()
	panel.dynasty = app.dynasty
	panel.landmark = lm
	panel.on_change = func(): _refresh_status()
	panel.set_meta("modal", true)
	_add_pane(panel)


## The world map over the open world (GameWorldMap): the world waits while it is open.
func _open_world_map() -> void:
	var panel: Control = WorldMapPanel.new()
	panel.dynasty = app.dynasty
	panel.sb = sb
	if sb.space == "world":
		panel.heir_tile = sb.heir
	panel.on_line = func(line: String):   # a pin, a walk or a coach: the status line says so, and the view comes to the heir
		last_line = line
		cam = Vector2.ZERO
		_refresh_status()
	add_child(panel)


## Whether a modal panel (the workshop) is open over the map.
func _modal_open() -> bool:
	for c in get_children():
		if c.has_meta("modal") and not c.is_queued_for_deletion():
			return true
	return false


## Plays the fight over the map: the battle screen runs under a stand-in app (MapFight) whose "done" gives the map back.
func _open_fight() -> void:
	var host := MapFight.new()
	host.dynasty = app.dynasty
	host.app = app
	host.sound = app.sound if "sound" in app else null
	host.on_done = _fight_over
	var bv: Control = BattleView.new()
	bv.app = host
	host.current = bv
	_fight = bv
	add_child(host)
	bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bv)


## The fight is over: the battle screen goes, the heir gets clear if they fled, and the map goes on (or the life's next screen
## comes, if the heir fell or the line ended).
func _fight_over() -> void:
	if app.dynasty.battle != null:
		return   # not over yet
	if _fight != null:
		var host: Node = _fight.app
		_fight.queue_free()
		_fight = null
		host.queue_free()
	sb.after_fight()
	_refresh_status()
	queue_redraw()   # (a heir who fell or a line that ended is handed on by the next _process)


## The spells the heir can cast on a dungeon's floor, as a menu; one picked is cast (GameSandbox.cast).
func _open_cast() -> void:
	var menu := PopupMenu.new()
	menu.add_theme_font_size_override("font_size", 20)
	menu.add_theme_constant_override("v_separation", 16)
	var list: Array = GameCasting.self_castable(app.dynasty)
	for i in list.size():
		menu.add_item("%s  (%d MP)" % [list[i]["name"], int(list[i]["cost"])], i)
		menu.set_item_disabled(i, not bool(list[i]["can"]))
	menu.id_pressed.connect(func(i: int):
		var r := sb.cast(str(list[i]["id"]))
		last_line = str(r["text"])
		_refresh_status()
		queue_redraw())
	menu.popup_hide.connect(func(): menu.queue_free.call_deferred())
	add_child(menu)
	menu.popup_centered()


## The pause screen (the bar's Menu button, Escape, B): the world waits while it is up. Its Panels row is the list of the family's screens.
func _open_menu() -> void:
	open_pause()


func open_pause() -> Control:
	for c in get_children():
		if c is PausePanel and not c.is_queued_for_deletion():
			return c   # one is enough: Escape in the pause screen closes it (the app's back), it does not stack another
	var p: Control = PausePanel.new()
	p.app = app
	p.screen = self
	add_child(p)
	return p


## The family's screens as a popup over the world, which waits while one is open, so the player does not leave the map for the text
## game unless they ask ("The text screen" is the old Back). The pause screen's Panels row.
func _open_panels_menu() -> void:
	var menu := PopupMenu.new()
	menu.set_meta("modal", true)
	var rows: Array = [
		["Back to the map", Callable()],
		["The family house" + _key_hint("house"), func(): _toggle_panel("house")],
		["Chronicle" + _key_hint("chronicle"), func(): _toggle_panel("chronicle")],
		["Skill trees" + _key_hint("skills"), func(): _toggle_panel("skills")],
		["Character" + _key_hint("character"), func(): _toggle_panel("character")],
		["Pack" + _key_hint("pack"), func(): _toggle_panel("pack")],
		["Status" + _key_hint("status"), func(): _toggle_panel("status")],
		["Nearby map" + _key_hint("nearby"), func(): _toggle_panel("nearby")],
		["Journal" + _key_hint("journal"), func(): _toggle_panel("journal")],
		["Gear" + _key_hint("gear"), func(): _toggle_panel("gear")],
		["The text screen", func(): app.show_state()],
	]
	for i in rows.size():
		menu.add_item(str(rows[i][0]), i)
	menu.id_pressed.connect(func(i: int):
		var act: Callable = rows[i][1]
		if act.is_valid():
			act.call_deferred())
	menu.popup_hide.connect(func(): menu.queue_free.call_deferred())
	add_child(menu)
	menu.popup_centered()


## The panes that stay up while you play: status, the ground nearby and the journal (each one the player has not closed), in a window
## wide enough for panes and with a mouse.
func _open_hud() -> void:
	if UiSettings.compact(self) or UiSettings.touch():
		return
	for script in [StatusPane, MinimapPane, JournalPane]:
		var key: String = script.resource_path.get_file().get_basename()
		if PaneKit.wanted(key):
			_open_hud_pane(script)


func _open_hud_pane(script: Script) -> void:
	var panel: Control = script.new()
	panel.dynasty = app.dynasty
	if "sb" in panel:
		panel.sb = sb
	panel.set_meta("pane_hud", true)
	_add_pane(panel)


## The Menu's switch for a pane that stays up: open it, or close it (and have it stay closed).
func _toggle_hud(script: Script) -> void:
	var key: String = script.resource_path.get_file().get_basename()
	for c in get_children():
		if c.has_meta("pane") and str(c.get_meta("pane")) == key and not c.is_queued_for_deletion():
			PaneKit.close(c)
			return
	PaneKit.want(key)
	_open_hud_pane(script)


## The character pane: a double click on the heir, or the Menu. Not a modal: the world goes on while it is open.
func _open_figure() -> void:
	var panel: Control = FigurePane.new()
	panel.dynasty = app.dynasty
	panel.on_change = func(): _refresh_status()
	panel.on_pack = func(): _open_pack("")
	_add_pane(panel)


## The pack (bag "") or what a bag holds, as a pane (one for each bag).
func _open_pack(bag: String) -> void:
	var panel: Control = PackPane.new()
	panel.dynasty = app.dynasty
	panel.bag = bag
	panel.on_change = func(): _refresh_status()
	panel.on_smoke = func() -> String: return str(_use_smoke()["text"])
	panel.on_open_bag = func(id: String): _open_pack(id)
	_add_pane(panel, "" if bag == "" else ":" + bag)


## What the panes that show the heir (and the world) draw is brought up to date a few times a second.
func _refresh_plate() -> void:
	if header_plate != null:
		header_plate.show_for(app.dynasty.heir.name, app.dynasty.heir.gold)


func _refresh_panes() -> void:
	_refresh_plate()
	for c in get_children():
		if c.has_meta("pane") and not c.is_queued_for_deletion() and c.has_method("refresh"):
			c.refresh()


## One of the family's panels over the map, as a modal: the world waits while it is open.
func _open_popup(panel_script: Script) -> void:
	var panel: Control = panel_script.new()
	panel.dynasty = app.dynasty
	panel.on_change = func(): _refresh_status()
	panel.set_meta("modal", true)
	_add_pane(panel)


## The shop panel's Gear tab on its own, over the map.
func _open_gear() -> void:
	var panel: Control = ShopPanel.new()
	panel.gear_only = true
	panel.dynasty = app.dynasty
	panel.on_change = func(): _refresh_status()
	panel.set_meta("modal", true)
	_add_pane(panel)


## The Use action: in by the door the heir stands at, or out by the entrance of the interior they are in.
func _use() -> void:
	var r := sb.use()
	if sb.space != "world":
		_warm_figures()   # inside: the figures of this building are made before they are drawn
	last_line = str(r["text"])
	cam = Vector2.ZERO
	if str(r.get("open", "")) == "workshop":
		_open_workshop(str(r.get("forge", "")))
	elif str(r.get("open", "")) in ["shop", "tavern", "board"]:
		_open_service(str(r["open"]), str(r.get("tab", "")))
	elif str(r.get("open", "")) == "merchant":
		_open_merchant(r["landmark"])
	elif str(r.get("open", "")) == "trials":
		_open_trials()
	elif str(r.get("open", "")) == "gate":
		_open_gate(str(r["gate"]))
	elif r.has("who") and not (r["who"] as Dictionary).is_empty():
		_say(str(r["who"]["id"]), str(r.get("bare", "")))   # a villager answered: their words show over their head
		if not (r["choices"] as Array).is_empty():
			_open_talk(r)
	_refresh_status()
	queue_redraw()


## Puts words over a person's head for a few seconds.
func _say(id: String, said: String) -> void:
	_bubbles[id] = {"text": said, "until": Time.get_ticks_msec() + int(float(GameTalk.setting("bubble_seconds")) * 1000.0)}


## A short conversation with a villager over the map: the world waits while it is open.
func _open_talk(r: Dictionary) -> void:
	var panel: Control = TalkPanel.new()
	panel.dynasty = app.dynasty
	panel.who = r["who"]
	panel.first = str(r.get("bare", ""))
	panel.on_say = func(line: String): last_line = line
	panel.set_meta("modal", true)
	_add_pane(panel)


## Up or down the stairs the heir stands at (`GameSandbox.climb`); the line says why not.
func _climb(dir: int) -> void:
	var r := sb.climb(dir)
	last_line = str(r["text"]) if r["ok"] else str(r["why"])
	_refresh_status()
	queue_redraw()


func _dig() -> void:
	var r := sb.dig(0)
	if r["ok"]:
		last_line = str(sb.log.back()["text"])   # GameSandbox.dig logged the line just now
		_save()
	else:
		last_line = str(r["why"])
	_refresh_status()
	queue_redraw()


func _forage() -> void:
	var r := sb.forage()
	last_line = str(r["text"])
	if r["ok"]:
		_save()
	_refresh_status()
	queue_redraw()


func _build() -> void:
	var r := sb.build(build_kind, facing_dir.x, facing_dir.y)
	last_line = str(r["text"])
	if r["ok"]:
		tile_view.refresh_cell(sb.heir.x + facing_dir.x, sb.heir.y + facing_dir.y)
		_save()
	_refresh_status()
	queue_redraw()


## The house button steps through the sizes of house on offer and shows where it would stand.
func _next_house_size(step: bool = true) -> void:
	var sizes: Array = sb.house_sizes()
	if step:
		house_size = (house_size + 1) % sizes.size()
		house_preview = true
	house_size = house_size % sizes.size()
	var sz: Array = sizes[house_size]
	house_button.text = "House: %d x %d" % [int(sz[0]), int(sz[1])]
	_refresh_status()
	queue_redraw()


## Raises the chosen house with its door on the tile the heir faces, in one go (or says what stops it).
func _raise_house() -> void:
	var sz: Array = sb.house_sizes()[house_size]
	var r := sb.build_house(int(sz[0]), int(sz[1]), facing_dir.x, facing_dir.y)
	last_line = str(r["text"])
	if r["ok"]:
		var rect: Rect2i = r["rect"]
		for x in range(rect.position.x - 1, rect.end.x + 1):
			for z in range(rect.position.y - 1, rect.end.y + 1):
				tile_view.refresh_cell(x, z)
		house_preview = false
		_save()
	_refresh_status()
	queue_redraw()


func _repair() -> void:
	var r := sb.repair_at(facing_dir.x, facing_dir.y)
	last_line = str(r["text"])
	if r["ok"]:
		tile_view.refresh_cell(sb.heir.x + facing_dir.x, sb.heir.y + facing_dir.y)
		_save()
	_refresh_status()
	queue_redraw()


func _remove() -> void:
	var r := sb.remove_at(facing_dir.x, facing_dir.y)
	last_line = str(r["text"])
	if r["ok"]:
		tile_view.refresh_cell(sb.heir.x + facing_dir.x, sb.heir.y + facing_dir.y)
		_save()
	_refresh_status()
	queue_redraw()


## The piece button steps through the pieces in the data's order (eight would not fit a phone's bar as eight buttons).
func _next_piece() -> void:
	var kinds: Array = sb.build_kinds()
	_pick(kinds[(kinds.find(build_kind) + 1) % kinds.size()])


## The level button steps the build level up a storey and back to the ground (stairs and upper floors).
func _next_level(step: bool = true) -> void:
	if step:
		sb.cycle_level()
	level_button.text = "Level: %s" % sb.level_name()
	_refresh_status()
	queue_redraw()


func _pick(kind: String) -> void:
	build_kind = kind
	house_preview = false
	if piece_button != null:
		piece_button.text = "Piece: %s" % GameBuild.pieces()[kind]["name"]
	_refresh_status()
	queue_redraw()


func _set_mode(m: String) -> void:
	mode = m
	build_bar.visible = m == "build"
	_refresh_status()
	queue_redraw()


func _toggle_orders() -> void:
	orders_panel.visible = not orders_panel.visible
	_refresh_orders()


## One button per companion in the party: their name and the order they hold; a tap moves them to the next order.
func _refresh_orders() -> void:
	for c in orders_panel.get_children():
		c.queue_free()
	var d: GameDynasty = app.dynasty
	if d.party.members.is_empty():
		orders_panel.add_child(Kit.label(str(GameSandbox.data()["text"]["no_companions"]), 14, Kit.dim()))
		return
	for m in d.party.members:
		var id: String = str(m["id"])
		var label := "%s: %s" % [str(m["name"]), GameCompanions.order_name(GameCompanions.order_of(d, id))]
		var pts := GameSkillTree.points(d.party.unit(d, m))
		if pts > 0:   # skill points the player has yet to spend on this companion
			label += "  (%s skill point%s)" % [GameText.num(pts), "" if pts == 1 else "s"]
		orders_panel.add_child(Kit.button(label, func(): _cycle(id), Vector2(272, 44)))


func _cycle(id: String) -> void:
	var r := sb.cycle_order(id)
	last_line = str(r["text"])
	if r["ok"]:
		_save()
	_refresh_orders()
	_refresh_status()


## Dig and Place as big buttons at the right-hand thumb, for a touch layout (the top bar and the piece bar stay).
func _make_action_buttons() -> void:
	var px := float(setting("action_button_px"))
	actions = VBoxContainer.new()
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left = -px - 12.0
	actions.offset_right = -12.0
	actions.offset_top = -(px * 2.0 + 8.0) - BAR - 12.0
	actions.offset_bottom = -BAR - 12.0
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	actions.add_child(Kit.button("Dig", func(): _dig(), Vector2(px, px)))
	actions.add_child(Kit.button("Place", func(): _build(), Vector2(px, px)))


## Writes where the heir stands onto the dynasty, then saves it.
func _save() -> void:
	sb.remember()
	app.dynasty.save_to_disk()


func _exit_tree() -> void:
	if sb != null:
		sb.remember()   # leaving the screen (Back, a fight, a succession) keeps where the heir was


## The news line (`last_line`) is told as a toast.
func _set_line(v: String) -> void:
	last_line = v
	if toast != null and v != "":
		toast.say(v)


func _cell() -> float:
	return float(setting("cell_px")) * zoom


func _refresh_status() -> void:
	if not app.dynasty.party.tree_news.is_empty():   # a companion has earned skill points: the journal tells it (the pane shows it next refresh)
		GameSkillTree.announce_companions(app.dynasty)
	var d: GameDynasty = app.dynasty
	var line := ""   # the news is a toast now; the strip keeps the place and the build hint
	if mode == "build":
		var why := sb.build_check(build_kind, facing_dir.x, facing_dir.y)
		var piece := str(GameBuild.pieces()[build_kind]["name"])
		line = str(GameSandbox.data()["text"]["ready"]).format({"piece": piece}) if why == "" else why
	var room := sb.place_line()
	if sb.storey() > 0:
		line = room if line == "" else "%s %s" % [room, line]   # always say which storey the heir is on
	elif room != "" and mode != "build":
		line = room if line == "" else line
	if level_button != null:
		level_button.text = "Level: %s" % sb.level_name()
	_refresh_slots()
	if cast_button != null:
		cast_button.visible = GameDungeons.is_dungeon(sb.space) and not GameCasting.self_castable(d).is_empty()
	if smoke_button != null:
		smoke_button.text = "Smoke %d" % GameSmoke.count(d.heir) if GameSmoke.count(d.heir) > 0 else "Smoke"
		smoke_button.modulate = Color(1, 1, 1, 1.0 if GameSmoke.count(d.heir) > 0 else 0.45)
	var pin := _pin_line()
	status.text = "%s  %s  %s" % [GameDay.time_text(d), GameDay.look(d)["weather"], line] if pin == "" else "%s  %s  %s  %s" % [GameDay.time_text(d), GameDay.look(d)["weather"], pin, line]
	if UiSettings.touch() or UiSettings.compact(self):
		# no status pane here: the heir's level and experience (and a smoke pot's time) lead the one status line
		var h := d.heir
		var lead := "Lv %s  XP %s/%s" % [GameText.num(h.level), GameText.num(h.xp), GameText.num(h.xp_to_next())]
		if GameSmoke.active(d):
			lead += "  " + GameSmoke.text("timer", {"time": GameSmoke.clock_text(GameSmoke.left(d))})
		status.text = "%s  %s" % [lead, status.text]
	_refresh_plate()


## The status line's word on the map pin: "Pin: Kingshold, 212 tiles NE". Where the status pane is up it says so itself, so the line
## does not (a desktop window); on a touch screen and a narrow window the line is where it shows.
func _pin_line() -> String:
	if sb.space != "world" or not GameTravel.has_pin(app.dynasty):
		return ""
	for c in get_children():
		if c.get_script() == StatusPane and not c.is_queued_for_deletion():
			return ""
	return GameTravel.pin_line(app.dynasty, sb.heir)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0))


## Keeps the tile chunks of the view and puts them where the view is (the heir at the middle, the camera's offset, the zoom, the light).
func _sync_tiles() -> void:
	var d: GameDynasty = app.dynasty
	var area := Vector2(size.x, size.y - BAR)
	var cell := _cell()
	var centre := Vector2(sb.heir) + cam
	var light := clampf(float(GameDay.look(d)["light"]), float(setting("dim_floor")), 1.0)
	map.size = area
	var indoors := sb.space != "world"
	tile_view.set_interior(sb.space if indoors else "", sb.interior)
	if indoors:
		light = 1.0   # indoors it is always light
	tile_view.set_level(sb.build_level)
	tile_view.show_view(centre, area * 0.5 / cell + Vector2(1, 1))
	tile_view.set_heir(float(sb.heir.x) + 0.5, float(sb.heir.y) + 0.5)   # the lids of the family's houses lift as they come near
	tile_view.place(Vector2.ZERO, area, centre, cell, light)
	var half := area / (2.0 * cell) + Vector2(4, 4)
	GateArt.warm(d, Rect2i(floori(centre.x - half.x), floori(centre.y - half.y), ceili(half.x * 2.0), ceili(half.y * 2.0)), sb.realm_here())   # the arches' pictures are made here, not while drawing


## What is drawn over the tiles: the night's tint, the route, creatures, companions, the build ghost, the heir and the touch stick.
func _paint(c: Control) -> void:
	if glow_layer != null:
		glow_layer.queue_redraw()   # the lights and the sky are drawn with the overlay (also when the screen is held still)
		sky_layer.queue_redraw()
	var d: GameDynasty = app.dynasty
	var area := Vector2(size.x, size.y - BAR)
	var origin := Vector2(0, BAR)
	var cell := _cell()
	var colors: Dictionary = GameSandbox.data()["colors"]
	var look := GameDay.look(d)
	var centre := Vector2(sb.heir) + cam
	if sb.space == "world":
		WorldLook.paint_grade(c, Rect2(origin, area), look)   # the sun's warmth by day, the night's tint as the light fails (indoors: no night, and none of the open world's route, creatures or companions to draw)
	var outdoors := sb.space == "world"   # indoors none of the open world's route, creatures or companions is on this floor
	for i in range(sb.route.size() if outdoors else 0):
		var rp := origin + (Vector2(sb.route[i]) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
		c.draw_circle(rp, maxf(2.0, cell * 0.12), _rgb(colors["route"]))
	if outdoors:
		_paint_standing(c, origin, area, centre, cell, colors, float(look["light"]))
	elif GameDungeons.is_dungeon(sb.space):
		_paint_dungeon(c, origin, area, centre, cell, colors)
	else:
		_paint_interior(c, origin, area, centre, cell, colors)
	if mode == "build" and outdoors:
		var gp := origin + (Vector2(sb.heir + facing_dir) - centre) * cell + area * 0.5
		var legal := sb.build_check(build_kind, facing_dir.x, facing_dir.y) == ""
		var gc := Color(0.3, 0.9, 0.4, 0.9) if legal else Color(0.95, 0.3, 0.3, 0.9)
		c.draw_rect(Rect2(gp, Vector2(cell, cell)), gc, false, maxf(2.0, cell * 0.1))
	if mode == "build" and outdoors and house_preview:
		var sz: Array = sb.house_sizes()[house_size]
		var rc := sb.house_rect(int(sz[0]), int(sz[1]), facing_dir.x, facing_dir.y)
		var rp := origin + (Vector2(rc.position) - centre) * cell + area * 0.5
		c.draw_rect(Rect2(rp, Vector2(rc.size) * cell), Color(0.95, 0.85, 0.3, 0.9), false, maxf(2.0, cell * 0.1))
	if fingers.steering():
		var base := _rgb(colors["stick_base"])
		var radius := WorldInput.setting("touch_stick_radius_px")
		c.draw_arc(origin + fingers.origin, radius, 0.0, TAU, 40, Color(base, 0.5), 3.0)
		c.draw_circle(origin + fingers.knob(), radius * 0.35, Color(_rgb(colors["stick_knob"]), 0.7))


## The night's lights, drawn added to the picture: hearths and anvils the family built, camp fires and other glyphs that shine, and the
## lit windows of the town's buildings (WorldLook). Only the open world has any.
func _paint_glow(c: Control) -> void:
	if sb == null or sb.space != "world":
		return
	var look := GameDay.look(app.dynasty)
	if WorldLook.night_glow(look) <= 0.0:
		return
	var area := Vector2(size.x, size.y - BAR)
	var cell := _cell()
	var centre := Vector2(sb.heir) + cam
	var half := area / (2.0 * cell) + Vector2(4, 4)
	var view := Rect2i(floori(centre.x - half.x), floori(centre.y - half.y), ceili(half.x * 2.0), ceili(half.y * 2.0))
	WorldLook.paint_glow(c, WorldLook.glow_sources(app.dynasty, tile_view, view), look, cell, Vector2(0, BAR), area, centre)


## Fog, then rain or snow, then the vignette over the map (the weather only in the open world, and not with reduced motion).
func _paint_sky(c: Control) -> void:
	if sb == null:
		return
	var look := GameDay.look(app.dynasty)
	var rect := Rect2(Vector2(0, BAR), Vector2(size.x, size.y - BAR))
	if sb.space == "world":
		WorldLook.paint_fog(c, rect, look)
		WorldLook.paint_weather(c, rect, look)
	WorldLook.paint_vignette(c, rect, look)


## What stands on the open world's ground, drawn back to front (the ones further north first, so the ones in front cover them): the
## town buildings, the creatures, the companions and the heir, each as its sprite (a circle where there is none), dimmed at night.
func _paint_standing(c: Control, origin: Vector2, area: Vector2, centre: Vector2, cell: float, colors: Dictionary, light: float) -> void:
	var d: GameDynasty = app.dynasty
	var dim := Color.WHITE.darkened(float(setting("night_dim")) * (1.0 - light))
	var half := area / (2.0 * cell) + Vector2(3, 3)
	var view := Rect2i(floori(centre.x - half.x), floori(centre.y - half.y), ceili(half.x * 2.0), ceili(half.y * 2.0))
	var items: Array = []   # [depth, kind, thing]
	var tags: Array = []    # [screen point, creature agent]: the level tags, drawn over everything standing
	_bubble_pos.clear()
	for p in GameWalls.pieces_in(Rect2i(view.position.x - 2, view.position.y - 5, view.size.x + 4, view.size.y + 10)):
		items.append([float(int(p["z"]) + 1) + (0.5 if str(p["k"]) == "gate" else 0.0), "wall", p])
	for b in GameTown.in_rect(view):
		items.append([float(b["z"] + b["h"]), "building", b])
	for w in GameVillagers.walkers_near(d, centre.x, centre.y, half.length(), GameDay.hour(d)):
		items.append([float(w["z"]), "villager", w])
	for e in GameDungeonArt.entrances_in(view):
		items.append([float(e["rect"].end.y) - 0.1, "entrance", e])
	if sb.storey() == 0:
		for g in GateArt.in_view(d, view):   # the waygates: arches of old stone with a ring of runes
			items.append([float((g["rect"] as Rect2i).end.y) - 0.5, "gate", g])
	if sb.storey() == 0:
		for t in GameTrials.sites(d):
			if view.has_point(Vector2i(int(t["x"]), int(t["z"]))):
				items.append([float(int(t["z"])) + 0.5, "site", t])
	for a in sb.creatures:
		items.append([float(a["z"]) + 0.5, "creature", a])
	for a in sb.landmark_dwellers():
		items.append([float(a["z"]) + 0.5, "creature", a])
	for a in sb.companions:
		items.append([float(a["z"]) + 0.5, "companion", a])
	items.append([float(sb.heir.y) + 1.0, "heir", null])
	items.sort_custom(func(p, q): return p[0] < q[0])
	for it in items:
		match str(it[1]):
			"wall":
				_paint_wall(c, it[2], origin, area, centre, cell, dim)
			"building":
				var b: Dictionary = it[2]
				var at := origin + (Vector2(float(b["x"]), float(b["z"])) - centre) * cell + area * 0.5
				var box := Rect2(at, Vector2(float(b["w"]), float(b["h"])) * cell)
				var lid := GameReveal.alpha(GameReveal.distance_to(Rect2i(int(b["x"]), int(b["z"]), int(b["w"]), int(b["h"])), float(sb.heir.x) + 0.5, float(sb.heir.y) + 0.5))
				WorldLook.paint_building_shadow(c, box, cell)
				var inside: Texture2D = BuildingArt.inside(str(b["kind"]), int(b["style"]), int(b["w"]), int(b["h"])) if lid < 1.0 else null
				if inside != null:   # the roof thins and the rooms show, with the people who live there
					c.draw_texture_rect(inside, box, false, dim)
					_paint_residents(c, b, at, cell, dim)
				c.draw_texture_rect(BuildingArt.texture(str(b["kind"]), int(b["style"]), int(b["w"]), int(b["h"]), GameVillagers.door_scale(b)), box, false, Color(dim.r, dim.g, dim.b, lid) if inside != null else dim)
			"gate":
				var g: Dictionary = it[2]
				var gr: Rect2i = g["rect"]
				var gat := origin + (Vector2(gr.position) - centre) * cell + area * 0.5
				c.draw_texture_rect(GateArt.texture_of(d, str(g["id"])), Rect2(gat, Vector2(gr.size) * cell), false, dim)
			"entrance":
				var e: Dictionary = it[2]
				var er: Rect2i = e["rect"]
				var eat := origin + (Vector2(er.position) - centre) * cell + area * 0.5
				c.draw_texture_rect(DungeonEntranceArt.texture(str(e["place"])), Rect2(eat, Vector2(er.size) * cell), false, dim)
			"villager":
				var w: Dictionary = it[2]
				var p := origin + (Vector2(float(w["x"]), float(w["z"])) - centre) * cell + area * 0.5
				var tex := _villager_tex(w)
				if tex != null:
					var fs := _figure_size(tex, cell) * float(w["scale"])
					_stand(c, _shown(_villager_frames(w), tex, "v%s" % w["id"], Vector2(float(w["x"]), float(w["z"]))), p + Vector2(0, cell * 0.3), fs, _villager_flip(w, int(w["dx"]) < 0), dim, cell)
					_bubble_pos[str(w["id"])] = p + Vector2(0, cell * 0.3 - fs.y)
			"site":
				var t: Dictionary = it[2]
				var tp := origin + (Vector2(float(t["x"]) + 0.5, float(t["z"]) + 0.5) - centre) * cell + area * 0.5
				var ring := Kit.good() if bool(t["passed"]) else Color(0.8, 0.55, 0.95)
				c.draw_set_transform(tp + Vector2(0, cell * 0.3), 0.0, Vector2(1.0, 0.4))   # a ring of standing stones on the ground, in perspective
				c.draw_arc(Vector2.ZERO, cell * 1.1, 0.0, TAU, 28, Color(ring.r, ring.g, ring.b, 0.9), maxf(2.0, cell * 0.12))
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				var mtex: Texture2D = SpriteArt.master(str(t["id"]))
				if mtex == null:
					mtex = SpriteArt.creature(str(t["master_id"]))
				if mtex == null:
					c.draw_circle(tp, maxf(2.0, cell * 0.3), ring)
				else:
					var ms := cell / 16.0 * float(setting("creature_pixel"))
					var mw := minf(mtex.get_width() * ms, cell * float(setting("creature_max_tiles")))
					var mh := mw * float(mtex.get_height()) / float(mtex.get_width())
					_stand(c, mtex, tp + Vector2(0, cell * 0.3), Vector2(mw, mh), false, dim, cell)   # the art faces left, and so does the master (a mirrored figure is drawn a box to the right, see _stand)   # the art faces left; the master turns to the heir
			"creature":
				var a: Dictionary = it[2]
				if tile_view.covered(floori(float(a["x"])), floori(float(a["z"]))):
					continue   # under a whole roof: not seen
				var p := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
				var tex: Texture2D = SpriteArt.creature(str(a["id"]))
				if tex == null:
					c.draw_circle(p, maxf(2.0, cell * 0.3), _rgb(colors["creature"]))
				else:
					var s := cell / 16.0 * float(setting("creature_pixel"))
					var w := minf(tex.get_width() * s, cell * float(setting("creature_max_tiles")))
					var h := w * float(tex.get_height()) / float(tex.get_width())
					_stand(c, _shown(SpriteArt.creature_frames(str(a["id"])), tex, "c%s" % a["uid"], Vector2(float(a["x"]), float(a["z"]))), p + Vector2(0, cell * 0.3), Vector2(w, h), _faces_right("c%s" % a["uid"], float(a["x"])), dim, cell)   # the art faces left
				if GameSandbox.level_of(a) > 0:
					tags.append([p, a])
			"companion":
				var a: Dictionary = it[2]
				if tile_view.covered(floori(float(a["x"])), floori(float(a["z"]))):
					continue
				var p := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
				var tex: Texture2D = _party_figure(str(a["id"]))
				if str(a["id"]) == selected_companion:   # the chosen one stands in a ring, and their post is marked
					c.draw_arc(p + Vector2(0, cell * 0.3), cell * 0.7, 0.0, TAU, 28, Kit.ACCENT, 2.0)
					if str(a["order"]) in ["stay", "guard", "watch", "gather"]:
						var post := origin + (Vector2(float(a["post_x"]), float(a["post_z"])) - centre) * cell + area * 0.5
						c.draw_rect(Rect2(post - Vector2(3, 3), Vector2(6, 6)), Kit.ACCENT, false, 1.5)
				if tex == null:
					c.draw_circle(p, maxf(2.0, cell * 0.3), _rgb(colors["companion"]))
				else:
					_stand(c, _shown(_party_frames(str(a["id"])), tex, "p%s" % a["id"], Vector2(float(a["x"]), float(a["z"]))), p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * _party_scale(str(a["id"])), not _faces_right("p%s" % a["id"], float(a["x"])), dim, cell)   # the art faces right
			"heir":
				var p := origin + (Vector2(sb.heir) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
				var tex: Texture2D = SpriteArt.figure(d.heir)
				if tex == null:
					c.draw_circle(p, maxf(3.0, cell * 0.4), _rgb(colors["heir"]))
				else:
					_stand(c, _shown(SpriteArt.figure_frames(d.heir), tex, "heir", Vector2(sb.heir)), p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * GameVillagers.scale_of(d.heir.race_id), facing_dir.x < 0, dim, cell)
	for t in tags:
		_paint_level_tag(c, t[0], t[1], cell)
	_paint_bubbles(c)
	_paint_name(c, origin, area, centre, cell)
	_paint_smoke(c, origin, area, centre, cell)


## The text a click's name tag shows: a creature's name carries its level and band mark ("Wolf  Lv 12 =").
func _named_text(named: Dictionary) -> String:
	if int(named.get("level", 0)) > 0:
		return "%s  Lv %s %s" % [str(named["name"]), GameText.num(int(named["level"])), GameLevels.mark(str(named["con"]))]
	return str(named["name"])


## The colour of a band's tag, from the Kit's tokens (so high contrast and the colour-blind setting keep working).
static func band_color(id: String) -> Color:
	match GameLevels.color_token(id):
		"good":
			return Kit.good()
		"bad":
			return Kit.bad()
		"dim":
			return Kit.dim()
		"accent":
			return Kit.ACCENT
	return Kit.TEXT


## "Lv 12 =" over a creature, coloured by its band (grey, green, white, yellow, red for trivial to deadly) with the band's mark after it,
## so the colour is never the only cue, on a dark chip so it reads on any ground.
func _paint_level_tag(c: Control, at: Vector2, a: Dictionary, cell: float) -> void:
	var id := sb.con(GameSandbox.level_of(a))
	var text := "Lv %s %s" % [GameText.num(GameSandbox.level_of(a)), GameLevels.mark(id)]
	var fs := clampi(int(round(11.0 * maxf(zoom, 0.8))), 10, 15)
	var font := ThemeDB.fallback_font
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var top := at + Vector2(0, -cell * 0.75)
	var box := Rect2(top + Vector2(-sz.x * 0.5 - 3.0, -sz.y - 1.0), sz + Vector2(6.0, 3.0))
	c.draw_rect(box, Color(0.04, 0.04, 0.07, 0.72))
	c.draw_string(font, box.position + Vector2(3.0, sz.y - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, band_color(id))


## The smoke pot's cloud, over the zone it covers: soft grey puffs whose places are a hash of their number, drifting a little with the
## time (still with reduced motion). Look only: nothing here changes the game.
func _paint_smoke(c: Control, origin: Vector2, area: Vector2, centre: Vector2, cell: float) -> void:
	var cloud: Variant = GameSmoke.centre(app.dynasty)
	if cloud == null or sb.space != "world":
		return
	WorldLook.paint_smoke(c, cloud, GameSmoke.radius(), int(GameSmoke.data()["puffs"]), origin, area, centre, cell, GameSmoke.left(app.dynasty) / float(GameSmoke.data()["seconds"]))


## What a click just named, over the thing for a moment.
func _paint_name(c: Control, origin: Vector2, area: Vector2, centre: Vector2, cell: float) -> void:
	if _name_tag.is_empty():
		return
	if int(_name_tag["until"]) < Time.get_ticks_msec():
		_name_tag = {}
		return
	var font := ThemeDB.fallback_font
	var text := str(_name_tag["text"])
	var at: Vector2 = origin + (Vector2(_name_tag["point"]) - Vector2(0.5, 0.5) - centre) * cell + area * 0.5 - Vector2(0, cell * 0.9)
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var box := Rect2(at + Vector2(-sz.x * 0.5 - 6.0, -sz.y - 4.0), sz + Vector2(12.0, 6.0))
	if skinned:
		c.draw_style_box(UiSkin.plate_box(true), box.grow(5.0))
		c.draw_string(font, box.position + Vector2(6.0, sz.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiSkin.pal("ink"))
	else:
		c.draw_style_box(Kit.style(Color(0.1, 0.09, 0.14, 0.9), 5, Color(0.88, 0.7, 0.25)), box)
		c.draw_string(font, box.position + Vector2(6.0, sz.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.88, 0.94))
	queue_redraw()


## One piece of a town's wall: a wall, a tower, the tower by a gate (with the town's banner), or the arch or beam over a gate's passage
## (high above the ground, so a walker goes under it). A piece fades while the heir stands behind it, so they are never lost.
func _paint_wall(c: Control, p: Dictionary, origin: Vector2, area: Vector2, centre: Vector2, cell: float, dim: Color) -> void:
	var k := str(p["k"])
	var x := int(p["x"])
	var z := int(p["z"])
	var tex: Texture2D
	var top: float
	if k == "gate":
		var ns := str(p["a"]) == "ns"
		tex = WallArt.texture("arch" if ns else "beam", int(p["i"]) if ns else (x + z) % 2)
		top = float(z + 1) - float(WallArt.data()["lintel_height"]) - WallArt.tiles_tall("arch")
	else:
		tex = WallArt.texture(k, (x + z) % 2, _banner(str(p["p"])))
		top = float(z + 1) - WallArt.tiles_tall(k)
	if k == "gate" and GameWalls.shut_now(app.dynasty):   # the leaves are closed by night
		var leaf := WallArt.texture("leaf", (x + z) % 2)
		var lat := origin + (Vector2(float(x), float(z + 1) - WallArt.tiles_tall("leaf")) - centre) * cell + area * 0.5
		c.draw_texture_rect(leaf, Rect2(lat, Vector2(cell, leaf.get_height() * cell / 16.0)), false, dim)
	var a := WallArt.fade(Vector2i(x, z), k, Vector2(float(sb.heir.x) + 0.5, float(sb.heir.y) + 0.5)) if k != "gate" else 1.0
	var at := origin + (Vector2(float(x), top) - centre) * cell + area * 0.5
	c.draw_texture_rect(tex, Rect2(at, Vector2(cell, tex.get_height() * cell / 16.0)), false, Color(dim.r, dim.g, dim.b, a))


func _banner(place: String) -> Color:
	if not _banners.has(place):
		_banners[place] = Color.html(str(GameVillagers.data()["guards"]["colors"].get(place, "#b8403a")))
	return _banners[place]


## What people have just said, in a bubble over their heads (a few seconds; one line each, the longest wrapped).
func _paint_bubbles(c: Control) -> void:
	var now := Time.get_ticks_msec()
	var font := ThemeDB.fallback_font
	for id in _bubbles.keys():
		var b: Dictionary = _bubbles[id]
		if int(b["until"]) < now:
			_bubbles.erase(id)
			continue
		if not _bubble_pos.has(id):
			continue
		var head: Vector2 = _bubble_pos[id]
		var line := str(b["text"])
		var width := 200.0
		var sz := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, width, 13)
		var box := Rect2(head + Vector2(-sz.x * 0.5 - 6.0, -sz.y - 16.0), sz + Vector2(12.0, 8.0))
		var paper := Color(0.96, 0.94, 0.86, 0.95)
		var ink := Color(0.1, 0.09, 0.14)
		if skinned:
			paper = UiSkin.pal("parch")
			ink = UiSkin.pal("ink")
			c.draw_style_box(UiSkin.plate_box(false), box.grow(5.0))
		else:
			c.draw_style_box(Kit.style(paper, 6, ink), box)
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(-4, -8), head + Vector2(4, -8), head + Vector2(0, -2)]), paper)
		c.draw_multiline_string(font, box.position + Vector2(6.0, 4.0 + 13.0), line, HORIZONTAL_ALIGNMENT_LEFT, width, 13, -1, ink)


## A dungeon's floor seen by the heir: its creatures and the heir as sprites (a circle where there is none), then the dark over
## it all: each tile as dark as GameDungeonArt.darkness says (the heir's own light, torches, braziers and lava lighten it).
func _paint_dungeon(c: Control, origin: Vector2, area: Vector2, centre: Vector2, cell: float, colors: Dictionary) -> void:
	var d: GameDynasty = app.dynasty
	var items: Array = []
	for a in sb.denizens:
		items.append([float(a["z"]) + 0.5, "foe", a])
	for pr in GameDungeons.layout(sb.space).get("people", []):
		items.append([float(pr["z"]) + 0.5, "person", pr])
	for a in sb.companions:
		items.append([float(a["z"]) + 0.5, "companion", a])
	items.append([float(sb.heir.y) + 1.0, "heir", null])
	items.sort_custom(func(p, q): return p[0] < q[0])
	for it in items:
		if str(it[1]) == "person":
			var pr: Dictionary = it[2]
			var p := origin + (Vector2(float(pr["x"]) + 0.5, float(pr["z"]) + 0.5) - centre) * cell + area * 0.5
			var tex: Texture2D = SpriteArt.hero(str(pr["race"]), str(pr["class"]), Color.html(str(pr["color"])))
			if tex == null:
				c.draw_circle(p, maxf(3.0, cell * 0.35), Color.html(str(pr["color"])))
			else:
				_stand(c, _shown(SpriteArt.hero_frames(str(pr["race"]), str(pr["class"]), Color.html(str(pr["color"]))), tex, "d%s" % pr.get("id", "%s,%s" % [pr["x"], pr["z"]]), Vector2(float(pr["x"]), float(pr["z"]))), p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * GameVillagers.scale_of(str(pr["race"])), false, Color.WHITE, cell)
		elif str(it[1]) == "companion":
			var a: Dictionary = it[2]
			var p := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
			var tex: Texture2D = _party_figure(str(a["id"]))
			if tex == null:
				c.draw_circle(p, maxf(2.0, cell * 0.3), _rgb(colors["companion"]))
			else:
				_stand(c, _shown(_party_frames(str(a["id"])), tex, "p%s" % a["id"], Vector2(float(a["x"]), float(a["z"]))), p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * _party_scale(str(a["id"])), not _faces_right("p%s" % a["id"], float(a["x"])), Color.WHITE, cell)
		elif str(it[1]) == "foe":
			var a: Dictionary = it[2]
			var p := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
			var tex: Texture2D = SpriteArt.creature(str(a["id"]))
			if tex == null:
				c.draw_circle(p, maxf(2.0, cell * 0.3), _rgb(colors["creature"]))
			else:
				var s := cell / 16.0 * float(setting("creature_pixel"))
				var w := minf(tex.get_width() * s, cell * float(setting("creature_max_tiles")))
				var h := w * float(tex.get_height()) / float(tex.get_width())
				_stand(c, _shown(SpriteArt.creature_frames(str(a["id"])), tex, "c%s" % a["uid"], Vector2(float(a["x"]), float(a["z"]))), p + Vector2(0, cell * 0.3), Vector2(w, h), _faces_right("c%s" % a["uid"], float(a["x"])), Color.WHITE, cell)
		else:
			var p := origin + (Vector2(sb.heir) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
			var tex: Texture2D = SpriteArt.figure(d.heir)
			if tex == null:
				c.draw_circle(p, maxf(3.0, cell * 0.4), _rgb(colors["heir"]))
			else:
				_stand(c, _shown(SpriteArt.figure_frames(d.heir), tex, "heir", Vector2(sb.heir)), p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * GameVillagers.scale_of(d.heir.race_id), facing_dir.x < 0, Color.WHITE, cell)
	var th := GameDungeonArt.theme(sb.space)
	if th.is_empty():
		return
	var tint: Array = th["light"]["tint"]
	var lights := GameDungeonArt.lights(sb.space)
	for k in sb.interior:
		var t := GameInterior._parse(k)
		var at := origin + (Vector2(t) - centre) * cell + area * 0.5
		if at.x > origin.x + area.x or at.y > origin.y + area.y or at.x + cell < origin.x or at.y + cell < origin.y:
			continue
		var dark := GameDungeonArt.darkness(sb.space, t.x, t.y, sb.heir.x, sb.heir.y, lights)
		if dark > 0.01:
			c.draw_rect(Rect2(at, Vector2(cell, cell)).grow(0.5), Color(float(tint[0]), float(tint[1]), float(tint[2]), dark))


## The inside of a town building or the family's house: the person who works there and the heir, each as their figure, the one further
## north first. (A circle only where there is no art, as everywhere.)
func _paint_interior(c: Control, origin: Vector2, area: Vector2, centre: Vector2, cell: float, colors: Dictionary) -> void:
	var d: GameDynasty = app.dynasty
	var items: Array = []   # [depth, kind, thing]
	for pr in GamePeople.in_space(sb.space):
		items.append([float(GamePeople.cell_of(pr).y) + 1.0, "person", pr])
	items.append([float(sb.heir.y) + 1.0, "heir", null])
	items.sort_custom(func(p, q): return p[0] < q[0])
	var service: Dictionary = GameVillagers.data()["service"].get(str(GameSpaces.space(sb.space).get("layout", "")), {})
	if sb.realm_here() != "":   # a realm's arrival ground: its own colours over the plain floor, the return gate over the way in
		GateArt.paint_arrival(c, sb.realm_here(), sb.interior, origin, area, centre, cell)
	for it in items:
		if str(it[1]) == "person":
			var t := GamePeople.cell_of(it[2])
			var p := origin + (Vector2(t) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
			var tex: Texture2D = null
			if not service.is_empty():
				tex = SpriteArt.hero(str(service["race"]), str(service["class"]), Color.html(str(service["color"])))
			if tex == null:
				c.draw_circle(p, maxf(3.0, cell * 0.35), _rgb(colors["companion"]))
			else:
				_stand(c, tex, p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * GameVillagers.scale_of(str(service["race"])), false, Color.WHITE, cell)
		else:
			var hp := origin + (Vector2(sb.heir) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
			var tex: Texture2D = SpriteArt.figure(d.heir)
			if tex == null:
				c.draw_circle(hp, maxf(3.0, cell * 0.4), _rgb(colors["heir"]))
			else:
				_stand(c, tex, hp + Vector2(0, cell * 0.3), _figure_size(tex, cell) * GameVillagers.scale_of(d.heir.race_id), facing_dir.x < 0, Color.WHITE, cell)


## Makes the figures of everyone who may be drawn now, together: the villagers, the heir and the companions (a figure first made while
## drawing makes the atlas upload mid-frame, which blanks the sprites drawn before it in that frame).
func _warm_figures() -> void:
	SpriteArt.begin_batch()
	var d: GameDynasty = app.dynasty
	SpriteArt.figure(d.heir)
	for pr in GameDungeons.layout(sb.space).get("people", []):
		SpriteArt.hero(str(pr["race"]), str(pr["class"]), Color.html(str(pr["color"])))
	var service: Dictionary = GameVillagers.data()["service"].get(str(GameSpaces.space(sb.space).get("layout", "")), {})
	if not service.is_empty():
		SpriteArt.hero(str(service["race"]), str(service["class"]), Color.html(str(service["color"])))   # the one who works in the building we are in
	for m in d.party.members:
		_party_figure(str(m["id"]))
	for b in GameTown.all():
		for r in GameVillagers.residents(b):
			_villager_tex(r)
			_villager_frames(r)
	for g in GameWalls.all_gates():
		for r in GameVillagers.guards(g):
			_villager_tex(r)
			_villager_frames(r)
	_warm_frames()
	SpriteArt.end_batch()


## Makes the walk and idle frames of everyone who may be drawn: the heir, the companions, the dungeon's people, the
## villagers and the creatures about (with the figures, in a batch: see _warm_figures). Frames made while drawing would
## blank the sprites drawn before them, so this runs before each frame is drawn, and costs a lookup once they are made.
func _warm_frames() -> void:
	var d: GameDynasty = app.dynasty
	SpriteArt.figure_frames(d.heir)
	for m in d.party.members:
		_party_frames(str(m["id"]))
	for pr in GameDungeons.layout(sb.space).get("people", []):
		SpriteArt.hero_frames(str(pr["race"]), str(pr["class"]), Color.html(str(pr["color"])))
	for a in sb.creatures:
		SpriteArt.creature_frames(str(a["id"]))
	for a in sb.denizens:
		SpriteArt.creature_frames(str(a["id"]))
	for a in sb.landmark_dwellers():
		SpriteArt.creature_frames(str(a["id"]))


## The frame to draw for something at `pos`: its walk frames while it has moved in the last moment, its idle ones
## otherwise, and the plain `tex` when it has no frames. Cosmetic state only, kept per `key`, like _faces_right.
func _shown(frames: Dictionary, tex: Texture2D, key: String, pos: Vector2) -> Texture2D:
	if frames.is_empty():
		return tex
	var now := float(Time.get_ticks_msec()) / 1000.0
	var before: Variant = _last_pos.get(key)
	if before != null and (before as Vector2).distance_to(pos) > 0.001:
		_moved_at[key] = now
	_last_pos[key] = pos
	return SpriteMotion.pick(frames, key, SpriteMotion.still_moving(float(_moved_at.get(key, -1000.0)), now), now)


## A villager's frames, as _villager_tex is their picture.
func _villager_frames(r: Dictionary) -> Dictionary:
	if str(r.get("creature", "")) != "":
		return SpriteArt.creature_frames(str(r["creature"]))
	return SpriteArt.hero_frames(str(r["race"]), str(r["class"]), Color.html(str(r["color"])))


## A companion's frames, kept for as long as they stay the same level (like _party_figure).
func _party_frames(id: String) -> Dictionary:
	var d: GameDynasty = app.dynasty
	var m: Dictionary = d.party.member(id)
	if m.is_empty():
		return {}
	return SpriteArt.figure_frames(d.party.unit(d, m))


## A villager's picture: a person's figure in their race's colours, or a monster's own art.
func _villager_tex(r: Dictionary) -> Texture2D:
	if str(r.get("creature", "")) != "":
		return SpriteArt.creature(str(r["creature"]))
	return SpriteArt.hero(str(r["race"]), str(r["class"]), Color.html(str(r["color"])))


## Whether to turn a villager's picture round: a person's art faces right and a monster's left; `left` is whether they look west.
func _villager_flip(r: Dictionary, left: bool) -> bool:
	return (not left) if str(r.get("creature", "")) != "" else left


## The people of a building with its roof off (GameVillagers: where they are at this hour; by night they lie in their beds).
func _paint_residents(c: Control, b: Dictionary, at: Vector2, cell: float, dim: Color) -> void:
	var d: GameDynasty = app.dynasty
	var hour := GameDay.hour(d)
	var night := GameDay.is_night(d)
	var who: Array = GameVillagers.residents(b)
	for i in who.size():
		var r: Dictionary = who[i]
		if not GameVillagers.present(d, b, i, hour):
			continue   # out in the street (or in the service they went to)
		var tex := _villager_tex(r)
		if tex == null:
			continue
		var sp: Dictionary = GameVillagers.spot(b, i, hour, night)
		var cellv: Vector2i = sp["cell"]
		if bool(sp["asleep"]):   # lying along the bed (two tiles long, a tile deep), head to the west
			var box := _figure_size(tex, cell) * 0.9 * float(r["scale"])
			c.draw_set_transform(at + (Vector2(cellv) + Vector2(1.0, 0.5)) * cell, -PI / 2.0, Vector2.ONE)
			c.draw_texture_rect(tex, Rect2(-box * 0.5, box), false, dim)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var rs := _figure_size(tex, cell) * float(r["scale"])
			var feet := at + (Vector2(cellv) + Vector2(0.5, 0.85)) * cell
			_stand(c, _shown(_villager_frames(r), tex, "v%s" % r["id"], Vector2(b["x"], b["z"]) + Vector2(cellv)), feet, rs, _villager_flip(r, false), dim, cell)
			_bubble_pos[str(r["id"])] = feet - Vector2(0, rs.y)


## Whether a creature or companion last moved to the east: it faces the way it last went (kept per key, for the look only).
func _faces_right(key: String, x: float) -> bool:
	var before: Variant = _last_x.get(key)
	_last_x[key] = x
	if before != null and absf(x - float(before)) > 0.001:
		_east[key] = x > float(before)
	return bool(_east.get(key, false))


## A figure `figure_tiles` tall, whatever its pixels.
func _figure_size(tex: Texture2D, cell: float) -> Vector2:
	var h := cell * float(setting("figure_tiles"))
	return Vector2(h * float(tex.get_width()) / float(tex.get_height()), h)


## Draws a sprite standing with its feet at `feet`, on a shadow, turned the other way when `flip`. A turned figure is drawn through a transform that mirrors
## it about the middle of its box, so it stands on the same ground as the unturned one (a rect with a negative width does not: it is drawn a box to the right).
func _stand(c: Control, tex: Texture2D, feet: Vector2, box: Vector2, flip: bool, tint: Color, cell: float) -> void:
	c.draw_set_transform(feet, 0.0, Vector2(1.0, 0.4))
	c.draw_circle(Vector2.ZERO, box.x * 0.4, Color(0, 0, 0, float(setting("shadow_alpha"))))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var at := feet - Vector2(box.x * 0.5, box.y - cell * 0.1)
	if flip:
		c.draw_set_transform(at + Vector2(box.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, box), false, tint)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		c.draw_texture_rect(tex, Rect2(at, box), false, tint)


## A companion's size against a human, by their race (a halfling is smaller, an orc larger).
func _party_scale(id: String) -> float:
	var m: Dictionary = app.dynasty.party.member(id)
	if m.is_empty():
		return 1.0
	var key := "%s:%d" % [id, int(m.get("level", 0))]
	if not _scales.has(key):
		_scales[key] = GameVillagers.scale_of(app.dynasty.party.unit(app.dynasty, m).race_id)
	return float(_scales[key])


## A companion's figure (their class in their race's colours), kept for as long as they stay the same level.
func _party_figure(id: String) -> Texture2D:
	var d: GameDynasty = app.dynasty
	var m: Dictionary = d.party.member(id)
	if m.is_empty():
		return null
	var key := "%s:%d" % [id, int(m.get("level", 0))]
	if not _figures.has(key):
		_figures[key] = SpriteArt.figure(d.party.unit(d, m))
	return _figures[key]


## The control over the tiles: it only hands its drawing back to the screen.
class Overlay extends Control:
	var screen: Control

	func _draw() -> void:
		if screen != null:
			screen._paint(self)


static func _rgb(v: Array) -> Color:
	return Color(float(v[0]), float(v[1]), float(v[2]))
