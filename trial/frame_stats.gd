## Frame times over a sliding window, for the rendering trial: how long frames take on average, at the slow end
## (the 95th and 99th percentile, which is what a player feels as stutter), the worst, and the share over a limit.
## Logic only, so a test covers it.
extends RefCounted

var window: int
var _ms: Array = []          # the last `window` frame times in milliseconds, oldest first


func _init(p_window: int = 300) -> void:
	window = maxi(1, p_window)


func add(ms: float) -> void:
	_ms.append(ms)
	if _ms.size() > window:
		_ms.pop_front()


func reset() -> void:
	_ms.clear()


func count() -> int:
	return _ms.size()


func avg() -> float:
	if _ms.is_empty():
		return 0.0
	var sum := 0.0
	for v in _ms:
		sum += float(v)
	return sum / float(_ms.size())


## The frame time that `p` percent of frames were no slower than (nearest rank), 0 to 100.
func percentile(p: float) -> float:
	if _ms.is_empty():
		return 0.0
	var sorted := _ms.duplicate()
	sorted.sort()
	var rank := int(ceil(clampf(p, 0.0, 100.0) / 100.0 * float(sorted.size())))
	return float(sorted[clampi(rank - 1, 0, sorted.size() - 1)])


func worst() -> float:
	var w := 0.0
	for v in _ms:
		w = maxf(w, float(v))
	return w


func fps() -> float:
	var a := avg()
	return 1000.0 / a if a > 0.0 else 0.0


## The share (0 to 1) of frames slower than `limit_ms`.
func over(limit_ms: float) -> float:
	if _ms.is_empty():
		return 0.0
	var n := 0
	for v in _ms:
		if float(v) > limit_ms:
			n += 1
	return float(n) / float(_ms.size())
