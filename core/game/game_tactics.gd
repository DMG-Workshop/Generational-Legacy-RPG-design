## Battle decisions for the autopilot heir and for companions, using only what GameBattle shows.
## Mend when badly hurt and cleanse a heavy affliction first. Otherwise every option is weighed in
## one coin, the HP of harm it spares the party. Foes are killed in order of threat per HP; damage
## to a foe brings its death, and that of every foe after it in that order, closer, and a foe that
## falls now does not strike this round. Holding a foe spares its blows while held; a curse, ward
## or haste spares what it softens. MP spent is priced by what the unit's main skill would have
## done with it, dearer as MP runs low. Areas count each foe they catch. Each unit fights in its
## class's style (GameSkills.weights): casters lead with spells and magic, fighters with steel and
## feats. Only class skills its level has opened are weighed. A class's style may also ask it to
## mend a hurt party member early (heal_below), to open a battle with set moves (opener), and every
## class rotates a little between its moves, so each of its skills gets used. No rolls of its own.
class_name GameTactics
extends RefCounted


## What a unit can afford this turn: [{ab, cost, skill (class skill index or -1), spell (id or ""),
## feat (id or ""), hp (HP the feat costs), item (a plague vial's id or "")}]. A feat costs no MP;
## it is an option while it is ready. A vial in the heir's pack is weighed as if it cost a share of
## the heir's HP (settings.bot_item_worth in plague.json), so one is thrown only into a hard fight.
static func options(b: GameBattle, by: int) -> Array:
	var u := b.unit(by)
	var out: Array = []
	var skills: Array = GameSkillTree.skills(u)
	var blood := b.pays_in_hp(by)   # Blood Magic: no MP is spent, the HP taken is weighed like a feat's
	for i in skills.size():
		if not GameSkills.unlocked(u, i) or b.unit_skill_used_up(by, i):
			continue   # not open at this level yet, or once a battle and already used
		var c := GameBattle.unit_skill_cost(u, i)
		if b.can_pay(by, c):
			out.append({"ab": skills[i], "cost": 0 if blood else c, "skill": i, "spell": "", "mp": c, "hp": b.blood_cost(by, c) if blood else 0})
	for id in b.unit_spells(by):
		var sp := b.unit_spell(by, id)
		if sp.is_empty():
			continue
		var c := GameCombat.ability_cost(sp, u.level)
		if b.can_pay(by, c):
			out.append({"ab": sp, "cost": 0 if blood else c, "skill": -1, "spell": id, "mp": c, "hp": b.blood_cost(by, c) if blood else 0})
	for id in b.unit_feats(by):
		if b.feat_block(by, id) == "":
			out.append({"ab": b.unit_feat(by, id), "cost": 0, "skill": -1, "spell": "", "feat": id,
				"hp": GameFeats.hp_cost(u, id, int(b.unit_numbers(by)["max_hp"]))})
	if by < 0 and not b.heir.inventory.is_empty():
		for id in GamePlague.vials_carried(b.heir):
			out.append({"ab": GamePlague.vial_ability(id), "cost": 0, "skill": -1, "spell": "", "item": id,
				"hp": float(GamePlague.setting("bot_item_worth")) * float(b.unit_numbers(-1)["max_hp"])})
	return out


static func _frac(hp: int, max_hp: int) -> float:
	return float(hp) / float(maxi(1, max_hp))


static func _plan(o: Dictionary, target: int) -> Dictionary:
	return {"act": "ability", "ab": o["ab"], "cost": o["cost"], "skill": o["skill"], "spell": o["spell"], "feat": o.get("feat", ""),
		"item": o.get("item", ""), "target": target, "mp": o.get("mp", o["cost"])}


## One decision: {"act": "pass"|"potion"|"attack"|"ability", "target", and for an ability
## "ab", "cost", "skill", "spell", "feat"}. `by` is -1 for the heir, else the ally's index.
static func choose(b: GameBattle, by: int) -> Dictionary:
	if by < 0 and b.heir_skip:
		return {"act": "pass"}
	var opts := options(b, by)
	var heir_frac := _frac(b.heir.hp, int(b.unit_numbers(-1)["max_hp"]))
	var below := float(GameCombat.setting("bot_heal_below")) if by < 0 else float(GameData.bal("companion_heal_below"))
	var hurt := 0
	for who in [-1] + b.conscious_allies():
		if _frac(b.unit(who).hp, int(b.unit_numbers(who)["max_hp"])) < float(GameCombat.setting("bot_party_heal_below")):
			hurt += 1
	if heir_frac < below:
		if by < 0 and b.heir.potions > 0:
			return {"act": "potion"}
		var heal := _pick_heal(opts, hurt >= 2)
		if not heal.is_empty():
			return _plan(heal, -1)
	elif by < 0 and hurt >= 2:
		var group := _pick_heal(opts, true)
		if not group.is_empty() and group["ab"].get("party", false):
			return _plan(group, -1)
	var care := _tend(b, by, opts)
	if not care.is_empty():
		return care
	if _affliction(b, "heir") >= float(GameCombat.setting("bot_cleanse_threat")):
		for o in opts:
			if o["ab"].get("cleanse", false):
				return _plan(o, -1)
	if by >= 0 and _plain(b.unit(by)):
		return _plain_blow(b, by, opts)
	var ctx := _context(b, by)
	var me := b.unit(by)
	var w := GameSkills.weights(me, ctx["nums"])
	var last: Array = ctx["living"]
	if last.size() == 1 and float(w["attack"]) >= float(GameCombat.setting("bot_finish_attack_from")) \
			and b.estimate(by, {}, int(last[0]), ctx["nums"]) >= float(b.enemies[last[0]]["hp"]):
		return {"act": "attack", "target": int(last[0])}   # a plain blow finishes the fight (a caster casts)
	opts = _keep_heal_mp(b, by, opts, heir_frac)
	# Every option at every sensible aim, valued; then MP is priced by the main damage skill's
	# gain over a plain blow (per point, dearer as MP runs low) and the best is taken. The class's
	# style then leans on what it fights with (GameSkills.weights): a caster's spells, a fighter's
	# steel and feats, a hybrid's by its build.
	var cands: Array = []
	var blow := -INF
	var aim := int(ctx["blows"][0])   # single-target options go where a plain blow does the most
	for t in ctx["blows"]:
		var v := _value(b, by, {}, t, ctx)
		if v > blow:
			blow = v
			aim = t
		cands.append({"plan": {"act": "attack", "target": t}, "value": v, "cost": 0, "other": false, "mp_back": 0.0})
	var main := GameBattle.unit_skill_of(me, "damage")
	var main_v := 0.0
	for o in opts:
		var ab: Dictionary = o["ab"]
		if ab.has("pct_max_hp"):
			continue
		var aims: Array = [-1]
		var prints := {}   # aim -> footprint, when already worked out
		if GameCombat.aims_at_foe(ab):
			match GameCombat.shape(ab):
				"all":
					aims = [ctx["living"][0]]
				"single":
					aims = [aim, ctx["worst"]] if ab.has("statuses") and ctx["worst"] != aim else [aim]
				_:
					aims = [aim] if GameCombat.around_self(ab) else _area_aims(ab, ctx, aim, prints)
		var seen := {}
		var mp_back := 0.0
		if ab.get("mana", false):
			mp_back = minf(float(ctx["nums"]["max_mp"] - me.mp), ceilf(float(ctx["nums"]["max_mp"]) * float(GameCombat.setting("mana_tap_pct"))))
		for t in aims:
			var hits: Array = []
			if t >= 0:
				hits = prints[t] if prints.has(t) else GameCombat.footprint(ab, ctx["origin"], t, ctx["points"])
				if hits.is_empty():
					continue   # aimed that way, it reaches no one
			if aims.size() > 1:
				# Aims that catch the same foes alike are one option, unless a sleeper is near.
				var key := str(hits) + ("" if ctx["calm"] else "@%d" % t)
				if seen.has(key):
					continue
				seen[key] = true
			var v := _value(b, by, ab, t, ctx, hits)
			if int(o["skill"]) == main and main >= 0:
				main_v = maxf(main_v, v)
			cands.append({"plan": _plan(o, t), "value": v, "cost": int(o["cost"]), "other": float(ab.get("mult", 0.0)) <= 0.0,
				"mp_back": mp_back, "hp": float(o.get("hp", 0))})
	if main >= 0:
		ctx["mp_price"] = maxf(0.0, main_v - blow) / float(maxi(1, GameBattle.unit_skill_cost(me, main)))
	var variety := GameSkills.variety(me)
	for c in cands:
		if float(c["value"]) > 0.0:
			c["value"] = float(c["value"]) * float(w.get(GameSkills.category(c["plan"]), 1.0)) / (1.0 + variety * _times_used(b, by, c["plan"]))
	var price := float(ctx["mp_price"]) * float(ctx["scarcity"]) * float(w["mp_price"])
	var floor_price := -1.0   # worked out only if a blessing or a curse is in the running
	var margin := float(GameCombat.setting("bot_other_margin"))
	var best := {}
	for c in cands:
		var cost_price := price
		if c["other"] and float(c["value"]) > 0.0:
			if floor_price < 0.0:
				floor_price = maxf(price, _heal_worth(b, by) * float(GameCombat.setting("bot_mp_floor")))
			cost_price = floor_price
		var score := float(c["value"]) + (float(c["mp_back"]) - float(c["cost"])) * cost_price - float(c.get("hp", 0.0))
		if c["other"] and score > 0.0:
			score /= margin
		c["score"] = score
		best = _keep_better(best, c)
	var opening := _opener(b, by, opts, ctx)
	if not opening.is_empty() and _share_felled(b, by, best["plan"], ctx) < float(GameCombat.setting("bot_opener_skip_share")):
		return opening
	return best["plan"]


## How often the unit has used this plan's ability in the battle so far (a plain blow: never counted).
static func _times_used(b: GameBattle, by: int, plan: Dictionary) -> int:
	if str(plan.get("act", "")) != "ability":
		return 0
	return int(b.uses.get("%s/%s" % [GameBattle.ref_of(by), plan["ab"].get("name", "")], 0))


## An heir whose class looks after its party (style heal_below) mends the most hurt member once they fall
## under that share of HP, before it does anything else: a single heal aimed at them, or the party
## heal when two or more are hurt that badly. Returns {} when nobody is that hurt or no heal can be paid.
static func _tend(b: GameBattle, by: int, opts: Array) -> Dictionary:
	var care := float(GameSkills.style(b.unit(by).class_id)["heal_below"])
	if care <= 0.0 or by >= 0:
		return {}   # a companion tends the heir by the plain rule only
	var worst := -2
	var worst_frac := 1.0
	var hurt := 0
	for who in [-1] + b.conscious_allies():
		# The heir's own wounds wait a little longer: the plain rule above mends them below bot_heal_below.
		var line := care * float(GameCombat.setting("bot_tend_self")) if who == -1 else care
		var f := _frac(b.unit(who).hp, int(b.unit_numbers(who)["max_hp"]))
		if f < line:
			hurt += 1
			if f < worst_frac:
				worst_frac = f
				worst = who
	if worst == -2:
		return {}
	var heal := _pick_heal(opts, hurt >= 2)
	if heal.is_empty():
		return {}
	return _plan(heal, worst)


## The share of the foes' remaining HP a plan is expected to take off this turn (0 for anything that
## does not strike).
static func _share_felled(b: GameBattle, by: int, plan: Dictionary, ctx: Dictionary) -> float:
	var ab: Dictionary = plan.get("ab", {}) if str(plan.get("act", "")) == "ability" else {}
	if str(plan.get("act", "")) in ["pass", "potion"] or (not ab.is_empty() and not GameCombat.aims_at_foe(ab)):
		return 0.0
	var t := int(plan.get("target", -1))
	var hits: Array = [] if ab.is_empty() else GameCombat.footprint(ab, ctx["origin"], t, ctx["points"])
	var dealt := 0.0
	for h in b.expected_hits(by, ab, t, hits, ctx["nums"]):
		dealt += minf(float(h[1]), float(b.enemies[h[0]]["hp"]))
	var left := 0.0
	for i in ctx["living"]:
		left += float(b.enemies[i]["hp"])
	return dealt / maxf(1.0, left)


## The heir's opening moves (style opener: skill or feat ids, in order): while the battle is young,
## the first of them not yet used and ready is played, if the fight looks costly enough to prepare for
## (the HP it would cost at the foes' pace, as a share of max HP: settings.bot_opener_min_danger) and
## a round of their blows costs no more than settings.bot_opener_max_pace of it.
static func _opener(b: GameBattle, by: int, opts: Array, ctx: Dictionary) -> Dictionary:
	var list: Array = GameSkills.style(b.unit(by).class_id)["opener"]
	if by >= 0 or list.is_empty() or b.turn >= list.size():
		return {}   # a hireling just fights
	var pace := float(ctx["total"]) / float(maxi(1, int(b.unit_numbers(-1)["max_hp"])))   # a round of the foes' blows
	if pace * float(ctx["turns"]) < float(GameCombat.setting("bot_opener_min_danger")) or pace > float(GameCombat.setting("bot_opener_max_pace")):
		return {}   # a fight that costs little is not worth a round of preparing, one that bites hard allows none
	for id in list:
		for o in opts:
			var is_feat := str(o.get("feat", "")) != ""
			if str(o["feat"] if is_feat else o["ab"].get("id", "")) != str(id) or (not is_feat and int(o["skill"]) < 0):
				continue
			if _times_used(b, by, _plan(o, -1)) > 0:
				break   # played already: on to the next
			var ab: Dictionary = o["ab"]
			if GameCombat.aims_at_foe(ab):
				return _plan(o, int(ctx["blows"][0]))
			if _blessing_value(b, by, ab, ctx) == -INF:
				break   # its status is on already
			return _plan(o, -1)
	return {}


## While the heir is below settings.bot_reserve_heal_below and the unit's class heal can still be
## paid, nothing that would leave too little MP for that heal is weighed: a caster never spends
## the mend away mid-fight. Under Blood Magic MP is not spent, so nothing is held back.
static func _keep_heal_mp(b: GameBattle, by: int, opts: Array, heir_frac: float) -> Array:
	if heir_frac >= float(GameCombat.setting("bot_reserve_heal_below")) or b.pays_in_hp(by):
		return opts
	var u := b.unit(by)
	var k := GameBattle.unit_skill_of(u, "heal")
	if k < 0:
		return opts
	var need := GameBattle.unit_skill_cost(u, k)
	if u.mp < need:
		return opts
	return opts.filter(func(o): return o["ab"].has("pct_max_hp") or u.mp - int(o.get("mp", o["cost"])) >= need)


## Where an area is worth aiming: the spot that catches the most threat, plus the foes a single
## strike or a hold would go for. Weighing every spot in full is too slow for the autopilot.
static func _area_aims(ab: Dictionary, ctx: Dictionary, aim: int, prints: Dictionary) -> Array:
	var out: Array = [aim]
	if ab.has("statuses") and ctx["worst"] != aim:
		out.append(ctx["worst"])
	var best := -1
	var best_w := 0.0
	var weight: Dictionary = ctx["weight"]
	var threat: Dictionary = ctx["threat"]
	for t in ctx["living"]:
		var hits := GameCombat.footprint(ab, ctx["origin"], t, ctx["points"])
		prints[t] = hits
		if hits.size() < 2:
			continue
		var w := 0.0
		for h in hits:
			w += (float(weight[h[0]]) + float(threat[h[0]])) * float(h[1])
		if w > best_w:
			best_w = w
			best = t
	if best >= 0 and best not in out:
		out.append(best)
	return out


## HP one MP buys through the unit's class heal on the heir. A ward or a curse that does not
## pay back a share of this is not worth casting while there are foes to strike.
static func _heal_worth(b: GameBattle, by: int) -> float:
	var nums := b.unit_numbers(by)   # the battle's own cache for this unit
	if not nums.has("heal_worth"):
		var u := b.unit(by)
		var k := GameBattle.unit_skill_of(u, "heal")
		nums["heal_worth"] = 0.0 if k < 0 else float(GameBattle.heal_amount(u, b.heir, GameSkillTree.skill(u, k))) / float(maxi(1, GameBattle.unit_skill_cost(u, k)))
	return float(nums["heal_worth"])


## A companion with no spells and no area or status skill has little to weigh: its feat when one
## is ready and lands harder than its other blows, else the class strike on the heir's focus while
## MP lasts, else a plain blow.
static func _plain(u: GameHeir) -> bool:
	if not u.spells.is_empty():
		return false
	var skills: Array = GameSkillTree.skills(u)
	for i in skills.size():
		if GameSkills.unlocked(u, i) and (GameCombat.is_aoe(skills[i]) or skills[i].has("statuses")):
			return false
	return true


static func _plain_blow(b: GameBattle, by: int, opts: Array) -> Dictionary:
	var awake := b.living_enemies().filter(func(i): return not _asleep(b, i))
	var t := b._valid_target(b.focus)
	if t not in awake and not awake.is_empty():
		t = awake[0]
	var plan := {"act": "attack", "target": t}
	var feats: Array = []
	for o in opts:
		if str(o.get("feat", "")) != "":
			feats.append(o)
		elif plan["act"] == "attack" and o["ab"].get("type", "") == "damage":
			plan = _plan(o, t)
	if feats.is_empty():
		return plan
	# A feat is aimed at the focus, and never where it would wake a sleeper.
	var nums := b.unit_numbers(by)
	var best := b.estimate(by, plan.get("ab", {}), t, nums)
	for o in feats:
		var hits := b.aoe_hits(o["ab"], by, t)
		if hits.is_empty() or hits.any(func(h): return h[0] not in awake):
			continue
		var v := -float(o["hp"])
		for h in b.expected_hits(by, o["ab"], t, hits, nums):
			v += minf(float(h[1]), float(b.enemies[h[0]]["hp"]))
		if v > best:
			best = v
			plan = _plan(o, t)
	return plan


static func _keep_better(cur: Dictionary, cand: Dictionary) -> Dictionary:
	if cur.is_empty():
		return cand
	var a := float(cand["score"])
	var c := float(cur["score"])
	if absf(a - c) <= absf(c) * 0.03:
		return cand if int(cand["cost"]) < int(cur["cost"]) else cur
	return cand if a > c else cur


## A heal option: a party heal when wanted (else any), or the class heal.
static func _pick_heal(opts: Array, want_party: bool) -> Dictionary:
	var single := {}
	var group := {}
	for o in opts:
		var ab: Dictionary = o["ab"]
		if not ab.has("pct_max_hp") or ab.get("cleanse", false):
			continue
		if ab.get("party", false):
			if group.is_empty():
				group = o
		elif single.is_empty():
			single = o
	if want_party and not group.is_empty():
		return group
	return single if not single.is_empty() else group


## How badly statuses weigh on a unit, as a share of its max HP (control and debuffs count too).
static func _affliction(b: GameBattle, ref: String) -> float:
	var list := b.status_list(ref)
	if list.is_empty():
		return 0.0
	var t := 0.0
	var max_hp := float(maxi(1, b.ref_max_hp(ref)))
	for inst in list:
		var def := GameCombat.status_def(inst["id"])
		if not def.get("harmful", false):
			continue
		if def.get("tick", "") == "damage":
			t += float(inst["amount"]) * float(inst["stacks"]) * float(inst["turns"]) / max_hp
		elif def.has("skip"):
			t += 0.1
		else:
			t += 0.05
	return t


## How likely a status sticks on `ref`, per point of the ability's own chance; once a decision.
static func _odds(b: GameBattle, ref: String, id: String, src: String, ctx: Dictionary) -> float:
	var key := ref + "|" + id
	var odds: Dictionary = ctx["odds"]
	if not odds.has(key):
		odds[key] = b.status_chance(ref, {"id": id, "chance": 1.0}, src)
	return float(odds[key])


static func _asleep(b: GameBattle, i: int) -> bool:
	return b.has_status(GameBattle.enemy_ref(i), "sleep")


## Everything one decision needs, worked out once: where the foes stand, which are awake, what each
## threatens and weighs in the kill order, the party's damage per round, rounds left, MP's worth.
## Foes are killed in order of threat per HP; a foe's weight is its threat plus that of every foe
## killed after it, since harming it brings all their deaths closer.
static func _context(b: GameBattle, by: int) -> Dictionary:
	var living := b.living_enemies()
	var points := {}
	var threat := {}
	var awake: Array = []
	var total := 0.0
	var hp_left := 0.0
	for i in living:
		points[i] = b.enemy_point(i)
		threat[i] = b.foe_threat(i)
		total += float(threat[i])
		hp_left += float(b.enemies[i]["hp"])
		if not _asleep(b, i):
			awake.append(i)
	var order := living.duplicate()
	order.sort_custom(func(x, y): return float(threat[x]) / float(b.enemies[x]["hp"]) > float(threat[y]) / float(b.enemies[y]["hp"]))
	var weight := {}
	var tail := 0.0
	for k in range(order.size() - 1, -1, -1):
		tail += float(threat[order[k]])
		weight[order[k]] = tail
	# Companions press the heir's focus; the heir weighs every foe. Sleepers are left alone while
	# another foe is awake.
	var pool: Array = awake if not awake.is_empty() else living
	var blows: Array = pool
	if by >= 0:
		var f := b._valid_target(b.focus)
		blows = [f] if f in pool else [pool[0]]
	# The party's damage per round, roughly: each member's main blow against the first foe's armour.
	var armour := float(b.enemies[living[0]]["def"]) * 0.5
	var dps := 0.0
	for who in [-1] + b.conscious_allies():
		var u := b.unit(who)
		var nums := b.unit_numbers(who)
		var d := maxf(1.0, float(nums["str"]) - armour)
		var k := GameBattle.unit_skill_of(u, "damage")
		if k >= 0:
			var s: Dictionary = GameSkillTree.skill(u, k)
			var p: float = nums.get(str(s.get("stat", "str")), nums["str"])
			d = maxf(d, p * float(s["mult"]) * float(s.get("hits", 1)) - armour * (1.0 - float(s.get("pierce", 0.0))))
		dps += d * (1.0 + float(nums["crit"]) * 0.75)
	var me := b.unit(by)
	var mine := b.unit_numbers(by)
	var worst: int = pool[0]
	for i in pool:
		if float(threat[i]) > float(threat[worst]):
			worst = i
	return {"living": living, "awake": awake, "calm": awake.size() == living.size(), "worst": worst, "blows": blows,
		"points": points, "origin": b.cast_point(by), "threat": threat, "weight": weight, "total": maxf(1.0, total),
		"dps": maxf(1.0, dps), "turns": maxf(1.0, hp_left / maxf(1.0, dps)), "nums": mine, "mp_price": 0.0,
		"scarcity": 0.15 + 0.85 * clampf(1.0 - _frac(me.mp, int(mine["max_mp"])) * 1.5, 0.0, 1.0),
		"boss_turns": float(GameCombat.setting("boss_control_max_turns")), "odds": {}}


## HP of harm an action spares the party: `ab` empty for a plain blow, `t` the aimed foe.
static func _value(b: GameBattle, by: int, ab: Dictionary, t: int, ctx: Dictionary, hits: Array = []) -> float:
	if not ab.is_empty() and not GameCombat.aims_at_foe(ab):
		return _blessing_value(b, by, ab, ctx)
	var threat: Dictionary = ctx["threat"]
	var weight: Dictionary = ctx["weight"]
	var dps := float(ctx["dps"])
	if hits.is_empty():
		hits = [[t, 1.0]] if ab.is_empty() else GameCombat.footprint(ab, ctx["origin"], t, ctx["points"])
	var v := 0.0
	var falls := {}
	var dealt := 0.0
	for h in b.expected_hits(by, ab, t, hits, ctx["nums"]):
		var i: int = h[0]
		var hp := float(b.enemies[i]["hp"])
		var d := minf(float(h[1]), hp)
		dealt += d
		v += d * float(weight.get(i, 0.0)) / dps
		if float(h[1]) >= hp:
			falls[i] = true
			v += float(threat.get(i, 0.0))
	var strikes := ab.is_empty() or float(ab.get("mult", 0.0)) > 0.0
	var awake_outside: int = (ctx["awake"] as Array).size()
	for h in hits:
		var i: int = h[0]
		if i in ctx["awake"]:
			awake_outside -= 1
		elif strikes and i != t:
			v -= float(threat.get(i, 0.0)) * 2.0
	var drain := float(ab.get("drain", 0.0))
	if drain > 0.0:
		v += minf(dealt * drain, float(ctx["nums"]["max_hp"]) - float(b.unit(by).hp))
	var src := GameBattle.ref_of(by)
	var turns_left := float(ctx["turns"])
	for st in ab.get("statuses", []):
		if str(st.get("on", "target")) != "target":
			continue
		# What the status does is the same on every foe; work it out once.
		var id := str(st["id"])
		var def := GameCombat.status_def(id)
		var pot := float(st.get("potency", def.get("default_potency", 1.0)))
		var base := float(st.get("chance", 1.0))
		var turns := minf(float(st.get("turns", def.get("default_turns", 1))), turns_left)
		var skip := str(def.get("skip", ""))
		var control := bool(def.get("control", false))
		if def.get("wake_on_hit", false) and awake_outside == 0:
			turns = 0.0   # the party would have to strike it awake
		var mods: Dictionary = def.get("mods", {})
		var per_turn := pot if mods.has("damage_dealt") or mods.has("damage_taken") else 0.0
		match skip:
			"always":
				per_turn += 1.0
			"chance":
				per_turn += pot
		var dot: bool = def.get("tick", "") == "damage"
		var by_power: float = pot * float(ctx["nums"].get(str(ab.get("stat", "str")), ctx["nums"]["str"])) if def.get("basis", "") == "power" else -1.0
		for h in hits:
			var i: int = h[0]
			if falls.has(i):
				continue
			var ref := GameBattle.enemy_ref(i)
			if skip != "" and b.has_status(ref, id):
				continue
			var chance := _odds(b, ref, id, src, ctx) * base
			if chance <= 0.0:
				continue
			var held := turns
			if control and b.enemies[i].get("boss", false):
				held = minf(held, float(ctx["boss_turns"]))
			var th := float(threat.get(i, 0.0))
			v += chance * held * th * per_turn
			if skip == "alternate":
				v += chance * floorf(held * 0.5) * th
			if dot:
				var per := by_power if by_power >= 0.0 else pot * float(b.enemies[i]["max_hp"])
				v += chance * minf(per * held, float(b.enemies[i]["hp"])) * float(weight.get(i, 0.0)) / dps
	return v


## What a party blessing spares, never twice at once (a spell's or a once skill's once a battle;
## a feat's or a class stance's again once it has run out): a ward soaks blows, regrowth mends
## them, haste adds actions, a rally adds damage, a guard takes the edge off blows, evasion slips
## them, focus turns blows into crits. A taunt is weighed on its own (see _taunt_value).
static func _blessing_value(b: GameBattle, by: int, ab: Dictionary, ctx: Dictionary) -> float:
	if (ab.has("group") or GameSkills.is_once(ab)) and int(b.uses.get("%s/%s" % [GameBattle.ref_of(by), ab.get("name", "")], 0)) > 0:
		return -INF
	var v := 0.0
	var members: Array = [-1] + b.conscious_allies()
	var strike := float(ctx["total"]) / float(members.size())   # what one member's turn of blows spares
	for st in ab.get("statuses", []):
		if b.has_status("heir" if str(st.get("on", "party")) == "party" else GameBattle.ref_of(by), str(st["id"])):
			return -INF
		var def := GameCombat.status_def(str(st["id"]))
		var turns := minf(float(st.get("turns", def.get("default_turns", 1))), float(ctx["turns"]))
		var pot := float(st.get("potency", def.get("default_potency", 1.0)))
		if def.get("draws", false):
			v += _taunt_value(b, by, ctx, turns, pot)
			continue
		var incoming := float(ctx["total"]) * turns / float(members.size())
		var mods: Dictionary = def.get("mods", {})
		for who in (members if str(st.get("on", "party")) == "party" else [by]):
			var max_hp := float(b.unit_numbers(who)["max_hp"])
			if def.get("absorb", false):
				v += minf(pot * max_hp, incoming)
			elif def.get("tick", "") == "heal":
				v += minf(pot * max_hp * turns, incoming + max_hp - float(b.unit(who).hp))
			elif mods.has("extra_action"):
				v += pot * float(mods["extra_action"]) * turns * strike
			elif float(mods.get("damage_dealt", 0.0)) > 0.0:
				v += pot * float(mods["damage_dealt"]) * turns * strike
			elif float(mods.get("damage_taken", 0.0)) < 0.0:
				v += minf(pot * absf(float(mods["damage_taken"])) * incoming, incoming)
			elif float(mods.get("dodge", 0.0)) > 0.0:
				var n := b.unit_numbers(who)
				var dodge := 0.0 if bool(n["no_dodge"]) else clampf(float(n["dodge"]) + b.status_mod(GameBattle.ref_of(who), "dodge"), 0.0, 1.0)
				v += pot * float(mods["dodge"]) * incoming * (1.0 - dodge)
			elif float(mods.get("crit", 0.0)) > 0.0:
				var span := 1.0 if def.get("spent_on", "") == "blow" else turns   # hiding lasts for one blow
				v += minf(1.0, pot * float(mods["crit"])) * (float(b.unit_numbers(who)["crit_mult"]) - 1.0) * strike * span
	return v


## Drawing every foe onto oneself for `turns`: every blow then lands on the one braced for it, so
## the party is spared the guard's share of them all. With anyone else standing, that pulls their
## blows onto the taunter too, which is only worth it while the taunter is hale.
static func _taunt_value(b: GameBattle, by: int, ctx: Dictionary, turns: float, pot: float) -> float:
	if b._taunting() > -2:
		return -INF
	var alone := by < 0 and b.conscious_allies().is_empty()
	if not alone and _frac(b.unit(by).hp, int(b.unit_numbers(by)["max_hp"])) < float(GameFeats.setting("bot_taunt_min_hp")):
		return -INF
	return pot * float(ctx["total"]) * turns


## Carries out a plan for the heir through the battle's own actions.
static func act(b: GameBattle, plan: Dictionary) -> void:
	match str(plan.get("act", "attack")):
		"pass":
			b.pass_turn()
		"potion":
			b.use_potion()
		"ability":
			if str(plan.get("item", "")) != "":
				b.throw_vial(str(plan["item"]), int(plan["target"]))
			elif str(plan.get("feat", "")) != "":
				b.use_feat(b.heir.equipped_feats.find(plan["feat"]), int(plan["target"]))
			elif int(plan.get("skill", -1)) >= 0:
				b.use_skill(int(plan["skill"]), int(plan["target"]))
			else:
				b.cast_spell(str(plan["spell"]), int(plan["target"]))
		_:
			b.attack(int(plan.get("target", b.first_target())))


## The heir's turn decided and taken for them, as the autopilot and auto-battle do. A plan the
## battle turns down (an area that reaches no one by now) becomes a plain blow, so a turn is never
## lost to it. A toxin in the pack may first go on the blade (no turn). Returns the plan carried out.
static func auto_turn(b: GameBattle) -> Dictionary:
	var coated: Array = []
	if not b.heir.inventory.is_empty() and b.coating.is_empty():
		GamePlague.auto_coat(b)
		if not b.coating.is_empty():
			coated = b.events.duplicate()   # the turn's action starts its own events; keep the coating's to show
	var plan := choose(b, -1)
	var before := b.turn
	act(b, plan)
	if b.result == "" and b.turn == before:
		plan = {"act": "attack", "target": b.first_target()}
		b.attack(int(plan["target"]))
	if not coated.is_empty():
		b.events = coated + b.events
	return plan


## Whether the battle under way fights itself from its first turn: a hunt or hard hunt begun with
## auto-battle on. The player may switch it on or off in any battle.
static func auto_from_start(d: GameDynasty) -> bool:
	return d.auto_battle and d.battle != null and d.battle_kind in ["hunt", "hunt_hard"]
