#!/system/bin/sh
dir=${0%/*}
cfg=/odm/etc/camera/CameraHWConfiguration.config
hal=/vendor/lib64/hw/camera.qcom.sm8650.so
hash() { sha256sum "$1" | cut -d' ' -f1; }
skip() { /system/bin/log -t pjd110_camera_aux "Skipped: $*"; exit 0; }
[ "$(getprop ro.build.display.id)" = 'PJD110_16.0.2.400(CN01)' ] || skip build
[ "$(hash "$cfg")" = d199ecc85d4b2a59be0ed6d2c871e5cdccf5c0405ce66c2dce8437c51f2d3d8b ] || skip 'configuration mismatch'
[ "$(hash "$hal")" = 5a221fe94e6e4134158275bb4c92cdcb22426a8a27069e30c60d3a7aee92433d ] || skip 'HAL mismatch'
[ "$(hash "$dir/CameraHWConfiguration.config")" = 7480262c84246bace5c4d57c440b232bf903def923eff6cff14f7db00c5faf42 ] || skip 'module config mismatch'
[ "$(hash "$dir/camera.qcom.sm8650.so")" = 318812211b84db1828bc9ce8638c83ed01d8f18e65922e58040fe1ca730218f5 ] || skip 'module HAL mismatch'
chcon u:object_r:vendor_configs_file:s0 "$dir/CameraHWConfiguration.config" && chcon u:object_r:vendor_file:s0 "$dir/camera.qcom.sm8650.so" || skip 'label failed'
mount -o bind "$dir/CameraHWConfiguration.config" "$cfg" || skip 'config mount failed'
mount -o bind "$dir/camera.qcom.sm8650.so" "$hal" || skip 'HAL mount failed'
/system/bin/log -t pjd110_camera_aux 'Ready: Aux + 8K + 1152p480'

# Appended to the v4 post-fs-data script, after its build and payload checks.
gainlib=com.qti.sensor.lyt808.so
target=/odm/lib64/camera/$gainlib
awk -v p="$target" '$5==p {found=1} END {exit found}' /proc/1/mountinfo || skip 'gain library already mounted'
[ "$(hash "$target")" = 0c6a7318f20ef6d15642fc79b69a3eb609d6ebaeae1958f74d23f4e0544dcb74 ] || skip 'stock gain library mismatch'
[ "$(hash "$dir/$gainlib")" = 2ae9493cbf5862387b1906c511a210ecb66c1138bbf24ae604a934d5bd52cd6c ] || skip 'module gain library mismatch'
chcon u:object_r:vendor_file:s0 "$dir/$gainlib" || skip 'gain library label failed'
mount -o bind "$dir/$gainlib" "$target" || skip 'gain library mount failed'
/system/bin/log -t pjd110_camera_iso 'Ready: LYT808 full RAW ISO 6400'
