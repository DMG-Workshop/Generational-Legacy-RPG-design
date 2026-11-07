# Rendering trial

Roadmap item 36. Before any art is made for the isometric world, find out on **the target phone** how an
isometric pixel-art world drawn by Godot's 3D renderer actually performs: frame time, battery, heat and APK size.
Then decide the technique, and how art files are stored. The trial is a throwaway: it lives in `trial/`, is left
out of the game's builds, and can be deleted once the decision is made.

**Status: built and tested on a desktop; not yet measured on a phone.** The numbers in the tables below are
blank until someone runs it. Nothing here has been measured on a phone, so no decision has been made yet. This
page says how to measure, and what will count as a pass, so the verdict is not made up after the numbers are in.

## What the trial is

`trial/iso_trial.gd` is one scene:

- a field of 24 x 24 blocks of different heights (so height, digging and building are real, not a picture of them),
  lit by a sun and by up to 8 torch lights;
- an orthographic camera at the isometric angle (35.264 degrees, or the 2:1 pixel-art angle of 30) that pans on
  a fixed path, so every run draws the same thing;
- up to 200 `Sprite3D` figures walking in circles, drawn from the game's own creature and class sprites, with their
  texture filter on nearest and `alpha_cut` on discard (crisp pixels, cheap, and lit by the lights).

Two ways of putting the 3D world on the screen are compared:

| Technique | How | Why it might win |
|-----------|-----|------------------|
| **native** | the 3D world is drawn at the screen's full resolution | the simplest; no extra viewport |
| **lowres** | the 3D world is drawn into a small `SubViewport` (the screen's size divided by the pixel scale, 1 to 4) and that picture is scaled up with nearest filtering | far fewer pixels to shade, and every rendered pixel is a crisp square, which is what pixel art wants |

Everything else that can cost frame time can be changed while it runs, from buttons on the screen: the number of lights
(0, 2, 4, 8), the sun's shadow, the number of figures (10, 50, 100, 200), the camera pitch, whether the camera snaps
to whole rendered pixels (without it, panning makes pixel edges shimmer) and the pixel scale.

On the screen: frame time average, 95th and 99th percentile, worst, and the share of frames over 20 ms (a stutter
on a 60 Hz screen), over the last 300 frames; draw calls, objects and video memory; the device.

## Running it

**On a computer** (to look at it; the numbers mean nothing there):

```bash
godot --path . res://trial/iso_trial.tscn
```

**On the phone.** Build the trial as its own app (`GL Render Trial`, package
`com.dmgworkshop.generationallegacy.trial`, which installs beside the game and opens straight into the trial; the game's
own builds do not contain it):

1. On GitHub, Actions, **Rendering trial APK**, Run workflow on this branch (it also runs on a pull request that
   changes the trial). It builds the trial APK and the game's own APK and puts both sizes in the run's summary.
2. Download the `render-trial-apk` artifact, unzip it, and `adb install -r GenerationalLegacyTrial.apk` (or copy it to the phone
   and open it).

The app starts in `lowres`, scale 3, 4 lights, 50 figures, no shadow.

## Measuring

Prepare the phone the same way every time, so runs can be compared: charged to about 80%, **off the charger**,
airplane mode on, screen brightness fixed at 50%, battery saver off, no other apps open, at room temperature and
not just after a long game. Wait 10 minutes between runs so it cools.

**1. Sweep** (about 3 minutes). Tap **Sweep**. It runs 12 settings of 15 seconds each (the first 2 seconds of each are
not counted): both techniques, 0, 4 and 8 lights, 50 and 200 figures, the sun's shadow, and pixel scales 2 and 4.
When it finishes the screen lists one line per setting. Each line is also written to the phone's log (`TRIAL_RESULT`)
and to `trial_sweep.csv` in the app's folder; the log is the easy way to get them:

```bash
adb logcat -d -s godot:I | grep TRIAL_
```

**2. Soak** (10 minutes). Pick the technique and settings that did best, and run them for 10 minutes with the
battery and the temperature recorded. With the phone on USB:

```bash
tools/trial_adb.sh GenerationalLegacyTrial.apk 600 trial_out
```

It installs the trial, starts it on its soak (if the phone does not pass that on, tap **Soak 10 min** in the app),
and records the battery level and temperature every 30 seconds with `adb`, then collects the app's frame-time lines
(`TRIAL_SOAK`, every 30 seconds) and prints a summary: the device, the APK's size, the battery drop and how it
heated. (USB charges a little while it records, which flatters the battery figure: for a clean battery number, run
the soak with the phone off the cable and read the level before and after.) Repeat the soak for the other technique.

**3. Look at it** and write down what you see, because no number says it:

- Are the pixels crisp (the figures, the block edges) in both techniques, at each pixel scale?
- Pan with **Snap camera** on, then off. Does it shimmer without snapping, and is it steady with it?
- Do the lights read well on the sprites, or do they look flat or noisy?
- Are the buttons easy to tap at this size?
- How hot does the phone feel after the soak?

The tool cannot do these: GPU time is probably not available from Godot's compatibility renderer (not checked), so frame time is the
time between frames (it includes waiting for the screen, so on a phone that keeps up it sits at the screen's refresh
interval and the percentiles show the stutters), and the battery temperature is the battery sensor's.

## What counts as a pass

Decided here before any measuring, so the verdict is not fitted to the numbers. These are a proposal to argue
with, in the same way as the limits in `data/game/budgets.json`.

| Measure | Pass, for the settings the real world will start from (4 lights, 50 figures, no shadow) |
|---------|------|
| Frame time | average within 5% of the screen's refresh interval (16.7 ms on 60 Hz); 99th percentile at most 25 ms; no more than 2% of frames over 20 ms |
| Headroom | with 200 figures and 8 lights the 95th percentile is still at most 33 ms (30 fps), because the real world will be busier than the trial |
| Battery | at most 8% of the charge in 10 minutes with the screen on (about 48% an hour) |
| Heat | battery temperature never above 41 C and at most 8 C above the start; the 95th percentile in the last 2 minutes within 25% of the first 2 (thermal throttling shows as frame times creeping up) |
| APK size | the trial's APK within 1 MB of the game's (the trial adds scripts, no assets, so this checks the build, and the number is the engine's floor for the real art to add to); the game with art under 150 MB |
| Looks | crisp, steady and readable in the chosen technique |

## Deciding the technique

| What the numbers show | Decision |
|-----------------------|----------|
| native passes and looks as good | native: the simplest, with no extra viewport |
| native fails and lowres passes | lowres at the largest pixel scale that passes and still looks right; the world is drawn at the scale's resolution and scaled up with nearest filtering |
| both fail only with shadows or 8 lights | the same, with the sun's shadow off and at most 4 lights; any light beyond that is a visual effect that has to earn its place |
| both fail at 4 lights and no shadow | 3D is too heavy for the target phone at this view: reconsider drawing the world as 2D isometric tiles (CanvasItem), which gives up real height but is far cheaper, before any art is made |
| they pass but heat or battery fail | cap the frame rate (30 fps) in the Graphics settings (roadmap item 37) and measure again |

**The decision is not made.** When the phone numbers are in, fill the tables below and write the verdict here.

### Results (to fill in)

Device: _____ (Android ___, chip ___, screen ___ Hz)

| technique | scale | lights | shadow | figures | avg ms | p95 ms | p99 ms | over 20 ms | draw calls |
|-----------|-------|--------|--------|---------|--------|--------|--------|------------|------------|
| native | | 0 | off | 50 | | | | | |
| native | | 4 | off | 50 | | | | | |
| native | | 8 | off | 50 | | | | | |
| native | | 4 | on | 50 | | | | | |
| native | | 4 | off | 200 | | | | | |
| lowres | 3 | 0 | off | 50 | | | | | |
| lowres | 3 | 4 | off | 50 | | | | | |
| lowres | 3 | 8 | off | 50 | | | | | |
| lowres | 3 | 4 | on | 50 | | | | | |
| lowres | 3 | 4 | off | 200 | | | | | |
| lowres | 2 | 4 | off | 50 | | | | | |
| lowres | 4 | 4 | off | 50 | | | | | |

| soak (10 min) | battery | start / end temp | p95 first / last 2 min |
|---------------|---------|------------------|------------------------|
| native | | | |
| lowres | | | |

APK: trial ____ MB, game ____ MB (from the workflow's run summary).

Verdict: _____

## How art files are stored

This can be said now, because it does not depend on the phone: **there is no binary art in the repository, and there
should not be until there is a reason.** The art is text: sprites are grids of characters in `data/art/*.json` (152 KB
for every creature, class, race, shirt, piece of gear and scene), reviewed in a diff like code, and turned into
textures when the game loads (`SpriteArt`, packed into atlases; `SceneryArt`, painted from data). The one image in the
repository is the icon. The screenshot tests' PNGs (`tests/screenshots`, about 1.4 MB) are not game art, and are replaced
rarely.

So **Git LFS is not needed today**, and adding it early only makes cloning, CI and every fork harder. Turn it on when
the first of these is true:

- a single binary asset is over 1 MB (GitHub warns at 50 MB and refuses 100 MB, but history keeps every version, so
  the real limit is much lower), or
- binary assets together pass 50 MB, or
- an asset is expected to change often (a painted sheet redone each week would add its full size to history each time).

When that happens, track by extension in `.gitattributes` (`*.png` under an `art/` folder, `*.glb`, `*.gltf`, `*.blend`,
`*.ogg`, `*.wav`), set `lfs: true` on `actions/checkout` in every workflow that needs the files, and keep the `.import`
files in git (they are small text) while `.godot/` stays out.

Whichever way an image gets in, its import settings for pixel art are: **lossless** compression, **mipmaps off**, **filter
nearest** (the project's `default_texture_filter` set to Nearest), and `process/fix_alpha_border` on. The trial's sprites
already follow this (the texture filter is set on the `Sprite3D` and on the screen's `TextureRect`). If the trial shows the
text-grid pipeline costs too much at load on the phone (the 48 sprites are generated when first drawn), the fix is to
pre-generate them into atlas PNGs at build time, and that is the moment to introduce binary art, and LFS with it.

The decision about the technique and the decision about storage are independent: the trial answers the first, the numbers
above decide the second only if they show the load time is a problem.
