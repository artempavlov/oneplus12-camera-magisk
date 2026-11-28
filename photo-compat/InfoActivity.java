package local.pjd110.photocompat;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public final class InfoActivity extends Activity {
    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        TextView text = new TextView(this);
        int padding = (int) (24 * getResources().getDisplayMetrics().density + 0.5f);
        text.setPadding(padding, padding, padding, padding);
        text.setText("PJD110 Photo Compatibility\n\nRestores the field of view of photos in the stock OnePlus Camera when the expanded LYT-808 profile is active.\n\nVector scope: com.oplus.camera only. Disable the camera Magisk module before turning off this compatibility hook.");
        setContentView(text);
    }
}
