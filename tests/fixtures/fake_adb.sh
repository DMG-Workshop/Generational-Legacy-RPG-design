#!/usr/bin/env bash
# A stand-in for adb for tests/test_game_trial.gd: answers the few commands tools/trial_adb.sh sends, the way a phone
# would. The battery drops one percent and warms half a degree each time it is asked. FAKE_STATE is a folder for
# its counter; FAKE_LOG, if set, is a file every command line is appended to.
[ -n "${FAKE_LOG:-}" ] && echo "adb $*" >> "$FAKE_LOG"
state="${FAKE_STATE:?}"
mkdir -p "$state"
case "$1" in
  get-state) echo device ;;
  install) echo Success ;;
  logcat)
    if [ "$2" = "-d" ]; then
      echo "I godot  : TRIAL_RESULT 1,10,lowres,3,426x240,4,0,50,35.3,1,16.70,17.10,18.00,19.00,0.0000,59.9,73,388,1000,20,llvmpipe,opengl3"
      echo "I godot  : unrelated line"
      echo "I godot  : TRIAL_SOAK 1,30,lowres,3,426x240,4,0,50,35.3,1,16.70,17.30,19.00,22.00,0.0010,59.8,73,388,1000,20,llvmpipe,opengl3"
      echo "I godot  : TRIAL_SOAK 1,600,lowres,3,426x240,4,0,50,35.3,1,18.90,24.00,31.00,40.00,0.0500,52.9,73,388,1000,20,llvmpipe,opengl3"
    fi ;;
  shell)
    shift
    case "$1" in
      getprop)
        case "$2" in
          ro.product.model) printf 'Pixel Test\r\n' ;;
          ro.build.version.release) printf '14\r\n' ;;
          ro.hardware) printf 'tensor\r\n' ;;
        esac ;;
      dumpsys)
        n=$(cat "$state/n" 2>/dev/null || echo 0)
        echo $((n + 1)) > "$state/n"
        printf 'Current Battery Service state:\r\n  AC powered: false\r\n  status: 3\r\n  level: %d\r\n  temperature: %d\r\n' $((80 - n)) $((310 + 5 * n)) ;;
      am|*) : ;;
    esac ;;
esac
