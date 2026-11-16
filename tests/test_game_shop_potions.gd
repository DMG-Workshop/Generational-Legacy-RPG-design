## Potions in the store (roadmap follow-up): the Store tab sells the healing potion at the same price and by the same rule as the
## life screen's Potion button; the button is shut when the heir cannot pay, the temple and forge tabs do not sell it, a town with
## no store has no tab to buy it in.
## Run: godot --headless --path . -s res://tests/test_game_shop_potions.gd
extends SceneTree

const ShopPanel := preload("res://ui/play/shop_panel.gd")

var fails := 0
var checks := 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	_run.call_deferred()


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await test_store()
	await test_other_tabs()
	await test_no_store()
	print("shop potion tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> GameDynasty:
	GameData.load_all()
	var d := GameDynasty.new_game(7, "Tess", "warrior", "faetouched", "human")
	d.pending_event = {}
	d.heir.gold = 1000
	return d


func test_store() -> void:
	var d := _fresh()
	ok(d.world.has_service("store"), "(Hearthmere has a store)")
	var shop: Control = ShopPanel.new()
	shop.dynasty = d
	shop.on_change = func(): pass
	shop.start_tab = "store"
	root.add_child(shop)
	await _frames(4)
	var buy: Button = shop.find_child("BuyPotion", true, false)
	ok(buy != null and not buy.disabled, "the Store tab has a Buy button for the healing potion")
	var price := d.potion_price()
	var gold := d.heir.gold
	var had := d.heir.potions
	buy.pressed.emit()
	await _frames(2)
	ok(d.heir.potions == had + 1 and d.heir.gold == gold - price, "pressing it buys one at the life screen's price (%d)" % price)
	d.heir.gold = price - 1
	shop._rebuild()
	await _frames(2)
	buy = shop.find_child("BuyPotion", true, false)
	ok(buy != null and buy.disabled, "with too little gold it is shut")
	var before := d.heir.potions
	if buy != null:
		buy.pressed.emit()
	ok(d.heir.potions == before, "and buys nothing")
	shop.queue_free()
	await _frames(2)


func test_other_tabs() -> void:
	var d := _fresh()
	var shop: Control = ShopPanel.new()
	shop.dynasty = d
	shop.on_change = func(): pass
	root.add_child(shop)
	await _frames(4)
	for t in ["temple", "forge", "gear"]:
		shop._show(t)
		await _frames(2)
		ok(shop.find_child("BuyPotion", true, false) == null, "the %s tab does not sell potions" % t)
	shop.queue_free()
	await _frames(2)


func test_no_store() -> void:
	var d := _fresh()
	d.world.location = "whisperwood"
	ok(not d.world.has_service("store"), "(Whisperwood has no store)")
	var shop: Control = ShopPanel.new()
	shop.dynasty = d
	shop.on_change = func(): pass
	shop.start_tab = "store"
	root.add_child(shop)
	await _frames(4)
	ok(shop.find_child("BuyPotion", true, false) == null, "away from a store there is nowhere here to buy one")
	shop.queue_free()
	await _frames(2)
