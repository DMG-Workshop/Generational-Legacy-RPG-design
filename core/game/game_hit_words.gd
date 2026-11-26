## The words the battle screen floats and shows for a blow and for loot ("miss", "block", "12 (3 blocked)", "Found"), from
## the battle text catalog so they can be translated. Core, no UI: the screen (ui/play/hit_fx.gd, loot_pop.gd) draws them.
class_name GameHitWords
extends RefCounted


static func miss() -> String:
	return GameMessages.line("fx_miss")


static func block() -> String:
	return GameMessages.line("fx_block")


static func blocked(n: String, absorbed: int) -> String:
	return GameMessages.line("fx_blocked", {"n": n, "absorbed": GameText.num(absorbed)})


static func shatter(n: String) -> String:
	return GameMessages.line("fx_shatter", {"n": n})


static func found() -> String:
	return GameMessages.line("fx_found")


## "** Epic Iron Sword": `rarity` is the mark and the rarity's word, `name` the item's.
static func find(rarity: String, item_name: String) -> String:
	return GameMessages.line("fx_find", {"rarity": rarity, "name": item_name})
