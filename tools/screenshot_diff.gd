## Comparing two screenshots, apart from the command line (tools/screenshots.gd) so a test can cover it. Two
## images are the same when they are the same size and no more than `share_max` of their pixels differ by more
## than `delta_max` in any channel. Software rendering on one machine repeats exactly (0 pixels differ), so the
## allowance is tiny: it is there for stray rounding, not for a changed screen. Renaming one button moves about
## 400 pixels of a 1280x720 screen, which must be seen. Anti-aliasing and text can shift by far more than the
## allowance between Mesa versions: the stored images are then made again on the machine that checks them
## (the workflow's "update" run), not the allowance loosened.
extends RefCounted

const DELTA_MAX := 12           # of 255, per channel, before a pixel counts as different
const SHARE_MAX := 0.00002      # of the pixels that may differ (18 of a 1280x720 screen) before the images count as different


## Compares `actual` with `baseline`. Returns {ok, reason, differing (pixels), share, worst (largest channel
## delta seen), diff (an Image: the actual dimmed, the differing pixels in magenta; null when the sizes differ)}.
static func compare(baseline: Image, actual: Image, delta_max: int = DELTA_MAX, share_max: float = SHARE_MAX) -> Dictionary:
	var out := {"ok": false, "reason": "", "differing": 0, "share": 0.0, "worst": 0, "diff": null}
	if baseline == null or actual == null or baseline.is_empty() or actual.is_empty():
		out["reason"] = "an image is missing or empty"
		return out
	if baseline.get_size() != actual.get_size():
		out["reason"] = "the size changed from %s to %s" % [baseline.get_size(), actual.get_size()]
		return out
	var a := baseline.duplicate() as Image
	var b := actual.duplicate() as Image
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var w := a.get_width()
	var h := a.get_height()
	var diff := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var limit := float(delta_max) / 255.0
	var count := 0
	var worst := 0.0
	for y in h:
		for x in w:
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var d := maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), maxf(absf(p.b - q.b), absf(p.a - q.a)))
			worst = maxf(worst, d)
			if d > limit:
				count += 1
				diff.set_pixel(x, y, Color(1.0, 0.0, 1.0))
			else:
				diff.set_pixel(x, y, Color(q.r * 0.35, q.g * 0.35, q.b * 0.35))
	out["differing"] = count
	out["share"] = float(count) / float(w * h)
	out["worst"] = int(round(worst * 255.0))
	out["diff"] = diff
	out["ok"] = out["share"] <= share_max
	out["reason"] = "" if out["ok"] else "%d pixels differ (%.3f%% of the screen, at most %.4f%% allowed)" % [count, 100.0 * float(out["share"]), 100.0 * share_max]
	return out
