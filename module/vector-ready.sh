#!/system/bin/sh
# Fail closed: do not expand RAW geometry unless the matching camera-only hook is ready.
set -eu
vector=/data/adb/modules/zygisk_vector
compat=local.pjd110.photocompat
camera=com.oplus.camera
dir=${0%/*}
expected=$(cat "$dir/photo-compat.sha256")
[ "${#expected}" = 64 ] || exit 1

[ ! -e "$vector/disable" ] && [ ! -e "$vector/remove" ] && [ -x "$vector/cli" ] || exit 1
timeout 8 dumpsys package "$camera" | awk '$1=="versionName=6.020.639" {ok=1} END {exit !ok}' || exit 1
apk=$(pm path --user 0 "$compat" | awk -F: '$1=="package" && $2~/\/base\.apk$/ {print $2}')
[ -f "$apk" ] && [ "$(sha256sum "$apk" | cut -d' ' -f1)" = "$expected" ] || exit 1
report=$(timeout 8 "$vector/cli" modules ls --json) || exit 1
printf '%s\n' "$report" | awk '
  /"PACKAGE": "local.pjd110.photocompat"/ {pkg=1}
  /"UID": [1-9][0-9][0-9][0-9][0-9],?$/ {user0=1}
  /"STATUS": "enabled"/ {enabled=1}
  /}/ {if (pkg && user0 && enabled) found=1; pkg=user0=enabled=0}
  /"success": true/ {success=1}
  END {exit !(success && found)}' || exit 1
scope=$(timeout 8 "$vector/cli" scope ls --json "$compat") || exit 1
printf '%s\n' "$scope" | awk '
  /"APP_PACKAGE"/ {apps++; if ($0~/"APP_PACKAGE": "com.oplus.camera"/) camera=1}
  /"USER_ID": 0,?$/ {user0=1}
  /"success": true/ {success=1}
  END {exit !(success && apps==1 && camera && user0)}'
