#!/system/bin/sh
# Magisk late_start service. The ODM partition stays read-only.
set -eu
dir=$(cd "$(dirname "$0")" && pwd -P)
target=/odm/lib64/camera/com.qti.sensormodule.sunny_lyt808.bin
profile=$dir/lyt808-raw50.bin
stock=df921ea87cfb2bd627f9926733658b2efebc3cf733338fd986e1ace3155d5f98
full=fa8e77fc2a8301e97bf6a4f59322a6c557d85cf1d6926a95b150701551c29b4c
svc=vendor.camera-provider
key=persist.vendor.camera.maxRAWSizes

note() { /system/bin/log -t pjd110_dualraw "$*"; }
skip() { note "Skipped: $*"; exit 0; }
hash() { sha256sum "$1" | cut -d' ' -f1; }
layers() { awk -v p="$target" '$5==p {n++} END{print n+0}' /proc/1/mountinfo; }
own() { [ "$(layers)" = 1 ] && [ "$(stat -c %d:%i "$target")" = "$(stat -c %d:%i "$profile")" ]; }
enabled() { [ ! -e "$dir/disable" ] && [ ! -e "$dir/remove" ]; }
unused() { [ "$(getprop "$key" __missing__)" = __missing__ ] && [ -z "$(resetprop -P "$key" || :)" ]; }
idle() {
    timeout 8 dumpsys media.camera | awk '/^Active Camera Clients:/{getline; idle=($0=="[]"); exit} END{exit !idle}'
}
restart() {
    old=$(getprop "init.svc_debug_pid.$svc")
    setprop ctl.restart "$svc" || return 1
    for i in $(seq 1 24); do
        sleep 1
        pid=$(getprop "init.svc_debug_pid.$svc")
        [ -n "$pid" ] && [ "$pid" != "$old" ] && [ -r "/proc/$pid/root$target" ] || continue
        [ "$(hash "/proc/$pid/root$target")" = "$1" ] || continue
        if timeout 6 dumpsys media.camera | awk -v dual="$2" -f "$dir/check-map.awk"; then return 0; fi
    done
    return 1
}

rollback() {
    trap - EXIT HUP INT TERM
    # A failed/aborted activation must not be retried automatically next boot.
    : > "$dir/disable"
    if own; then
        if [ "$(getprop "$key")" = 4 ]; then resetprop -n -d "$key" || :; fi
        if umount "$target" && [ "$(hash "$target")" = "$stock" ] && restart "$stock" 0 && unused; then
            note 'Activation failed; stock RAW restored. Module disabled.'
        else
            note 'Rollback incomplete; module disabled. Reboot for stock RAW.'
        fi
    else
        note 'Activation failed; no owned mount to remove. Module disabled.'
    fi
    rm -f "$dir/.activating"
    exit 1
}

main() {
    [ "$(id -u)" = 0 ] && [ "$(getprop ro.build.display.id)" = 'PJD110_16.0.2.400(CN01)' ] || skip 'unsupported build or no root'
    [ "$dir" = /data/adb/modules/pjd110_camera2_raw50 ] || skip 'not the installed module'
    if [ "$(readlink /proc/self/ns/mnt)" != "$(readlink /proc/1/ns/mnt)" ]; then
        [ "${1:-}" != master ] || skip 'global mount namespace unavailable'
        exec su -mm -c "ASH_STANDALONE=1 /data/adb/magisk/busybox sh '$dir/service.sh' master"
    fi
    exec 9>"$dir/.switch.lock"
    flock -n 9 || skip 'activation already in progress'
    enabled || exit 0
    if [ -e "$dir/.activating" ]; then
        : > "$dir/disable"; rm -f "$dir/.activating"
        skip 'previous activation was interrupted; module disabled'
    fi
    for i in $(seq 1 120); do
        [ "$(getprop sys.boot_completed)" = 1 ] && [ "$(getprop ro.persistent_properties.ready)" = true ] && break
        sleep 2
    done
    [ "$(getprop sys.boot_completed)" = 1 ] && [ "$(getprop ro.persistent_properties.ready)" = true ] || skip 'Android not ready'
    # Wait for face unlock/other clients rather than restarting an active session.
    ready=0
    for i in $(seq 1 60); do
        enabled || exit 0
        if [ "$(getprop init.svc.$svc)" = running ] && [ -n "$(getprop init.svc_debug_pid.$svc)" ] && idle; then ready=1; break; fi
        sleep 2
    done
    [ "$ready" = 1 ] || skip 'camera did not become idle'
    [ "$(layers)" = 0 ] && [ "$(hash "$target")" = "$stock" ] && [ "$(hash "$profile")" = "$full" ] || skip 'profile mismatch or existing mount'
    unused || skip 'existing RAW size override'
    chcon u:object_r:vendor_file:s0 "$profile" || skip 'cannot label profile'
    enabled && idle || skip 'camera in use or module disabled'
    : > "$dir/.activating"
    trap rollback EXIT
    trap 'exit 1' HUP INT TERM
    mount -o bind "$profile" "$target"
    own && resetprop -n "$key" 4 && [ "$(getprop "$key")" = 4 ] && [ -z "$(resetprop -P "$key" || :)" ] && restart "$full" 1 || exit 1
    rm "$dir/.activating"
    trap - EXIT HUP INT TERM
    note 'Ready: Camera2 ID 2 RAW 4096x3072 and 8192x6144.'
}
main "$@"
