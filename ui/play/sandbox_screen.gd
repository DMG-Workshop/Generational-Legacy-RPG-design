## The open world as a screen (roadmap items 39 and 51): a top-down map of the generated ground round the heir, drawn from
## GameSandbox, with the world's input (ui/play/world_input.gd) and the day's light (GameDay). Nothing here works out a
## result: it reads GameSandbox and GameDay, calls them, and draws. While it is open the world clock runs (GameClock), the
## world's own time, so a fight, a succession or an ended saga hands the screen back to the app at once.
## Tap a tile to walk there (a route over the ground as it is now); the keys or the stick walk the heir one tile at a time.
extends Control

const Kit := preload("res://ui/play/ui_kit.gd")
const SpriteArt := preload("res://ui/play/sprite_art.gd")
const WorldInput := preload("res://ui/play/world_input.gd")
const UiSettings := preload("res://ui/play/ui_settings.gd")
const TouchControls := preload("res://ui/play/touch_controls.gd")
const CraftPanel := preload("res://ui/play/craft_panel.gd")
const ShopPanel := preload("res://ui/play/shop_panel.gd")
const TavernPanel := preload("res://ui/play/tavern_panel.gd")
const BoardPanel := preload("res://ui/play/board_panel.gd")
const WorldMapPanel := preload("res://ui/play/world_map_panel.gd")
const MerchantPanel := preload("res://ui/play/merchant_panel.gd")
const TalkPanel := preload("res://ui/play/talk_panel.gd")
const BattleView := preload("res://ui/play/battle_view.gd")
const MapFight := preload("res://ui/play/map_fight.gd")
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
var build_bar: HBoxContainer
var orders_panel: VBoxContainer
var fingers := TouchControls.new()   # the stick and the pinch of a touch screen
var actions: VBoxContainer           # Dig and Place under the thumb, shown only with a touch layout
var status: Label
var map: Control          # clips the tile view to the map area, under the bar and the overlay
var tile_view: TileView   # the ground, as tile chunks
var overlay: Control      # the route, buildings, creatures, heir, ghost and stick, over the tiles
var _figures := {}        # companion id and level -> their figure's texture (SpriteArt)
var _last_x := {}         # creature or companion -> where it was drawn last (the look only)
var _east := {}           # creature or companion -> whether it last moved east
var _fight: Control = null   # the battle screen, hosted over the map while a creature's fight is on
var piece_button: Button
var level_button: Button
var last_line := ""
var _walk_wait := 0.0
var _greet_wait := 0.0
var _bubbles := {}        # a person's id -> {text, until (msec)}: what they just said, over their head
var _bubble_pos := {}     # a person's id -> where their head was drawn last (screen)
var _banners := {}        # place -> the colour of its gate guards and banners
var _tick_wait := 0.0
var _save_wait := 0.0
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
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 4)
	bar.size = Vector2(maxf(0.0, size.x - 16.0), BAR - 8.0)
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	bar.add_child(Kit.button("Back", func(): app.show_state(), Vector2(88, BAR - 12)))
	bar.add_child(Kit.button("Dig", func(): _dig(), Vector2(72, BAR - 12)))
	bar.add_child(Kit.button("Forage", func(): _forage(), Vector2(88, BAR - 12)))
	bar.add_child(Kit.button("Build", func(): _set_mode("walk" if mode == "build" else "build"), Vector2(88, BAR - 12)))
	bar.add_child(Kit.button("Orders", func(): _toggle_orders(), Vector2(96, BAR - 12)))
	bar.add_child(Kit.button("Map", func(): _open_world_map(), Vector2(64, BAR - 12)))
	bar.add_child(Kit.button("Use", func(): _use(), Vector2(64, BAR - 12)))
	bar.add_child(Kit.button("Up", func(): _climb(-1), Vector2(64, BAR - 12)))
	bar.add_child(Kit.button("Down", func(): _climb(1), Vector2(72, BAR - 12)))
	status = Kit.label("", 14, Kit.dim())
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	bar.add_child(status)
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
	_walk_wait -= delta
	var stepped := false
	if step_for(mv) != Vector2i.ZERO:
		sb.route = []
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
	var lines := GameClock.feed(d, delta)
	for e in lines:
		last_line = str(e.get("text", e)) if e is Dictionary else str(e)
	_save_wait -= delta
	if _save_wait <= 0.0:
		_save()
		_save_wait = float(setting("save_seconds"))
	if inp["cancel"]:
		app.show_state()
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
	overlay.queue_redraw()
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var e := event as InputEventMouseButton
		var area := Vector2(size.x, size.y - BAR)
		if e.pressed:
			_press = e.position
			_press_ms = Time.get_ticks_msec()
		elif WorldInput.is_tap(_press, e.position, float(Time.get_ticks_msec() - _press_ms) / 1000.0):
			_tap(e.position - Vector2(0, BAR), area)


func _tap(p: Vector2, area: Vector2) -> void:
	if p.y < 0.0 or p.y > area.y:
		return
	var tile := tile_at(p, area, sb.heir, cam, _cell())
	var dx := tile.x - sb.heir.x
	var dz := tile.y - sb.heir.y
	if mode == "build":
		if absi(dx) <= 1 and absi(dz) <= 1 and (dx != 0 or dz != 0):
			facing_dir = Vector2i(dx, dz)   # a tap beside the heir aims the piece there
		_refresh_status()
		queue_redraw()
		return
	if absi(dx) <= 1 and absi(dz) <= 1 and (dx != 0 or dz != 0):
		sb.route = []
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


## The workshop over the map, at the family's forge: while it is open the world waits and the keys do nothing here.
func _open_workshop(forge: String) -> void:
	var panel: Control = CraftPanel.new()
	panel.dynasty = app.dynasty
	panel.on_change = func(): _refresh_status()
	panel.forge = forge
	add_child(panel)


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
	add_child(panel)


## A wilds trader's panel over the map (GameWildsTrade): the world waits while it is open.
func _open_merchant(lm: Dictionary) -> void:
	var panel: Control = MerchantPanel.new()
	panel.dynasty = app.dynasty
	panel.landmark = lm
	panel.on_change = func(): _refresh_status()
	panel.set_meta("modal", true)
	add_child(panel)


## The world map over the open world (GameWorldMap): the world waits while it is open.
func _open_world_map() -> void:
	var panel: Control = WorldMapPanel.new()
	panel.dynasty = app.dynasty
	if sb.space == "world":
		panel.heir_tile = sb.heir
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


## The Use action: in by the door the heir stands at, or out by the entrance of the interior they are in.
func _use() -> void:
	var r := sb.use()
	last_line = str(r["text"])
	cam = Vector2.ZERO
	if str(r.get("open", "")) == "workshop":
		_open_workshop(str(r.get("forge", "")))
	elif str(r.get("open", "")) in ["shop", "tavern", "board"]:
		_open_service(str(r["open"]), str(r.get("tab", "")))
	elif str(r.get("open", "")) == "merchant":
		_open_merchant(r["landmark"])
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
	add_child(panel)


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


func _cell() -> float:
	return float(setting("cell_px")) * zoom


func _refresh_status() -> void:
	var d: GameDynasty = app.dynasty
	var line := last_line
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
	status.text = "%s  %s  %s" % [GameDay.time_text(d), GameDay.look(d)["weather"], line]


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


## What is drawn over the tiles: the night's tint, the route, creatures, companions, the build ghost, the heir and the touch stick.
func _paint(c: Control) -> void:
	var d: GameDynasty = app.dynasty
	var area := Vector2(size.x, size.y - BAR)
	var origin := Vector2(0, BAR)
	var cell := _cell()
	var colors: Dictionary = GameSandbox.data()["colors"]
	var look := GameDay.look(d)
	var centre := Vector2(sb.heir) + cam
	var tint: Array = look["tint"]
	var night_alpha := (1.0 - float(look["light"])) * 0.5
	if sb.space != "world":
		night_alpha = 0.0   # indoors: no night, and none of the open world's route, creatures or companions to draw
	if night_alpha > 0.0:
		c.draw_rect(Rect2(origin, area), Color(float(tint[0]), float(tint[1]), float(tint[2]), night_alpha))
	var outdoors := sb.space == "world"   # indoors none of the open world's route, creatures or companions is on this floor
	for i in range(sb.route.size() if outdoors else 0):
		var rp := origin + (Vector2(sb.route[i]) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
		c.draw_circle(rp, maxf(2.0, cell * 0.12), _rgb(colors["route"]))
	if outdoors:
		_paint_standing(c, origin, area, centre, cell, colors, float(look["light"]))
	elif GameDungeons.is_dungeon(sb.space):
		_paint_dungeon(c, origin, area, centre, cell, colors)
	else:
		var hp := origin + (Vector2(sb.heir) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
		c.draw_circle(hp, maxf(3.0, cell * 0.4), _rgb(colors["heir"]))
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


## What stands on the open world's ground, drawn back to front (the ones further north first, so the ones in front cover them): the
## town buildings, the creatures, the companions and the heir, each as its sprite (a circle where there is none), dimmed at night.
func _paint_standing(c: Control, origin: Vector2, area: Vector2, centre: Vector2, cell: float, colors: Dictionary, light: float) -> void:
	var d: GameDynasty = app.dynasty
	var dim := Color.WHITE.darkened(float(setting("night_dim")) * (1.0 - light))
	var half := area / (2.0 * cell) + Vector2(3, 3)
	var view := Rect2i(floori(centre.x - half.x), floori(centre.y - half.y), ceili(half.x * 2.0), ceili(half.y * 2.0))
	var items: Array = []   # [depth, kind, thing]
	_bubble_pos.clear()
	for p in GameWalls.pieces_in(Rect2i(view.position.x - 2, view.position.y - 5, view.size.x + 4, view.size.y + 10)):
		items.append([float(int(p["z"]) + 1) + (0.5 if str(p["k"]) == "gate" else 0.0), "wall", p])
	for b in GameTown.in_rect(view):
		items.append([float(b["z"] + b["h"]), "building", b])
	for w in GameVillagers.walkers_near(d, centre.x, centre.y, half.length(), GameDay.hour(d)):
		items.append([float(w["z"]), "villager", w])
	for e in GameDungeonArt.entrances_in(view):
		items.append([float(e["rect"].end.y) - 0.1, "entrance", e])
	for a in sb.creatures:
		items.append([float(a["z"]) + 0.5, "creature", a])
	for a in sb.companions:
		items.append([float(a["z"]) + 0.5, "companion", a])
	items.append([float(sb.heir.y) + 1.0, "heir", null])
	items.sort_custom(func(p, q): return p[0] < q[0])
	for it in items:
		match str(it[1]):
			"building":
				var b: Dictionary = it[2]
				var at := origin + (Vector2(float(b["x"]), float(b["z"])) - centre) * cell + area * 0.5
				var box := Rect2(at, Vector2(float(b["w"]), float(b["h"])) * cell)
				var lid := GameReveal.alpha(GameReveal.distance_to(Rect2i(int(b["x"]), int(b["z"]), int(b["w"]), int(b["h"])), float(sb.heir.x) + 0.5, float(sb.heir.y) + 0.5))
				var inside: Texture2D = BuildingArt.inside(str(b["kind"]), int(b["style"]), int(b["w"]), int(b["h"])) if lid < 1.0 else null
				if inside != null:   # the roof thins and the rooms show, with the people who live there
					c.draw_texture_rect(inside, box, false, dim)
					_paint_residents(c, b, at, cell, dim)
				c.draw_texture_rect(BuildingArt.texture(str(b["kind"]), int(b["style"]), int(b["w"]), int(b["h"]), GameVillagers.door_scale(b)), box, false, Color(dim.r, dim.g, dim.b, lid) if inside != null else dim)
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
					_stand(c, tex, p + Vector2(0, cell * 0.3), fs, _villager_flip(w, int(w["dx"]) < 0), dim, cell)
					_bubble_pos[str(w["id"])] = p + Vector2(0, cell * 0.3 - fs.y)
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
					_stand(c, tex, p + Vector2(0, cell * 0.3), Vector2(w, h), _faces_right("c%s" % a["uid"], float(a["x"])), dim, cell)   # the art faces left
			"companion":
				var a: Dictionary = it[2]
				if tile_view.covered(floori(float(a["x"])), floori(float(a["z"]))):
					continue
				var p := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
				var tex: Texture2D = _party_figure(str(a["id"]))
				if tex == null:
					c.draw_circle(p, maxf(2.0, cell * 0.3), _rgb(colors["companion"]))
				else:
					_stand(c, tex, p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * _party_scale(str(a["id"])), not _faces_right("p%s" % a["id"], float(a["x"])), dim, cell)   # the art faces right
			"heir":
				var p := origin + (Vector2(sb.heir) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
				var tex: Texture2D = SpriteArt.figure(d.heir)
				if tex == null:
					c.draw_circle(p, maxf(3.0, cell * 0.4), _rgb(colors["heir"]))
				else:
					_stand(c, tex, p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * GameVillagers.scale_of(d.heir.race_id), facing_dir.x < 0, dim, cell)
	_paint_bubbles(c)


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
		c.draw_style_box(Kit.style(Color(0.96, 0.94, 0.86, 0.95), 6, Color(0.1, 0.09, 0.14)), box)
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(-4, -8), head + Vector2(4, -8), head + Vector2(0, -2)]), Color(0.96, 0.94, 0.86, 0.95))
		c.draw_multiline_string(font, box.position + Vector2(6.0, 4.0 + 13.0), line, HORIZONTAL_ALIGNMENT_LEFT, width, 13, -1, Color(0.1, 0.09, 0.14))


## A dungeon's floor seen by the heir: its creatures and the heir as sprites (a circle where there is none), then the dark over
## it all: each tile as dark as GameDungeonArt.darkness says (the heir's own light, torches, braziers and lava lighten it).
func _paint_dungeon(c: Control, origin: Vector2, area: Vector2, centre: Vector2, cell: float, colors: Dictionary) -> void:
	var d: GameDynasty = app.dynasty
	var items: Array = []
	for a in sb.denizens:
		items.append([float(a["z"]) + 0.5, "foe", a])
	items.append([float(sb.heir.y) + 1.0, "heir", null])
	items.sort_custom(func(p, q): return p[0] < q[0])
	for it in items:
		if str(it[1]) == "foe":
			var a: Dictionary = it[2]
			var p := origin + (Vector2(float(a["x"]), float(a["z"])) - centre) * cell + area * 0.5
			var tex: Texture2D = SpriteArt.creature(str(a["id"]))
			if tex == null:
				c.draw_circle(p, maxf(2.0, cell * 0.3), _rgb(colors["creature"]))
			else:
				var s := cell / 16.0 * float(setting("creature_pixel"))
				var w := minf(tex.get_width() * s, cell * float(setting("creature_max_tiles")))
				var h := w * float(tex.get_height()) / float(tex.get_width())
				_stand(c, tex, p + Vector2(0, cell * 0.3), Vector2(w, h), _faces_right("c%s" % a["uid"], float(a["x"])), Color.WHITE, cell)
		else:
			var p := origin + (Vector2(sb.heir) + Vector2(0.5, 0.5) - centre) * cell + area * 0.5
			var tex: Texture2D = SpriteArt.figure(d.heir)
			if tex == null:
				c.draw_circle(p, maxf(3.0, cell * 0.4), _rgb(colors["heir"]))
			else:
				_stand(c, tex, p + Vector2(0, cell * 0.3), _figure_size(tex, cell) * GameVillagers.scale_of(d.heir.race_id), facing_dir.x < 0, Color.WHITE, cell)
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


## Makes the figures of everyone who may be drawn now, together: the villagers, the heir and the companions (a figure first made while
## drawing makes the atlas upload mid-frame, which blanks the sprites drawn before it in that frame).
func _warm_figures() -> void:
	SpriteArt.begin_batch()
	var d: GameDynasty = app.dynasty
	SpriteArt.figure(d.heir)
	for m in d.party.members:
		_party_figure(str(m["id"]))
	for b in GameTown.all():
		for r in GameVillagers.residents(b):
			_villager_tex(r)
	for g in GameWalls.all_gates():
		for r in GameVillagers.guards(g):
			_villager_tex(r)
	SpriteArt.end_batch()


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
			_stand(c, tex, feet, rs, _villager_flip(r, false), dim, cell)
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


## Draws a sprite standing with its feet at `feet`, on a shadow, turned the other way when `flip`.
func _stand(c: Control, tex: Texture2D, feet: Vector2, box: Vector2, flip: bool, tint: Color, cell: float) -> void:
	c.draw_set_transform(feet, 0.0, Vector2(1.0, 0.4))
	c.draw_circle(Vector2.ZERO, box.x * 0.4, Color(0, 0, 0, float(setting("shadow_alpha"))))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var at := feet - Vector2(box.x * 0.5, box.y - cell * 0.1)
	if flip:
		c.draw_texture_rect(tex, Rect2(at + Vector2(box.x, 0.0), Vector2(-box.x, box.y)), false, tint)
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
