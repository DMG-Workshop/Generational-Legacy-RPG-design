## The system clipboard, for copying a house backup out and pasting one in. Tests switch on `fake` so they
## neither touch the real clipboard (a headless run has none) nor depend on it.
extends RefCounted

static var fake := false
static var fake_text := ""


static func set_text(text: String) -> void:
	if fake:
		fake_text = text
	else:
		DisplayServer.clipboard_set(text)


static func get_text() -> String:
	return fake_text if fake else DisplayServer.clipboard_get()
