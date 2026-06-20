import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final canvas = img.Image(width: size, height: size);

  final bg = 0xFF2F6F5E;
  final white = 0xFFFFFFFF;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      canvas.setPixelRgba(x, y, 47, 111, 94, 255);
    }
  }

  final cx = size ~/ 2;
  final cy = size ~/ 2;

  _fillCircle(canvas, cx, cy, 420, white);
  canvas.setPixelRgba(cx, cy, 47, 111, 94, 255);
  _fillCircle(canvas, cx, cy, 380, bg);

  const gap = 40;
  final barTop = cy - 140;
  final barBottom = cy + 140;
  final barLeft = cx - 200;
  final barRight = cx + 200;

  _fillRect(canvas, barLeft, barTop, barRight, barBottom, white);

  final innerTop = barTop + gap;
  final innerBottom = barBottom - gap;
  final innerLeft = barLeft + gap;
  final innerRight = barRight - gap;

  _fillRect(canvas, innerLeft, innerTop, innerRight, innerBottom, bg);

  final innerBarTop = cy - 60;
  final innerBarBottom = cy + 60;
  final innerBarLeft = cx - 120;
  final innerBarRight = cx + 120;

  _fillRect(canvas, innerBarLeft, innerBarTop, innerBarRight, innerBarBottom, white);

  final innerDotTop = cy - 25;
  final innerDotBottom = cy + 25;
  final innerDotLeft = cx - 25;
  final innerDotRight = cx + 25;

  _fillRect(canvas, innerDotLeft, innerDotTop, innerDotRight, innerDotBottom, bg);

  final fgPng = img.encodePng(canvas);
  File('assets/app_icon_foreground.png').writeAsBytesSync(fgPng);

  final fullCanvas = img.Image(width: size, height: size);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      fullCanvas.setPixelRgba(x, y, 47, 111, 94, 255);
    }
  }

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final px = canvas.getPixel(x, y);
      if (px.r != 47 || px.g != 111 || px.b != 94) {
        fullCanvas.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }

  final fullPng = img.encodePng(fullCanvas);
  File('assets/app_icon.png').writeAsBytesSync(fullPng);

  // ignore: avoid_print
  print('Icons generated: assets/app_icon.png, assets/app_icon_foreground.png');
}

void _fillCircle(img.Image image, int cx, int cy, int radius, int color) {
  for (int y = cy - radius; y <= cy + radius; y++) {
    for (int x = cx - radius; x <= cx + radius; x++) {
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= radius * radius) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final a = (color >> 24) & 0xFF;
          final r = (color >> 16) & 0xFF;
          final g = (color >> 8) & 0xFF;
          final b = color & 0xFF;
          image.setPixelRgba(x, y, r, g, b, a);
        }
      }
    }
  }
}

void _fillRect(img.Image image, int left, int top, int right, int bottom, int color) {
  final a = (color >> 24) & 0xFF;
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;
  for (int y = top; y <= bottom && y < image.height; y++) {
    for (int x = left; x <= right && x < image.width; x++) {
      if (x >= 0 && y >= 0) {
        image.setPixelRgba(x, y, r, g, b, a);
      }
    }
  }
}
