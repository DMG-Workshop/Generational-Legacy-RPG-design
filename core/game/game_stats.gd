## The dynasty's statistics, worked out from what it keeps: how many heirs have lived and how they died,
## the greatest heir, the legends slain, and the gold each kept heir had when they died. Older heirs,
## folded into the Ages, count toward the totals but their gold is no longer kept. Logic only; the
## chronicle draws it (ui/play/chronicle_panel.gd).
class_name GameStats
extends RefCounted


## {generations, age, heirs, causes, legends, legend_kinds, best, gold, gold_by_age}. causes is [[cause, count]] most
## common first. best is the Hall of Fame's first entry ({} before any heir has died). gold is
## [{gen, gold}] for the heirs kept in full, oldest first, the living heir last.
static func summary(d: GameDynasty) -> Dictionary:
	var heirs := 0
	for row in d.ages.age_rows(d):
		heirs += int(row["heirs"])
	var living := d.heir != null and d.state == "life"
	if living:
		heirs += 1
	var causes := []
	var totals := d.ages.cause_totals(d)
	for c in totals:
		causes.append([str(c), int(totals[c])])
	causes.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	var legends := d.ages.legend_totals(d)
	var slain := 0
	for k in legends:
		slain += int(legends[k])
	var gold := []
	for rec in d.history:
		gold.append({"gen": int(rec.get("gen", 1)), "gold": int(rec.get("gold", 0))})
	if living:
		gold.append({"gen": d.heir.gen, "gold": d.heir.gold})
	return {
		"generations": d.gen,
		"age": d.age_number(),
		"ages_reached": _ages_reached(d),
		"heirs": heirs,
		"causes": causes,
		"legends": slain,
		"legend_kinds": legends.size(),
		"best": d.ages.hall[0] if not d.ages.hall.is_empty() else {},
		"gold": gold,
		"gold_by_age": _gold_by_age(d),
	}


## The Ages the saga has reached, oldest first: every Age a folded or kept heir died in, and the Age the saga
## is in now (so a new house reaches its first Age before anyone has died).
static func _ages_reached(d: GameDynasty) -> Array:
	var seen := {}
	for row in d.ages.age_rows(d):
		seen[int(row["age"])] = true
	seen[d.age_number()] = true
	var out := seen.keys()
	out.sort()
	return out


## One entry per Age, oldest first: its number, the heirs whose gold at death is known, and their average
## gold at death (-1 when none of its heirs has a known figure, as in an Age saved before gold was kept).
static func _gold_by_age(d: GameDynasty) -> Array:
	var out: Array = []
	for row in d.ages.age_rows(d):
		var known := int(row.get("gold_known", 0))
		var avg := -1
		if known > 0:
			avg = int(round(float(row.get("gold_sum", 0)) / float(known)))
		out.append({"age": int(row["age"]), "known": known, "average": avg})
	return out
