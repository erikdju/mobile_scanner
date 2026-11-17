package dev.steenbakker.mobile_scanner

import android.app.Activity
import android.view.OrientationEventListener
import android.view.Surface
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DeviceOrientationListenerTest {
    @Test
    fun physicalOrientationChangesWithoutRotatingDisplayOrUiEvents() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val listener = DeviceOrientationListener(activity)
        listener.start()
        assertNull(listener.physicalRotation)
        val uiOrientation = listener.getOrientation()
        val displayRotations = mutableListOf<Int>()
        listener.onDisplayRotationChanged = { displayRotations.add(it) }
        val sensor = DeviceOrientationListener::class.java
            .getDeclaredMethod("createOrientationEventListener").apply { isAccessible = true }
            .invoke(listener) as OrientationEventListener

        for ((angle, target) in listOf(
            0 to Surface.ROTATION_0,
            90 to Surface.ROTATION_270,
            180 to Surface.ROTATION_180,
            270 to Surface.ROTATION_90,
            359 to Surface.ROTATION_0,
        )) {
            sensor.onOrientationChanged(angle)
            assertEquals(target, listener.physicalRotation)
            assertEquals(uiOrientation, listener.getOrientation())
            sensor.onOrientationChanged(OrientationEventListener.ORIENTATION_UNKNOWN)
            assertEquals(target, listener.physicalRotation)
        }
        assertEquals(List(5) { Surface.ROTATION_0 }, displayRotations)
        listener.stop()
        assertNull(listener.physicalRotation)
        listener.start()
        assertNull(listener.physicalRotation)
        listener.stop()
    }
}
