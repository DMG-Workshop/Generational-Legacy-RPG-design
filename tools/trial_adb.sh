#!/usr/bin/env bash
# Measures the rendering trial on a phone connected by USB (docs/RENDER_TRIAL.md): installs the trial APK, starts it,
# and while it runs records the battery level and temperature, then collects the trial's own frame-time lines
# from the phone's log. The numbers adb cannot give (what the screen looks like, how hot the phone feels) are for you.
#
#   tools/trial_adb.sh APK [SECONDS] [OUT_DIR]
#     APK      the trial APK (GenerationalLegacyTrial.apk from the "Rendering trial APK" workflow)
#     SECONDS  how long to record (default 600, the length of the app's own soak)
#     OUT_DIR  where the files go (default trial_out)
#   ADB=/path/to/adb          use this adb
#   INTERVAL=30               seconds between battery samples
#   SKIP_INSTALL=1            the trial is installed already
#
# Needs a phone with USB debugging on, awake and unlocked, charged to about 80% and left off the charger.
# The app is started on its own soak ("--soak"); if the phone does not pass that on, tap "Soak 10 min" in the app
# within a few seconds. Writes battery.csv, trial_log.txt and summary.txt in OUT_DIR and prints the summary.
set -euo pipefail

apk="${1:?usage: tools/trial_adb.sh APK [SECONDS] [OUT_DIR]}"
duration="${2:-600}"
out="${3:-trial_out}"
adb="${ADB:-adb}"
interval="${INTERVAL:-30}"
pkg="com.dmgworkshop.generationallegacy.trial"
activity="com.godot.game.GodotApp"

mkdir -p "$out"
"$adb" get-state > /dev/null 2>&1 || { echo "No phone found by adb: connect it, turn on USB debugging and accept the prompt." >&2; exit 1; }

model=$("$adb" shell getprop ro.product.model | tr -d '\r')
android=$("$adb" shell getprop ro.build.version.release | tr -d '\r')
soc=$("$adb" shell getprop ro.hardware | tr -d '\r')
apk_bytes=$(wc -c < "$apk" | tr -d ' ')

if [ -z "${SKIP_INSTALL:-}" ]; then
  "$adb" install -r "$apk" > /dev/null
fi

# one battery reading: level (percent), temperature (degrees C), status
battery() {
  local text level temp status
  text=$("$adb" shell dumpsys battery | tr -d '\r')
  level=$(printf '%s\n' "$text" | sed -n 's/^ *level: *//p' | head -1)
  temp=$(printf '%s\n' "$text" | sed -n 's/^ *temperature: *//p' | head -1)
  status=$(printf '%s\n' "$text" | sed -n 's/^ *status: *//p' | head -1)
  awk -v l="$level" -v t="$temp" -v s="$status" 'BEGIN { printf "%s,%.1f,%s", l, t / 10.0, s }'
}

"$adb" logcat -c || true
"$adb" shell am force-stop "$pkg" || true
echo "elapsed_s,level_percent,temp_c,status" > "$out/battery.csv"
echo "0,$(battery)" >> "$out/battery.csv"
"$adb" shell am start -n "$pkg/$activity" --es command_line_params "--soak" > /dev/null

elapsed=0
while [ "$elapsed" -lt "$duration" ]; do
  step=$interval
  if [ $((duration - elapsed)) -lt "$step" ]; then step=$((duration - elapsed)); fi
  sleep "$step"
  elapsed=$((elapsed + step))
  echo "$elapsed,$(battery)" >> "$out/battery.csv"
done

"$adb" logcat -d -s godot:I | tr -d '\r' | grep 'TRIAL_' > "$out/trial_log.txt" || true

{
  echo "Device: $model (Android $android, $soc)"
  echo "APK: $apk_bytes bytes ($(awk -v b="$apk_bytes" 'BEGIN { printf "%.1f", b / 1048576 }') MB)"
  awk -F, 'NR == 2 { l0 = $2; t0 = $3 } NR > 1 { l1 = $2; t1 = $3; if ($3 > tmax) tmax = $3; e = $1 }
    END { printf "Battery: %s%% to %s%% in %d s (%.1f%% per 10 minutes)\nTemperature: %.1f C at the start, %.1f C at the end, %.1f C at most\n", l0, l1, e, (e > 0 ? (l0 - l1) * 600.0 / e : 0), t0, t1, tmax }' "$out/battery.csv"
  rows=$(grep -c 'TRIAL_SOAK' "$out/trial_log.txt" || true)
  echo "Frame-time lines from the app: $rows"
  if [ "$rows" -gt 0 ]; then
    echo "First and last (columns: time, elapsed, technique, scale, size, lights, shadow, figures, pitch, snap, avg, p95, p99, worst, over_20ms, fps, ...):"
    grep 'TRIAL_SOAK' "$out/trial_log.txt" | head -1
    grep 'TRIAL_SOAK' "$out/trial_log.txt" | tail -1
  else
    echo "None: the soak did not start. Tap 'Soak 10 min' in the app and run this again with SKIP_INSTALL=1."
  fi
} | tee "$out/summary.txt"
