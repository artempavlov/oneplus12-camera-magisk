package local.pjd110.photocompat;

import android.app.Application;
import android.content.Context;
import android.os.Build;
import android.util.Log;

import de.robv.android.xposed.IXposedHookLoadPackage;
import de.robv.android.xposed.XC_MethodHook;
import de.robv.android.xposed.XposedHelpers;
import de.robv.android.xposed.callbacks.XC_LoadPackage;

/** Startup-scoped alternative to polling for the camera PID. */
public final class PhotoCompat implements IXposedHookLoadPackage {
    private static final String CAMERA = "com.oplus.camera";
    private static final String APS = "com.oplus.ocs.camera.consumer.apsAdapter.";
    private static final String TAG = "PJD110HeicCompat";
    private static final String RESTORE = "local.pjd110.photocompat.originals";

    @Override public void handleLoadPackage(XC_LoadPackage.LoadPackageParam p) {
        if (!CAMERA.equals(p.packageName) || !CAMERA.equals(p.processName)
                || !"PJD110_16.0.2.400(CN01)".equals(Build.DISPLAY)) return;
        XposedHelpers.findAndHookMethod(Application.class, "attach", Context.class, new XC_MethodHook() {
            @Override protected void afterHookedMethod(MethodHookParam param) {
                Context ctx = (Context) param.args[0];
                try {
                    if (CAMERA.equals(ctx.getPackageName()) && "6.020.639".equals(
                            ctx.getPackageManager().getPackageInfo(CAMERA, 0).versionName)) install(ctx.getClassLoader());
                } catch (ReflectiveOperationException | RuntimeException | android.content.pm.PackageManager.NameNotFoundException e) {
                    Log.w(TAG, "Compatibility hook not installed", e);
                }
            }
        });
    }

    private static void install(ClassLoader loader) throws ReflectiveOperationException {
        Class<?> capture = Class.forName(APS + "adapter.ApsCaptureParam", false, loader);
        Class<?> watermark = Class.forName(APS + "adapter.ApsWatermarkParam", false, loader);
        Class<?> client = Class.forName(APS + "APSClient", false, loader);
        PhotoMetadata metadata = new PhotoMetadata(capture);

        XposedHelpers.findAndHookMethod(client, "addFrameBuff", capture, String[].class, String[].class,
                watermark, new XC_MethodHook() {
            @Override protected void beforeHookedMethod(MethodHookParam call) throws ReflectiveOperationException {
                Object[] originals = metadata.apply(call.args[0], (String[]) call.args[1]);
                if (originals != null) call.setObjectExtra(RESTORE, originals);
            }
            @Override protected void afterHookedMethod(MethodHookParam call) throws IllegalAccessException {
                metadata.restore(call.args[0], (Object[]) call.getObjectExtra(RESTORE));
            }
        });
        Log.i(TAG, "Photo compatibility hook installed at application startup");
    }

}
