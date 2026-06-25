import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// Brand colors (from lib/ui/core/theme.dart)
final green = img.ColorRgb8(0x2F, 0x6F, 0x5E); // primary
final greenDeep = img.ColorRgb8(0x24, 0x55, 0x49); // darker shade for gradient
final greenLight = img.ColorRgb8(0x3C, 0x8A, 0x74); // lighter shade for gradient
final cream = img.ColorRgb8(0xF7, 0xF5, 0xF1); // background / glyph
final terracotta = img.ColorRgb8(0xB5, 0x63, 0x4A); // secondary (coin)
final terracottaLight = img.ColorRgb8(0xD4, 0x90, 0x6F); // coin highlight

const size = 1024;

void main() {
  // ---- Full icon (iOS / legacy): full-bleed green gradient + glyph ----
  final full = img.Image(width: size, height: size, numChannels: 4);
  _fillGradient(full);
  _drawGlyph(full, cx: 512, cy: 528, scale: 1.18);
  File('assets/app_icon.png').writeAsBytesSync(img.encodePng(full));
  stdout.writeln('Generated assets/app_icon.png');

  // ---- Adaptive foreground (Android): transparent bg + glyph in safe zone ----
  final fg = img.Image(width: size, height: size, numChannels: 4);
  _drawGlyph(fg, cx: 512, cy: 512, scale: 0.98);
  File('assets/app_icon_foreground.png').writeAsBytesSync(img.encodePng(fg));
  stdout.writeln('Generated assets/app_icon_foreground.png');
}

/// Vertical gradient from a lighter green at top to a deeper green at bottom.
void _fillGradient(img.Image image) {
  for (int y = 0; y < size; y++) {
    final t = y / (size - 1);
    final r = _lerp(greenLight.r, greenDeep.r, t);
    final g = _lerp(greenLight.g, greenDeep.g, t);
    final b = _lerp(greenLight.b, greenDeep.b, t);
    final color = img.ColorRgb8(r, g, b);
    img.drawLine(image, x1: 0, y1: y, x2: size - 1, y2: y, color: color);
  }
  // Soft radial highlight in the upper-left for depth.
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = (x - 330) / 520.0;
      final dy = (y - 300) / 520.0;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 1.0) {
        final a = ((1.0 - d) * 38).round();
        _blend(image, x, y, img.ColorRgba8(255, 255, 255, a));
      }
    }
  }
}

/// Draws the wallet + coin glyph centered at (cx, cy). `scale` 1.0 ≈ 640px wide.
void _drawGlyph(img.Image image, {required int cx, required int cy, required double scale}) {
  int px(double u) => (cx + u * scale).round();
  int py(double u) => (cy + u * scale).round();
  int pr(double u) => (u * scale).round();

  // Coin rising out of the wallet (drawn first so the wallet overlaps it).
  final coinCx = px(-58);
  final coinCy = py(-188);
  img.fillCircle(image, x: coinCx, y: coinCy, radius: pr(118), color: terracotta, antialias: true);
  img.fillCircle(image, x: coinCx, y: coinCy, radius: pr(98), color: cream, antialias: true);
  img.fillCircle(image, x: coinCx, y: coinCy, radius: pr(88), color: terracottaLight, antialias: true);

  // Wallet body.
  img.fillRect(image,
      x1: px(-300), y1: py(-96), x2: px(300), y2: py(232),
      radius: pr(64), color: cream);

  // Seam / opening line near the top of the wallet.
  img.fillRect(image,
      x1: px(-300), y1: py(-30), x2: px(300), y2: py(2),
      radius: 0, color: green);

  // Clasp button (a green pill with the wallet's pocket).
  img.fillRect(image,
      x1: px(150), y1: py(70), x2: px(300), y2: py(170),
      radius: pr(50), color: green);
  img.fillCircle(image, x: px(212), y: py(120), radius: pr(26), color: cream, antialias: true);
}

int _lerp(num a, num b, double t) => (a + (b - a) * t).round();

void _blend(img.Image image, int x, int y, img.Color over) {
  final a = over.a / 255.0;
  final under = image.getPixel(x, y);
  image.setPixelRgb(
    x, y,
    (over.r * a + under.r * (1 - a)).round(),
    (over.g * a + under.g * (1 - a)).round(),
    (over.b * a + under.b * (1 - a)).round(),
  );
}
