# OnePlus 12 Camera Magisk Module

A systemless camera module for the OnePlus 12 (PJD110). It makes more camera modes available to third-party apps through Camera2.

| Feature | What the module provides |
| --- | --- |
| Auxiliary lenses | Access through Camera2 on compatible apps |
| RAW on the main camera | 4096 x 3072 and 8192 x 6144 DNG |
| High ISO in 50 MP RAW | Up to ISO 6400 with sensor digital gain |
| 8K video | 7680 x 4320 at 24 frames per second |
| Slow motion | 2048 x 1152 at 480 frames per second |

The app must select the mode. The module does not add menus or controls to camera apps. The [Open Camera fork](https://github.com/artempavlov/opencamera) has a video mode picker.

Version 6 also fixes the unintended crop in the stock OnePlus Camera Photo mode. The separate Photo Compatibility APK runs only in `com.oplus.camera` and does not change how third-party apps process photos.

## Compatibility

- Device: OnePlus 12, model `PJD110`.
- Firmware: `PJD110_16.0.2.400(CN01)` (ColorOS 16).
- Tested with Magisk 30.7 and SELinux enforcing.
- Stock Camera `6.020.639`, [Vector 2.2](https://github.com/JingMatrix/Vector/releases/tag/v2.2) and a working Zygisk environment are required for the expanded RAW profile.

Do not install this ZIP on other firmware builds. Disable the module before an OTA update. The module checks the build ID and file checksums before it applies the changes. It does not write to `vendor` or `odm`.

## Quick start

Use Python 3 and [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools).
Make sure `adb` is on your computer's `PATH`.

1. Download and extract this repository with **Code → Download ZIP**, or clone it.
2. Enable USB debugging on the supported OnePlus 12.
3. Connect the phone by USB and accept the debugging prompt.
4. [Build the Photo Compatibility APK](#build-the-photo-compatibility-apk). Install it for the primary Android user. In Vector, enable **PJD110 Photo Compatibility** and select only **Camera** (`com.oplus.camera`, user 0) in its scope. Do not select System Framework or any other app.
5. From the repository folder, run:

   ```sh
   python3 build.py --from-phone --photo-compat dist/photo-compat/PJD110-PhotoCompat.apk
   ```

   On Windows, replace `python3` with `py -3` if Python uses the `py` launcher.

6. Copy `dist/PJD110-Camera-Unified-v6.zip` to the phone.
7. In **Magisk → Modules → Install from storage**, select that ZIP.
8. Reboot when Magisk reports success.

The build command reads four files over ADB and checks their SHA-256 hashes. It does not use root, install the module, or reboot the phone. The GitHub source ZIP is not an installer.

If ADB shows multiple devices, add `--serial SERIAL` with the serial from `adb devices`. If a camera overlay is active, disable it and reboot before trying again. If ADB cannot read the files, use the [manual build](#build-from-stock-files). Do not skip the checksum checks.

Do not use this module with unrelated camera overlays. Version 6 keeps module ID `pjd110_camera2_raw50`. The installer retires the known Camera Aux v3 if its files match.

The module skips the expanded RAW profile if the camera version, companion APK checksum, or Vector scope does not match. If you rebuild or update the companion APK, rebuild the Magisk ZIP with that exact APK. To stop using the companion, first disable the Magisk camera module and reboot to remove its overlays, then disable or uninstall the companion.

## Build the Photo Compatibility APK

Use Bash, JDK 21, Android SDK Platform 36 and Build Tools 35.0.0. Set `ANDROID_HOME` to your SDK. Obtain the [legacy Xposed API 82 JAR](https://api.xposed.info/reference/packages.html) (`de.robv.android.xposed:api:82`) for compilation; it is not bundled into the APK.

```sh
bash photo-compat/build.sh /path/to/api-82.jar dist/photo-compat
```

The script signs `dist/photo-compat/PJD110-PhotoCompat.apk` with a local development key. Keep `dist/photo-compat/photo-compat.jks` so you can sign updates with the same key. Install exactly the APK you pass to `build.py`.

## Disable or remove

1. Open the **Modules** tab in Magisk.
2. Disable or remove **OnePlus 12 Camera**.
3. Reboot to drop the module overlays.

If a mode is missing, check for a competing camera module and confirm that the app opens the main camera directly. The Magisk scripts log under `pjd110_camera_aux`, `pjd110_camera_iso`, and `pjd110_dualraw`.

## Build from stock files

Use Python 3. No third-party packages are required. Copy the following unmodified files from the supported firmware to `stock/`. Do not use the active files from a phone with the module enabled.

| Firmware path | Name in `stock/` |
| --- | --- |
| `/odm/etc/camera/CameraHWConfiguration.config` | `CameraHWConfiguration.config` |
| `/vendor/lib64/hw/camera.qcom.sm8650.so` | `camera.qcom.sm8650.so` |
| `/odm/lib64/camera/com.qti.sensor.lyt808.so` | `com.qti.sensor.lyt808.so` |
| `/odm/lib64/camera/com.qti.sensormodule.sunny_lyt808.bin` | `com.qti.sensormodule.sunny_lyt808.bin` |

```sh
python3 build.py --stock stock --photo-compat dist/photo-compat/PJD110-PhotoCompat.apk
```

The build checks each input and output against `patches.json`. It does not modify the stock files or connect to the phone. The Git tree contains the patch data and Magisk scripts, not complete vendor files.

## Verification

Testing version 5 on the supported phone confirmed that the module loaded its four overlays after reboot with SELinux enforcing. Earlier capture tests produced decodable 8K video, 2048 x 1152 slow-motion video, and RAW files at both resolutions. An equal-exposure DNG comparison also verified the gain increase at ISO 6400.

Version 6 was activated and tested without a reboot. Stock Photo retained the expected field of view in 10-bit HEIC at 1× and 2×, including the first shot after a cold app launch, and in JPEG at 1×. The new v6 installation path has not been tested through a fresh phone reboot.
