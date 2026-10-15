import java.nio.ByteBuffer;
import org.lwjgl.BufferUtils;
import org.lwjgl.opengl.Display;
import org.lwjgl.opengl.DisplayMode;
import org.lwjgl.opengl.GL11;

// Tells whether the windowed GL surface is 1x (points) or 2x (Retina pixels): clears green, then reads the
// pixel at (2w-1, 2h-1), which only exists in a 2x surface.
public class LwjglDpiProbe {
    public static void main(String[] args) throws Exception {
        int w = 640, h = 360;
        Display.setDisplayMode(new DisplayMode(w, h));
        Display.create();
        for (int i = 0; i < 5; i++) { GL11.glClearColor(0f, 1f, 0f, 1f); GL11.glClear(GL11.GL_COLOR_BUFFER_BIT); Display.update(); }
        GL11.glClearColor(0f, 1f, 0f, 1f); GL11.glClear(GL11.GL_COLOR_BUFFER_BIT);
        ByteBuffer far = BufferUtils.createByteBuffer(4), near = BufferUtils.createByteBuffer(4);
        far.put(0, (byte) 7).put(1, (byte) 7).put(2, (byte) 7).put(3, (byte) 7);
        GL11.glReadPixels(w - 1, h - 1, 1, 1, GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, near);
        GL11.glReadPixels(2 * w - 1, 2 * h - 1, 1, 1, GL11.GL_RGBA, GL11.GL_UNSIGNED_BYTE, far);
        boolean nearGreen = (near.get(1) & 0xff) == 255, farGreen = (far.get(1) & 0xff) == 255 && (far.get(0) & 0xff) == 0;
        System.out.println("near(w-1,h-1) green=" + nearGreen + "  far(2w-1,2h-1) green=" + farGreen
            + "  => surface " + (farGreen ? "2x (BUG: game draws in a quarter)" : "1x (correct)"));
        Display.destroy();
    }
}
