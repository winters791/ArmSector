import org.lwjgl.Sys;
import org.lwjgl.openal.AL;
import org.lwjgl.openal.AL10;
import org.lwjgl.opengl.Display;
import org.lwjgl.opengl.DisplayMode;
import org.lwjgl.opengl.GL11;

public class LwjglSmoke {
    public static void main(String[] args) throws Exception {
        System.out.println("arch=" + System.getProperty("os.arch") + " java=" + System.getProperty("java.version") + " lwjgl=" + Sys.getVersion());
        AL.create();
        System.out.println("AL: " + AL10.alGetString(AL10.AL_VERSION) + " / " + AL10.alGetString(AL10.AL_RENDERER));
        AL.destroy();
        for (boolean full : new boolean[]{false, true}) {
            if (full) Display.setDisplayModeAndFullscreen(Display.getDesktopDisplayMode());
            else Display.setDisplayMode(new DisplayMode(640, 360));
            Display.setTitle("LWJGL arm64 smoke test");
            Display.create();
            System.out.println((full ? "fullscreen" : "windowed") + " GL: " + GL11.glGetString(GL11.GL_VERSION) + " | " + GL11.glGetString(GL11.GL_RENDERER)
                + " | " + Display.getWidth() + "x" + Display.getHeight());
            System.out.println("READY " + (full ? "fullscreen" : "windowed"));
            long end = System.currentTimeMillis() + (full ? 4000 : 1500); int frames = 0;
            while (System.currentTimeMillis() < end) {
                GL11.glClearColor(0.1f, 0.2f, 0.4f, 1f); GL11.glClear(GL11.GL_COLOR_BUFFER_BIT);
                Display.update(); frames++;
            }
            System.out.println("frames=" + frames + " active=" + Display.isActive());
            Display.destroy();
        }
        System.out.println("OK");
    }
}
