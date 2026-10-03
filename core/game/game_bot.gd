## Simple autopilot used by tests and the "Auto-live" button. Deterministic (no RNG of its own).
class_name GameBot
extends RefCounted


static func fight(d: GameDynasty) -> void:
	var b := d.battle
	var h := d.heir
	var guard := 0
	while not b.is_over() and guard < 200:
		guard += 1
		var low := float(h.hp) < float(h.max_hp()) * 0.4
		if low and h.potions > 0:
			b.use_potion()
		elif low and b.can_use_skill(1) and b.skill_info(1)["type"] == "heal":
			b.use_skill(1, -1)
		elif b.can_use_skill(0):
			b.use_skill(0, b.first_target())
		else:
			b.attack(b.first_target())
	d.finish_battle()


## One decision for the current life. Returns false once the heir has died.
static func step(d: GameDynasty) -> bool:
	var h := d.heir
	if d.state != "life":
		return false
	var hp_frac := float(h.hp) / float(h.max_hp())
	while h.potions < 3 and h.gold >= d.potion_price() * 2:
		d.buy_potion()
	if hp_frac < 0.55:
		d.rest()
	elif d.can_found_family():
		d.found_family()
	else:
		var boss := d.available_boss()
		if not boss.is_empty() and h.level >= int(boss.get("min_level", 99)) and hp_frac > 0.85:
			d.start_legend()
			fight(d)
		elif (h.battles_won + h.level) % 5 == 4:
			d.train(["str", "vit", "agi", "mag"][(h.battles_won + h.level) % 4])
		else:
			d.start_hunt("hunt")
			fight(d)
	return d.state == "life"


static func live_life(d: GameDynasty) -> void:
	var guard := 0
	while d.state == "life" and guard < 500:
		guard += 1
		if d.heir.age >= d.heir.lifespan * 0.9 and d.can_retire():
			d.retire()
		else:
			step(d)


static func choose_best(d: GameDynasty) -> void:
	if d.state == "succession":
		d.choose_heir(0)
