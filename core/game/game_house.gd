## The family house: upgrades bought with the heir's gold between hunts and kept by the dynasty, so every
## heir after the first has them. Three tracks: the House Hall (a companion place per level), the
## Training Yard (more XP from training per level) and the Ranch (pens, a hatchery and a nursery: GameRanch.ranch).
## Prices are in balance.json; what a Ranch level does is in data/creatures/ranch.json. Level 0 is what
## a new house has, and changes nothing in play.
## A save holds only the levels bought, as {track: level}; anything else in it is dropped on load.
class_name GameHouse
extends RefCounted

const HALL := "hall"
const YARD := "yard"
const RANCH := "ranch"
const TRACKS := [HALL, YARD, RANCH]


## The level of a track, 0 to house_max_level.
static func level(d: GameDynasty, track: String) -> int:
	if d == null or not TRACKS.has(track):
		return 0
	return clampi(int(d.house.get(track, 0)), 0, max_level())


static func max_level() -> int:
	return int(GameData.bal("house_max_level"))


## What the next level of a track costs in gold, or -1 when it is at the top.
static func cost(d: GameDynasty, track: String) -> int:
	var lv := level(d, track)
	if not TRACKS.has(track) or lv >= max_level():
		return -1
	return int(round(float(GameData.bal("house_base_cost")) * pow(float(GameData.bal("house_cost_growth")), lv)))


## Why the next level cannot be bought now, or "" when it can.
static func buy_error(d: GameDynasty, track: String) -> String:
	if not TRACKS.has(track):
		return GameMessages.text("life", "no_track", {"track": track})
	if cost(d, track) < 0:
		return GameMessages.text("life", "at_best", {"track": track_name(track)})
	if d.heir.gold < cost(d, track):
		return GameMessages.text("life", "not_enough_gold_raw", {"needed": int(cost(d, track))})
	return ""


## Buys the next level of a track with the heir's gold. Returns what happened, for the chronicle.
static func buy(d: GameDynasty, track: String) -> String:
	var why := buy_error(d, track)
	if why != "":
		return why
	var price := cost(d, track)
	d.heir.gold -= price
	d.house[track] = level(d, track) + 1
	return GameMessages.text("life", "built", {"track": track_name(track), "level": int(level(d, track)), "price": int(price)})


## A companion place for each level of the Hall.
static func extra_party_slots(d: GameDynasty) -> int:
	return level(d, HALL) * int(GameData.bal("house_hall_slots_per_level"))


## The multiplier on training XP from the Yard: 1.0 at level 0.
static func train_xp_mult(d: GameDynasty) -> float:
	return 1.0 + float(level(d, YARD)) * float(GameData.bal("house_yard_train_xp_per_level"))


static func track_name(track: String) -> String:
	return GameMessages.text("life", "track_hall") if track == HALL else GameMessages.text("life", "track_yard") if track == YARD else GameMessages.text("life", "track_ranch") if track == RANCH else track


## The saved house, checked: only known tracks with whole-number levels in range survive.
static func from_dict(raw: Variant) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for track in TRACKS:
		if (raw as Dictionary).has(track) and typeof(raw[track]) in [TYPE_INT, TYPE_FLOAT]:
			var lv := clampi(int(raw[track]), 0, max_level())
			if lv > 0:
				out[track] = lv
	return out
