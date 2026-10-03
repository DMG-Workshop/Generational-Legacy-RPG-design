## Tests for currency and wallet systems
##
## Tests: currency conversion, arithmetic, wallet transactions, history

extends GutTest


var wallet: Wallet
var currency: Currency


func before_each() -> void:
	wallet = Wallet.new()
	currency = Currency.new()


## Test: Create currency with all denominations
func test_create_currency_all_denominations() -> void:
	var c = Currency.new(1, 2, 3, 4)

	assert_eq(c.platinum, 1)
	assert_eq(c.gold, 2)
	assert_eq(c.silver, 3)
	assert_eq(c.copper, 4)


## Test: Convert to copper (total value)
func test_currency_to_copper() -> void:
	var c = Currency.new(1, 1, 1, 1)
	# 1pp (1000cp) + 1gp (100cp) + 1sp (10cp) + 1cp = 1111cp

	assert_eq(c.to_copper(), 1111)


## Test: Create from copper
func test_create_currency_from_copper() -> void:
	var c = Currency.from_copper(1111)

	assert_eq(c.platinum, 1)
	assert_eq(c.gold, 1)
	assert_eq(c.silver, 1)
	assert_eq(c.copper, 1)


## Test: Normalization (convert overflow)
func test_currency_normalization() -> void:
	var c = Currency.new(0, 0, 0, 25)  # 25 copper

	assert_eq(c.copper, 5)
	assert_eq(c.silver, 2)  # 25cp = 2sp + 5cp


## Test: Add currencies
func test_add_currencies() -> void:
	var c1 = Currency.new(0, 0, 5, 0)
	var c2 = Currency.new(0, 0, 3, 0)

	c1.add(c2)

	assert_eq(c1.to_copper(), 80)  # 8sp = 80cp


## Test: Subtract currencies
func test_subtract_currencies() -> void:
	var c1 = Currency.new(0, 0, 10, 0)
	var c2 = Currency.new(0, 0, 3, 0)

	var success = c1.subtract(c2)

	assert_true(success)
	assert_eq(c1.to_copper(), 70)  # 7sp = 70cp


## Test: Subtract insufficient funds
func test_subtract_insufficient() -> void:
	var c1 = Currency.new(0, 0, 2, 0)
	var c2 = Currency.new(0, 0, 5, 0)

	var success = c1.subtract(c2)

	assert_false(success)
	assert_eq(c1.to_copper(), 20)  # Unchanged


## Test: Check if has enough
func test_has_enough() -> void:
	var wallet_amount = Currency.new(0, 5, 0, 0)
	var cost = Currency.new(0, 3, 0, 0)

	assert_true(wallet_amount.has(cost))


## Test: Check if has enough (insufficient)
func test_has_not_enough() -> void:
	var wallet_amount = Currency.new(0, 2, 0, 0)
	var cost = Currency.new(0, 5, 0, 0)

	assert_false(wallet_amount.has(cost))


## Test: Compare currencies equal
func test_currency_equals() -> void:
	var c1 = Currency.new(1, 2, 3, 4)
	var c2 = Currency.from_copper(1111)

	assert_true(c1.equals(c2))


## Test: Compare greater than
func test_currency_greater_than() -> void:
	var c1 = Currency.new(0, 0, 10, 0)
	var c2 = Currency.new(0, 0, 5, 0)

	assert_true(c1.is_greater_than(c2))


## Test: Compare less than
func test_currency_less_than() -> void:
	var c1 = Currency.new(0, 0, 5, 0)
	var c2 = Currency.new(0, 0, 10, 0)

	assert_true(c1.is_less_than(c2))


## Test: Currency to string
func test_currency_to_string() -> void:
	var c = Currency.new(1, 2, 3, 4)
	var s = c.to_string()

	assert_true("1p" in s or "1pp" in s)
	assert_true("2g" in s or "2gp" in s)
	assert_true("3s" in s or "3sp" in s)
	assert_true("4c" in s or "4cp" in s)


## Test: Currency short string
func test_currency_short_string() -> void:
	var c = Currency.new(1, 2, 3, 4)
	var s = c.to_short_string()

	assert_true("1" in s and ("p" in s or "pp" in s))


## Test: Multiply currency
func test_multiply_currency() -> void:
	var c = Currency.new(0, 1, 0, 0)  # 1gp = 100cp

	var doubled = c.multiply(2.0)

	assert_eq(doubled.to_copper(), 200)  # 2gp


## Test: Percent of currency
func test_percent_of_currency() -> void:
	var part = Currency.new(0, 0, 5, 0)  # 50cp
	var whole = Currency.new(0, 0, 10, 0)  # 100cp

	var percent = part.percent_of(whole)

	assert_eq(percent, 50.0)


## Test: Wallet initialization
func test_wallet_init() -> void:
	var w = Wallet.new()

	assert_not_null(w.balance)
	assert_eq(w.get_total_copper(), 0)


## Test: Add to wallet
func test_wallet_add() -> void:
	var amount = Currency.new(0, 5, 0, 0)

	wallet.add(amount, "Found in chest")

	assert_eq(wallet.get_total_copper(), 500)


## Test: Remove from wallet (success)
func test_wallet_remove_success() -> void:
	var amount = Currency.new(0, 5, 0, 0)
	wallet.add(amount, "Starting funds")

	var cost = Currency.new(0, 2, 0, 0)
	var success = wallet.remove(cost, "Bought item")

	assert_true(success)
	assert_eq(wallet.get_total_copper(), 300)  # 3gp remaining


## Test: Remove from wallet (insufficient)
func test_wallet_remove_insufficient() -> void:
	var amount = Currency.new(0, 2, 0, 0)
	wallet.add(amount, "Starting funds")

	var cost = Currency.new(0, 5, 0, 0)
	var success = wallet.remove(cost, "Bought expensive item")

	assert_false(success)
	assert_eq(wallet.get_total_copper(), 200)  # Unchanged


## Test: Safe remove
func test_wallet_remove_safe() -> void:
	var amount = Currency.new(0, 2, 0, 0)
	wallet.add(amount, "Starting funds")

	var cost = Currency.new(0, 5, 0, 0)
	var removed = wallet.remove_safe(cost, "Partial payment")

	assert_eq(removed.to_copper(), 200)  # Got what was available
	assert_eq(wallet.get_total_copper(), 0)  # Wallet empty


## Test: Transfer between wallets
func test_wallet_transfer() -> void:
	var w1 = Wallet.new()
	var w2 = Wallet.new()

	var amount = Currency.new(0, 5, 0, 0)
	w1.add(amount, "Starting funds")

	var transfer = Currency.new(0, 2, 0, 0)
	var success = w1.transfer(w2, transfer, "Payment")

	assert_true(success)
	assert_eq(w1.get_total_copper(), 300)  # 3gp
	assert_eq(w2.get_total_copper(), 200)  # 2gp


## Test: Transaction history
func test_wallet_history() -> void:
	var amount = Currency.new(0, 1, 0, 0)
	wallet.add(amount, "Found gold")
	wallet.add(amount, "Quest reward")

	var history = wallet.get_history()

	assert_eq(history.size(), 2)
	assert_eq(history[0]["type"], "ADD")
	assert_eq(history[1]["type"], "ADD")


## Test: Recent transactions
func test_wallet_recent_transactions() -> void:
	for i in range(15):
		var amount = Currency.new(0, i + 1, 0, 0)
		wallet.add(amount, "Transaction %d" % i)

	var recent = wallet.get_recent_transactions(5)

	assert_eq(recent.size(), 5)


## Test: Clear wallet
func test_wallet_clear() -> void:
	var amount = Currency.new(1, 5, 10, 25)
	wallet.add(amount, "Large amount")

	assert_gt(wallet.get_total_copper(), 0)

	wallet.clear()

	assert_eq(wallet.get_total_copper(), 0)
