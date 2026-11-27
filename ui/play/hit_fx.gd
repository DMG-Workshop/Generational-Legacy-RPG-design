## How a blow feels (data/ui/hit_fx.json): what a number says and how big it is for a hit, a crit, a blocked or dodged
## blow and a heal; whether a hit is heavy; the screen shake, the hit-stop on a kill, the nudge a struck figure takes
## and the collapse of a fallen one. The functions that decide (`number`, `is_heavy`, `shake_px`, `stop_seconds`,
## `nudge_px`) are pure and tested; the ones that move nodes only tween a node and put it back. Rendering only: they read
## the fight's typed events and never change them, and any chance in how a thing looks (which way a shake leans) comes
## from CosmeticRng keyed hashes, never the dynasty's dice. With reduced motion (UiSettings.motion_time is 0) every
## motion here does nothing and only the numbers stay. The battle screen's speed (BattleSpeed) shortens every motion and
## shrinks the shake and the hit-stop (half at 2x, none at 4x, none with Skip).
extends RefCounted

const PATH := "res://data/ui/hit_fx.json"
const UiSettings := preload("res://ui/play/ui_settings.gd")
const CosmeticRng := preload("res://ui/play/cosmetic_rng.gd")
const BattleSpeed := preload("res://ui/play/battle_speed.gd")

static var _data: Dictionary = {}
static var _loaded := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = v if typeof(v) == TYPE_DICTIONARY else {}
	return _data


static func reset() -> void:
	_loaded = false
	_data = {}


static func num(section: String, key: String) -> float:
	var s: Variant = data().get(section, {})
	return float((s as Dictionary).get(key, 0.0)) if typeof(s) == TYPE_DICTIONARY else 0.0


# ---------------------------------------------------------------- what a number says

## A blow that is heavy: a crit, or one that takes `heavy_fraction` of the target's health or more.
static func is_heavy(ev: Dictionary, target_max_hp: int) -> bool:
	if ev.get("crit", false):
		return true
	return target_max_hp > 0 and float(int(ev.get("amount", 0))) >= num("numbers", "heavy_fraction") * float(target_max_hp)


## The words and look of the number a battle event floats: {text, kind, size, heavy}. `kind` is one of hit, crit, block,
## miss, heal, tick (the screen picks the colour from the kind and the side hit); `text` says what happened in words or
## marks too ("12", "12!", "miss", "block", "+8"), so no kind rests on colour alone. {} for an event with no number.
static func number(ev: Dictionary, target_max_hp: int = 0) -> Dictionary:
	var big := int(num("numbers", "size"))
	match str(ev.get("type", "")):
		"damage":
			var amount := int(ev.get("amount", 0))
			var absorbed := int(ev.get("absorbed", 0))
			if amount <= 0 and absorbed > 0:
				return {"text": GameHitWords.block(), "kind": "block", "size": int(num("numbers", "word_size")), "heavy": false}
			var crit: bool = ev.get("crit", false)
			var heavy := is_heavy(ev, target_max_hp)
			var text := GameText.num(amount) + ("!" if crit else "")
			if absorbed > 0:
				text = GameHitWords.blocked(text, absorbed)
			if ev.get("shatter", false):
				text = GameHitWords.shatter(text)
			return {"text": text, "kind": "crit" if crit else "hit", "size": int(num("numbers", "crit_size")) if crit else (int(num("numbers", "heavy_size")) if heavy else big), "heavy": heavy}
		"miss":
			return {"text": GameHitWords.miss(), "kind": "miss", "size": int(num("numbers", "word_size")), "heavy": false}
		"heal":
			return {"text": GameText.signed(int(ev.get("amount", 0))), "kind": "heal", "size": int(num("numbers", "heal_size")), "heavy": false}
	return {}


# ---------------------------------------------------------------- how hard it lands

## Screen shake in pixels for a blow: 0 for an ordinary one, the crit's for a crit, the heavy hit's for a heavy hit, and
## at least the kill's for a blow that fells its target.
static func shake_px(ev: Dictionary, target_max_hp: int, killed: bool) -> float:
	var px := 0.0
	if ev.get("crit", false):
		px = num("shake", "crit_px")
	elif is_heavy(ev, target_max_hp):
		px = num("shake", "heavy_px")
	if killed:
		px = maxf(px, num("shake", "kill_px"))
	return px


## How long the figures freeze when a foe falls (a crit that kills holds a little longer); 0 with reduced motion, and in
## auto-battle when `not_in_auto` (the fight must not be slower for it).
static func stop_seconds(crit: bool, auto: bool) -> float:
	if auto and bool((data().get("hit_stop", {}) as Dictionary).get("not_in_auto", true)):
		return 0.0
	return BattleSpeed.time(num("hit_stop", "crit_kill_seconds") if crit else num("hit_stop", "kill_seconds")) * BattleSpeed.fx_scale()


## The push a struck figure takes, in pixels (larger for a heavy blow); 0 for a blow that does no damage.
static func nudge_px(ev: Dictionary, target_max_hp: int) -> float:
	if int(ev.get("amount", 0)) <= 0:
		return 0.0
	return num("nudge", "heavy_px") if is_heavy(ev, target_max_hp) else num("nudge", "px")


# ---------------------------------------------------------------- moving nodes (look only)

## Shakes `node` (the arena) about its place for a moment and puts it back. A second shake in the middle of one carries
## on from the same place, never a drifted one.
static func shake(node: Control, px: float, key: String) -> void:
	px *= BattleSpeed.fx_scale()
	var seconds := BattleSpeed.time(num("shake", "seconds"))
	if px <= 0.0 or seconds <= 0.0 or node == null or not node.is_inside_tree():
		return
	var home: Vector2 = node.get_meta("fx_shake_home") if node.has_meta("fx_shake_home") else node.position
	node.set_meta("fx_shake_home", home)
	if node.has_meta("fx_shake_tween"):
		var old: Tween = node.get_meta("fx_shake_tween")
		if old != null and old.is_valid():
			old.kill()
	var rng := CosmeticRng.keyed("shake:" + key)
	var steps := maxi(2, int(num("shake", "steps")))
	var t := node.create_tween()
	for i in steps:
		var fade := 1.0 - float(i) / float(steps)
		var off := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * px * fade
		t.tween_property(node, "position", home + off, seconds / float(steps))
	t.tween_callback(func():
		node.position = home
		node.remove_meta("fx_shake_home")
		node.remove_meta("fx_shake_tween"))
	node.set_meta("fx_shake_tween", t)


## Pushes `node` `dx` pixels along x and lets it ease back (the knock-back of a struck figure).
static func nudge(node: Control, dx: float) -> void:
	var out_s := BattleSpeed.time(num("nudge", "out_seconds"))
	if dx == 0.0 or out_s <= 0.0 or node == null or not node.is_inside_tree():
		return
	var home: Vector2 = node.get_meta("fx_nudge_home") if node.has_meta("fx_nudge_home") else node.position
	node.set_meta("fx_nudge_home", home)
	if node.has_meta("fx_nudge_tween"):
		var old: Tween = node.get_meta("fx_nudge_tween")
		if old != null and old.is_valid():
			old.kill()
	var t := node.create_tween()
	t.tween_property(node, "position:x", home.x + dx, out_s).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position:x", home.x, BattleSpeed.time(num("nudge", "back_seconds"))).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		node.position.x = home.x
		node.remove_meta("fx_nudge_home")
		node.remove_meta("fx_nudge_tween"))
	node.set_meta("fx_nudge_tween", t)


## The hit-stop: the arena's figures stop moving for `seconds` (its idle breathing and poses), the words and bars carry on.
## Awaitable; returns at once when `seconds` is 0.
static func freeze(tree: SceneTree, arena: Node, seconds: float) -> void:
	if seconds <= 0.0 or arena == null or not arena.is_inside_tree():
		return
	var was: int = arena.process_mode
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	await tree.create_timer(seconds).timeout
	if is_instance_valid(arena):
		arena.process_mode = was as Node.ProcessMode


## A fallen figure sinks and tips over a little as it fades (used with the pose's own fall).
static func collapse(root: Control, key: String) -> void:
	var seconds := BattleSpeed.time(num("collapse", "seconds"))
	if seconds <= 0.0 or root == null or not root.is_inside_tree():
		return
	var lean := 1.0 if CosmeticRng.keyed("collapse:" + key).randf() < 0.5 else -1.0
	root.pivot_offset = Vector2(root.size.x * 0.5, root.size.y)
	var t := root.create_tween()
	t.set_parallel(true)
	t.tween_property(root, "rotation_degrees", lean * num("collapse", "tilt_degrees"), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(root, "position:y", root.position.y + num("collapse", "sink_px"), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ---------------------------------------------------------------- the data's own check

static func validate() -> Array:
	var out: Array = []
	var d := data()
	if d.is_empty():
		return ["hit effects: data/ui/hit_fx.json is missing or unreadable"]
	var need := {
		"numbers": ["size", "crit_size", "heavy_size", "heal_size", "word_size", "status_size", "life", "rise", "pop_scale", "crit_pop_scale", "stagger_px", "stagger_rows", "heavy_fraction"],
		"shake": ["heavy_px", "crit_px", "kill_px", "seconds", "steps"],
		"hit_stop": ["kill_seconds", "crit_kill_seconds"],
		"nudge": ["px", "heavy_px", "out_seconds", "back_seconds"],
		"flash": ["bright", "seconds"],
		"collapse": ["sink_px", "tilt_degrees", "seconds"],
		"status_pop": ["seconds", "rise", "pop_scale", "letters", "size"],
		"loot": ["pop_seconds", "arc_px", "stagger_seconds", "beam_seconds", "beam_width", "beam_height", "icon_px"],
	}
	for sec in need:
		if typeof(d.get(sec)) != TYPE_DICTIONARY:
			out.append("hit effects: %s must be a table" % sec)
			continue
		for k in need[sec]:
			var v: Variant = d[sec].get(k)
			if not (v is float or v is int) or float(v) <= 0.0:
				out.append("hit effects: %s.%s must be a number above 0" % [sec, k])
	if not Color.html_is_valid(str((d.get("numbers", {}) as Dictionary).get("crit_color", ""))):
		out.append("hit effects: numbers.crit_color must be a colour")
	if num("numbers", "heavy_fraction") >= 1.0:
		out.append("hit effects: numbers.heavy_fraction must be below 1")
	if num("shake", "kill_px") > 12.0 or num("shake", "crit_px") > 12.0 or num("shake", "heavy_px") > 12.0:
		out.append("hit effects: a shake over 12 pixels throws the arena about; keep it small")
	if num("hit_stop", "crit_kill_seconds") > 0.2 or num("hit_stop", "kill_seconds") > 0.2:
		out.append("hit effects: a hit-stop over 0.2 seconds feels like a stall")
	var loot: Dictionary = d.get("loot", {}) if typeof(d.get("loot")) == TYPE_DICTIONARY else {}
	var table: Variant = loot.get("rarity", {})
	if typeof(table) != TYPE_DICTIONARY:
		return out + ["hit effects: loot.rarity must be a table"]
	var seen: Array = []
	for r in GameLoot.data()["rarities"]:
		var id := str(r["id"])
		seen.append(id)
		var row: Variant = (table as Dictionary).get(id)
		if typeof(row) != TYPE_DICTIONARY or not Color.html_is_valid(str((row as Dictionary).get("color", ""))) or typeof((row as Dictionary).get("mark")) != TYPE_STRING:
			out.append("hit effects: loot.rarity.%s needs a colour and a mark (text)" % id)
		elif id != "common" and str(row["mark"]) == "" and id != "":
			out.append("hit effects: loot.rarity.%s needs a mark, so colour is not the only cue" % id)
	for id in table:
		if id not in seen:
			out.append("hit effects: loot.rarity.%s is not a rarity of the loot data" % id)
	if str(loot.get("beam_from", "")) not in seen:
		out.append("hit effects: loot.beam_from must be a rarity")
	return out
