package local.pjd110.photocompat;

import android.graphics.Rect;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;

import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

/** Applies the proven APS metadata fix independently of the hook loader. */
public final class PhotoMetadata {
    private static final Rect EXPANDED = new Rect(0, 0, 8192, 6144);
    private final Method role, tenBit, video, nativeCopy, set, id;
    private final Field[] metadata;
    private final Constructor<?> resultCtor;
    private final Object key;

    public PhotoMetadata(Class<?> capture) throws ReflectiveOperationException {
        role = capture.getMethod("getRole");
        tenBit = capture.getMethod("get10BitsEnable");
        video = capture.getMethod("getIsVideoSnapshot");
        metadata = new Field[]{capture.getDeclaredField("mLogicMeta"), capture.getDeclaredField("mPhysicMeta")};
        for (Field field : metadata) field.setAccessible(true);
        nativeCopy = CaptureResult.class.getDeclaredMethod("getNativeCopy");
        nativeCopy.setAccessible(true);
        Class<?> blob = nativeCopy.getReturnType();
        resultCtor = CaptureResult.class.getDeclaredConstructor(String.class, blob, CaptureRequest.class, int.class, long.class);
        Constructor<?> keyCtor = CaptureResult.Key.class.getDeclaredConstructor(String.class, Class.class);
        resultCtor.setAccessible(true);
        keyCtor.setAccessible(true);
        key = keyCtor.newInstance("org.quic.camera2.ref.cropsize.DisableZoomCrop", Integer.TYPE);
        set = blob.getDeclaredMethod("set", CaptureResult.Key.class, Object.class);
        id = CaptureResult.class.getDeclaredMethod("getCameraId");
        set.setAccessible(true);
        id.setAccessible(true);
    }

    public Object[] apply(Object frame, String[] params) throws ReflectiveOperationException {
        if (frame == null || !eligible(params) || !Integer.valueOf(0).equals(role.invoke(frame))
                || !Boolean.FALSE.equals(video.invoke(frame))) return null;
        String bits = String.valueOf(tenBit.invoke(frame));
        if (!"1".equals(bits) && !"0".equals(bits)) return null;
        Object[] originals = null;
        try {
            for (int i = 0; i < metadata.length; i++) {
                Object value = metadata[i].get(frame);
                if (!(value instanceof CaptureResult)) continue;
                CaptureResult result = (CaptureResult) value;
                if (!EXPANDED.equals(result.get(CaptureResult.SCALER_CROP_REGION)) || result.getRequest() == null) continue;
                Object copy = nativeCopy.invoke(result);
                set.invoke(copy, key, 1);
                Object replacement = resultCtor.newInstance(id.invoke(result), copy, result.getRequest(),
                        result.getSequenceId(), result.getFrameNumber());
                if (originals == null) originals = new Object[metadata.length];
                originals[i] = result;
                metadata[i].set(frame, replacement);
            }
            return originals;
        } catch (ReflectiveOperationException | RuntimeException e) {
            restore(frame, originals);
            throw e;
        }
    }

    public void restore(Object frame, Object[] originals) throws IllegalAccessException {
        if (originals == null) return;
        for (int i = 0; i < metadata.length; i++)
            if (originals[i] != null) metadata[i].set(frame, originals[i]);
    }

    private static boolean eligible(String[] params) {
        if (params == null || (params.length & 1) != 0) return false;
        Map<String, String> values = new HashMap<>();
        for (int i = 0; i < params.length; i += 2) values.put(params[i], params[i+1]);
        String zoom = values.get("zoom_ratio");
        return ("1.0".equals(zoom) || "2.0".equals(zoom)) && zoom.equals(values.get("zoom_display_ratio"))
                && "4096".equals(values.get("crop_width")) && "3072".equals(values.get("crop_height"))
                && "4096".equals(values.get("output_width")) && "3072".equals(values.get("output_height"));
    }
}
