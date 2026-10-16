import java.awt.image.BufferedImage;
import java.io.File;
import java.util.zip.CRC32;
import javax.imageio.ImageIO;

public class WebpProbe {
    public static void main(String[] args) throws Exception {
        BufferedImage img = ImageIO.read(new File(args[0]));
        CRC32 crc = new CRC32();
        for (int y = 0; y < img.getHeight(); y++)
            for (int x = 0; x < img.getWidth(); x++) { int p = img.getRGB(x, y); crc.update(p); crc.update(p >>> 8); crc.update(p >>> 16); crc.update(p >>> 24); }
        System.out.println(System.getProperty("os.arch") + ": " + img.getWidth() + "x" + img.getHeight() + " type=" + img.getType() + " pixelCRC=" + Long.toHexString(crc.getValue()));
    }
}
