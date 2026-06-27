// This is a standalone developer CLI script (not shipped app code), so
// printing progress to stdout is intentional.
// ignore_for_file: avoid_print
import 'dart:collection';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('assets/app_icon.jpg');
  if (!file.existsSync()) {
    print('Error: assets/app_icon.jpg not found');
    return;
  }
  
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: could not decode image');
    return;
  }
  
  final width = image.width;
  final height = image.height;
  
  // 1. Generate clean PNG of the full icon (assets/app_icon.png)
  // We want to make sure the white background is clean pure white (255, 255, 255)
  // so there are no compression artifacts.
  final fullImage = img.Image(width: width, height: height);
  
  // 2. Generate transparent foreground icon (assets/app_icon_foreground.png)
  final foregroundImage = img.Image(width: width, height: height, numChannels: 4);
  
  // Flood fill to find all background/shadow pixels starting from the corners
  final visited = List.generate(height, (_) => List.filled(width, false));
  final isBackground = List.generate(height, (_) => List.filled(width, false));
  
  final queue = Queue<List<int>>();
  
  // Add corners
  final corners = [
    [0, 0],
    [width - 1, 0],
    [0, height - 1],
    [width - 1, height - 1],
  ];
  
  for (final corner in corners) {
    final cx = corner[0];
    final cy = corner[1];
    queue.add([cx, cy]);
    visited[cy][cx] = true;
    isBackground[cy][cx] = true;
  }
  
  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    final x = current[0];
    final y = current[1];
    
    // Check neighbors
    final neighbors = [
      [x + 1, y],
      [x - 1, y],
      [x, y + 1],
      [x, y - 1],
    ];
    
    for (final neighbor in neighbors) {
      final nx = neighbor[0];
      final ny = neighbor[1];
      
      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        if (!visited[ny][nx]) {
          visited[ny][nx] = true;
          
          final p = image.getPixel(nx, ny);
          final r = p.r;
          
          // If Red channel is high, it's background/shadow (not the blue squircle)
          if (r > 80) {
            isBackground[ny][nx] = true;
            queue.add([nx, ny]);
          }
        }
      }
    }
  }
  
  // Now construct the images
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final p = image.getPixel(x, y);
      
      if (isBackground[y][x]) {
        // Full icon: make the background pure white
        // Except we can keep the shadow as it is
        final v = (p.r + p.g + p.b) / 3.0;
        if (v > 250) {
          fullImage.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          // Keep the original shadow pixel
          fullImage.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        }
        
        // Foreground: make background transparent, and shadow semi-transparent
        if (v > 250) {
          foregroundImage.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          // Semi-transparent shadow:
          // Alpha = 1 - (V / 254.0)
          // We clamp the alpha to be safe
          final alpha = (1.0 - (v / 254.0)).clamp(0.0, 1.0);
          final aByte = (alpha * 255).round();
          foregroundImage.setPixelRgba(x, y, 0, 0, 0, aByte);
        }
      } else {
        // Squircle body: copy exactly
        fullImage.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
        foregroundImage.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
      }
    }
  }
  
  // Write PNG files
  final fullPng = img.encodePng(fullImage);
  File('assets/app_icon.png').writeAsBytesSync(fullPng);
  print('Generated assets/app_icon.png');
  
  final foregroundPng = img.encodePng(foregroundImage);
  File('assets/app_icon_foreground.png').writeAsBytesSync(foregroundPng);
  print('Generated assets/app_icon_foreground.png');
}
