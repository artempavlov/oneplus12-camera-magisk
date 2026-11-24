# Magisk sources this after extraction. Mark the known predecessor for
# removal only after all four comparisons and the staged files are ready.
hash() { sha256sum "$1" | cut -d' ' -f1; }
eqhash() { [ "$(hash "$1")" = "$2" ] || abort "Unexpected file: $1"; }
[ "$BOOTMODE" = true ] && [ "$(getprop ro.build.display.id)" = 'PJD110_16.0.2.400(CN01)' ] || abort 'Requires Magisk on PJD110 16.0.2.400(CN01)'
old=/data/adb/modules/pjd110_camera_aux
[ ! -e /data/adb/modules_update/pjd110_camera_aux ] || abort 'Pending Camera Aux update; finish it first'
if [ -e "$old" ]; then
    [ -d "$old" ] && [ ! -L "$old" ] && [ ! -e "$old/uninstall.sh" ] || abort 'Unrecognised Camera Aux installation'
    eqhash "$old/module.prop" 19c1416cd5b48a7cd379c087b0248c29bac1d46412246ec0e8f5570f58e714d4
    eqhash "$old/post-fs-data.sh" 3105cba15a274c8064fed2e889d3360b8792e8bcff10e022295f28ad61f1c21c
    eqhash "$old/CameraHWConfiguration.config" 7480262c84246bace5c4d57c440b232bf903def923eff6cff14f7db00c5faf42
    eqhash "$old/camera.qcom.sm8650.so" 318812211b84db1828bc9ce8638c83ed01d8f18e65922e58040fe1ca730218f5
fi
case "$(hash /odm/lib64/camera/com.qti.sensor.lyt808.so)" in
    0c6a7318f20ef6d15642fc79b69a3eb609d6ebaeae1958f74d23f4e0544dcb74|2ae9493cbf5862387b1906c511a210ecb66c1138bbf24ae604a934d5bd52cd6c) ;;
    *) abort 'Unrecognised active LYT808 gain library' ;;
esac
(cd "$MODPATH" && sha256sum -c contents.sha256) || abort 'Unified module payload verification failed'
set_perm "$MODPATH/CameraHWConfiguration.config" 0 0 0644 u:object_r:vendor_configs_file:s0
set_perm "$MODPATH/camera.qcom.sm8650.so" 0 0 0644 u:object_r:vendor_file:s0
set_perm "$MODPATH/lyt808-raw50.bin" 0 0 0644 u:object_r:vendor_file:s0
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/com.qti.sensor.lyt808.so" 0 0 0644 u:object_r:vendor_file:s0
set_perm "$MODPATH/service.sh" 0 0 0755
if [ -d "$old" ]; then
    touch "$old/remove" || abort 'Cannot mark Camera Aux v3 for removal'
fi
ui_print 'Unified camera module ready for next boot.'
