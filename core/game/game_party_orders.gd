## The party's one-tap orders: what a companion's Attack / Defend / Skill / Auto buttons do. Each is a plain
## GameRound command (or the Auto switch) made from the round's own menu, so a tap goes through exactly the same
## queue, checks and resolution as the long way round the command panel; nothing here plays a round, rolls dice or
## touches the battle except through GameRound. No node, no UI.
##
##   static func command(r: GameRound, by: int, kind: String, foe_ref: String = "") -> Dictionary
##       # the command for "attack" | "defend" | "skill" ({} when there is none to give: "auto" is no command)
##       # attack: at the party's focus (GameRound.pin_ref) when one is set, else at `foe_ref` ("" = the heir's focus, as ever)
##       # skill: the member's first class skill they can use now, at the focus or `foe_ref`, else at any foe it reaches
##   static func skill_row(r: GameRound, by: int) -> Dictionary   # that skill's menu row, {} when none can be used now
##   static func give(r: GameRound, by: int, kind: String, foe_ref: String = "") -> String   # "" done, else why not (nothing changed); an order
##       # for a member on Auto takes them off Auto first, "auto" puts them on it
##   static func rows(r: GameRound) -> Array                      # what the buttons and figures show, one entry per member (see below)
##   static func all_auto(r: GameRound) -> bool                   # every companion who can still fight is on Auto (false with no companions)
##   static func set_all_auto(r: GameRound, on: bool) -> void     # the Auto switch of every companion (the heir keeps their own)
class_name GamePartyOrders
extends RefCounted

const KINDS := ["attack", "defend", "skill", "auto"]


static func skill_row(r: GameRound, by: int) -> Dictionary:
	for row in r.menu(by):
		if str(row["group"]) == "skill" and bool(row["enabled"]):
			return row
	return {}


## The foes to try for a skill, the focused one first, then the aimed one, then every living foe.
static func _foes(r: GameRound, foe_ref: String) -> Array:
	var out: Array = []
	for ref in [r.pin_ref(), foe_ref]:
		if str(ref) != "" and not out.has(ref) and GameRound._why_foe(r.b, str(ref)) == "":
			out.append(ref)
	for i in r.b.living_enemies():
		var ref := "enemy:%d" % i
		if not out.has(ref):
			out.append(ref)
	return out


static func command(r: GameRound, by: int, kind: String, foe_ref: String = "") -> Dictionary:
	match kind:
		"attack":
			var pin := r.pin_ref()
			var at := pin if pin != "" else (foe_ref if GameRound._why_foe(r.b, foe_ref) == "" else "")
			return {"act": "attack", "target": at}
		"defend":
			return {"act": "defend"}
		"skill":
			var row := skill_row(r, by)
			if row.is_empty():
				return {}
			var cmd: Dictionary = (row["cmd"] as Dictionary).duplicate(true)
			if str(row["aim"]) in ["foe", "area"]:
				for ref in _foes(r, foe_ref):
					cmd["target"] = ref
					if r.check(by, cmd) == "":
						return cmd
				return {}
			return cmd
	return {}


static func give(r: GameRound, by: int, kind: String, foe_ref: String = "") -> String:
	if kind == "auto":
		if by not in r.members():
			return GameMessages.text("life", "out_of_fight")
		r.set_auto(by, true)
		return ""
	var cmd := command(r, by, kind, foe_ref)
	if cmd.is_empty():
		return GameMessages.text("life", "no_skill_now" if kind == "skill" else "unknown_command")
	var why := r.check(by, cmd)
	if why != "":
		return why
	if bool(r.auto.get(by, false)):   # an order from the player takes the member off Auto, as a tap on their chip does
		r.set_auto(by, false)
	return r.queue(by, cmd)


static func all_auto(r: GameRound) -> bool:
	var any := false
	for by in r.members():
		if by < 0:
			continue
		any = true
		if not bool(r.auto.get(by, false)):
			return false
	return any


static func set_all_auto(r: GameRound, on: bool) -> void:
	for by in r.members():
		if by >= 0 and bool(r.auto.get(by, false)) != on:
			r.set_auto(by, on)


## What the order buttons need to know, one entry per member of the party in index order (fallen included):
## {"by", "name", "state" ("ready"|"held"|"ko"), "decision" (GameRound.view's), "active": which of attack | defend | skill | auto the
## member's decision is ("" for a spell, a feat, an item, a flee or no decision yet), "mark": what to show on their figure
## ("attack"|"defend"|"skill"|"auto"|"held"|"" for nothing), "word": the chip's short wording, "skill": the name of the skill the
## Skill button would use ("" when none can be used now)}. The heir is included, with no skill (their own panel has them all).
static func rows(r: GameRound) -> Array:
	var out: Array = []
	for m in r.view()["members"]:
		var by := int(m["by"])
		var decision := str(m["decision"])
		var kind := str(m["kind"])
		var active := ""
		if decision in ["auto", "fallback"]:
			active = "auto"
		elif decision == "queued" and kind in ["attack", "defend", "skill"]:
			active = kind
		var mark := active
		if decision == "queued" and mark == "" and kind in ["spell", "feat", "item"]:
			mark = "skill"
		if decision == "held":
			mark = "held"
		elif decision in ["ko", "empty"]:
			mark = ""
		var skill := "" if by < 0 else str(skill_row(r, by).get("label", ""))
		out.append({"by": by, "name": str(m["name"]), "state": str(m["state"]), "decision": decision, "active": active, "mark": mark,
			"word": str((m["chip"] as Dictionary).get("short", "")), "skill": skill})
	return out
