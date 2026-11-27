## The stand-in for the app that the battle screen runs under when a fight is hosted over the open world's map (roadmap item
## 48): the battle screen asks its `app` for the dynasty, `hunt_stopped`, `autosave()`, `sound`, `current` and `show_state()`, and
## here `show_state()` (the battle screen's way of saying it is done) hands the screen back to the map instead of swapping to
## the life screen. A fight on the map never chains into the next hunt, so `hunt_stopped` is always on. Rendering only: it holds
## nothing of its own and the dynasty is the app's.
extends Node

var dynasty: GameDynasty
var app: Node               # the real app: it saves and has the sound
var sound: Node
var hunt_stopped := true
var ground_loot := false      # a fight on the open world's ground: the dead's spoils are left on the ground (GameDrops), not offered as a search
var current: Control = null   # the battle screen that is running (the app's `current` is the map)
var on_done: Callable


func autosave() -> void:
	if app != null and app.has_method("autosave"):
		app.autosave()


func show_state() -> void:
	if on_done.is_valid():
		on_done.call()
