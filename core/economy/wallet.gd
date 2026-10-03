## Wallet: player's currency container with transaction history
##
## Tracks money, provides safe add/remove operations, logs transactions

extends Resource

class_name Wallet


var balance: Currency = Currency.new()
var transaction_history: Array[Dictionary] = []


func _init() -> void:
	balance = Currency.new()


## Add currency with reason logging
func add(amount: Currency, reason: String = "Unknown") -> void:
	balance.add(amount)
	_log_transaction("ADD", amount, reason)


## Remove currency (returns false if insufficient)
func remove(amount: Currency, reason: String = "Unknown") -> bool:
	if not balance.has(amount):
		return false

	balance.subtract(amount)
	_log_transaction("REMOVE", amount, reason)
	return true


## Safe remove (doesn't fail, just takes what's available)
func remove_safe(amount: Currency, reason: String = "Unknown") -> Currency:
	var available = Currency.from_copper(mini(balance.to_copper(), amount.to_copper()))
	balance.subtract(available)
	_log_transaction("REMOVE_SAFE", available, reason)
	return available


## Transfer to another wallet
func transfer(other: Wallet, amount: Currency, reason: String = "Transfer") -> bool:
	if not balance.has(amount):
		return false

	balance.subtract(amount)
	other.balance.add(amount)
	_log_transaction("TRANSFER_OUT", amount, reason)
	other._log_transaction("TRANSFER_IN", amount, reason)
	return true


## Check balance
func get_balance() -> Currency:
	return balance


## Display balance
func get_balance_string() -> String:
	return balance.to_string()


## Get total in copper
func get_total_copper() -> int:
	return balance.to_copper()


## Clear wallet
func clear() -> void:
	balance = Currency.new()
	_log_transaction("CLEAR", Currency.new(), "Wallet cleared")


## Get transaction history
func get_history() -> Array[Dictionary]:
	return transaction_history


## Get recent transactions
func get_recent_transactions(count: int = 10) -> Array[Dictionary]:
	return transaction_history.slice(maxi(0, transaction_history.size() - count))


## Log transaction
func _log_transaction(type: String, amount: Currency, reason: String) -> void:
	transaction_history.append({
		"type": type,
		"amount": amount.to_copper(),
		"display": amount.to_string(),
		"reason": reason,
		"timestamp": Time.get_ticks_msec(),
		"balance_after": balance.to_copper()
	})
