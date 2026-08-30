import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

// ---------------------------------------------------------------------------
// Cal Matters icon generator
// Black rounded square + gradient ring (gray -> orange) + orange flame.
// ---------------------------------------------------------------------------

void main() {
  generateIcon(1024, 'store/ic_launcher_512.png');
  generateIcon(192, 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');
  generateIcon(144, 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png');
  generateIcon(96, 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png');
  generateIcon(72, 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png');
  generateIcon(48, 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png');

  const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  generateIcon(1024, '$iosDir/Icon-App-1024x1024@1x.png');
  generateIcon(20, '$iosDir/Icon-App-20x20@1x.png');
  generateIcon(40, '$iosDir/Icon-App-20x20@2x.png');
  generateIcon(60, '$iosDir/Icon-App-20x20@3x.png');
  generateIcon(29, '$iosDir/Icon-App-29x29@1x.png');
  generateIcon(58, '$iosDir/Icon-App-29x29@2x.png');
  generateIcon(87, '$iosDir/Icon-App-29x29@3x.png');
  generateIcon(40, '$iosDir/Icon-App-40x40@1x.png');
  generateIcon(80, '$iosDir/Icon-App-40x40@2x.png');
  generateIcon(120, '$iosDir/Icon-App-40x40@3x.png');
  generateIcon(120, '$iosDir/Icon-App-60x60@2x.png');
  generateIcon(180, '$iosDir/Icon-App-60x60@3x.png');
  generateIcon(76, '$iosDir/Icon-App-76x76@1x.png');
  generateIcon(152, '$iosDir/Icon-App-76x76@2x.png');
  generateIcon(167, '$iosDir/Icon-App-83.5x83.5@2x.png');

  print('Done — all icons generated.');
}

const int _ss = 4; // supersample for smooth edges

void generateIcon(int size, String outPath) {
  final s = size * _ss;
  final canvas = img.Image(width: s, height: s, numChannels: 4);
  final S = s.toDouble();

  _fillRoundedRect(canvas, S, s ~/ 5);

  final cx = S / 2, cy = S / 2;

  // Gradient ring
  final ringOuter = S * 0.44;
  final ringThick = S * 0.105;
  _drawGradientRing(canvas, cx, cy, ringOuter, ringThick);

  // Flame: outer orange + bright core
  final fw = S * 0.155;  // half width
  final fh = S * 0.235;  // height
  final baseY = cy + S * 0.155;

  final outerPath = _flamePath(cx, baseY, fw, fh, 1.0);
  _fillPolygon(canvas, outerPath, 0xF4, 0x7A, 0x06);

  final corePath = _flamePath(cx, baseY - fh * 0.06, fw * 0.55, fh * 0.62, 0.62);
  _fillPolygon(canvas, corePath, 0xFF, 0xC9, 0x3A);

  // Downscale
  final down = img.copyResize(canvas, width: size, height: size,
      interpolation: img.Interpolation.cubic);

  final outBytes = img.encodePng(down);
  File(outPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(outBytes);
  print('  ${outPath} (${size}x${size})');
}

void _fillRoundedRect(img.Image canvas, double S, int r) {
  final size = canvas.width;
  for (int py = 0; py < size; py++) {
    for (int px = 0; px < size; px++) {
      bool outside = false;
      if (px < r && py < r) {
        outside = (px - r) * (px - r) + (py - r) * (py - r) > r * r;
      } else if (px >= size - r && py < r) {
        outside = (px - (size - r - 1)) * (px - (size - r - 1)) + (py - r) * (py - r) > r * r;
      } else if (px < r && py >= size - r) {
        outside = (px - r) * (px - r) + (py - (size - r - 1)) * (py - (size - r - 1)) > r * r;
      } else if (px >= size - r && py >= size - r) {
        outside = (px - (size - r - 1)) * (px - (size - r - 1)) + (py - (size - r - 1)) * (py - (size - r - 1)) > r * r;
      }
      if (outside) {
        canvas.setPixelRgba(px, py, 0, 0, 0, 0);
      } else {
        canvas.setPixelRgba(px, py, 0x0B, 0x0B, 0x0D, 255);
      }
    }
  }
}

void _drawGradientRing(img.Image canvas, double cx, double cy, double radius,
    double thickness) {
  final innerR = radius - thickness;
  final outerR = radius;
  final w = canvas.width, h = canvas.height;

  final minX = max(0, (cx - outerR - 1).floor());
  final maxX = min(w - 1, (cx + outerR + 1).ceil());
  final minY = max(0, (cy - outerR - 1).floor());
  final maxY = min(h - 1, (cy + outerR + 1).ceil());

  for (int py = minY; py <= maxY; py++) {
    for (int px = minX; px <= maxX; px++) {
      final dx = px - cx;
      final dy = py - cy;
      final dist2 = dx * dx + dy * dy;

      if (dist2 < innerR * innerR || dist2 > outerR * outerR) continue;

      final angle = atan2(dy.toDouble(), dx.toDouble()); // 0=right, pi=left

      final d1 = (angle - pi).abs();
      final t = min(1.0, d1 * 180 / (90 * pi));
      final tt = t * t * (3 - 2 * t); // smoothstep

      const gr = 0x40, gg = 0x40, gb = 0x44;
      const or = 0xF4, og = 0x7A, ob = 0x06;

      final r = (gr * (1 - tt) + or * tt).round().clamp(0, 255);
      final g = (gg * (1 - tt) + og * tt).round().clamp(0, 255);
      final b = (gb * (1 - tt) + ob * tt).round().clamp(0, 255);

      final edgeInner = (innerR * innerR - dist2).abs() / (thickness * 2);
      final edgeOuter = (outerR * outerR - dist2).abs() / (thickness * 2);
      final a = (min(edgeInner, edgeOuter).clamp(0.0, 1.0) * 255).round().clamp(0, 255);

      canvas.setPixelRgba(px, py, r, g, b, a);
    }
  }
}

// ---------------------------------------------------------------------------
// Flame path: flattened cubic Beziers -> polygon.
// Two prongs: tall right prong (tip at -1.0fh), shorter left prong
// (tip at -0.72fh), with a V-notch valley between them.
// ---------------------------------------------------------------------------

class _P {
  final double x, y;
  const _P(this.x, this.y);
}

List<_P> _flamePath(double cx, double baseY, double fw, double fh, double scale) {
  final pts = <_P>[];
  final s = scale;

  // Start at tall right prong tip
  var cur = _P(cx + 0.25 * fw * s, baseY - 1.00 * fh * s);

  final segments = <List<_P>>[
    // right side down to bottom-right
    [_P(cx + 0.32 * fw * s, baseY - 0.60 * fh * s), _P(cx + 1.02 * fw * s, baseY - 0.26 * fh * s), _P(cx + 1.00 * fw * s, baseY - 0.02 * fh * s)],
    // bottom right to bottom center
    [_P(cx + 0.92 * fw * s, baseY + 0.55 * fh * s), _P(cx + 0.28 * fw * s, baseY + 0.88 * fh * s)],
    // bottom center to bottom left
    [_P(cx - 0.28 * fw * s, baseY + 0.88 * fh * s), _P(cx - 0.90 * fw * s, baseY + 0.52 * fh * s)],
    // bottom left to left mid
    [_P(cx - 0.95 * fw * s, baseY + 0.20 * fh * s), _P(cx - 0.98 * fw * s, baseY + 0.05 * fh * s)],
    // left mid up to left prong tip
    [_P(cx - 1.02 * fw * s, baseY - 0.20 * fh * s), _P(cx - 0.30 * fw * s, baseY - 0.48 * fh * s), _P(cx - 0.15 * fw * s, baseY - 0.72 * fh * s)],
    // left prong tip curving inward-down to notch valley
    [_P(cx - 0.06 * fw * s, baseY - 0.80 * fh * s), _P(cx + 0.02 * fw * s, baseY - 0.55 * fh * s)],
    // notch valley up to tall right prong tip
    [_P(cx + 0.10 * fw * s, baseY - 0.62 * fh * s), _P(cx + 0.18 * fw * s, baseY - 0.78 * fh * s), _P(cx + 0.25 * fw * s, baseY - 1.00 * fh * s)],
  ];

  for (final seg in segments) {
    final start = cur;
    final end = seg.last;
    if (seg.length == 2) {
      // single control point? No: cubic needs 2 controls. Use quadratic-ish:
      // treat as cubic with both controls = seg[0]
      final c1 = seg[0];
      final c2 = seg[0];
      cur = end;
      pts.addAll(_cubic(start, c1, c2, end, 24));
    } else {
      final c1 = seg[0];
      final c2 = seg[1];
      cur = end;
      pts.addAll(_cubic(start, c1, c2, end, 24));
    }
  }
  return pts;
}

List<_P> _cubic(_P p0, _P c1, _P c2, _P p1, int steps) {
  final out = <_P>[];
  for (int i = 1; i <= steps; i++) {
    final t = i / steps;
    final mt = 1 - t;
    final x = mt * mt * mt * p0.x +
        3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p1.x;
    final y = mt * mt * mt * p0.y +
        3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p1.y;
    out.add(_P(x, y));
  }
  return out;
}

// Scanline fill of a closed polygon with even-odd rule.
void _fillPolygon(img.Image canvas, List<_P> poly, int r, int g, int b) {
  final w = canvas.width, h = canvas.height;
  final minY = max(0, poly.map((p) => p.y).reduce(min).floor() - 1);
  final maxY = min(h - 1, poly.map((p) => p.y).reduce(max).ceil() + 1);

  for (int py = minY; py <= maxY; py++) {
    final ys = py + 0.5;
    final xs = <double>[];
    for (int i = 0; i < poly.length; i++) {
      final p1 = poly[i];
      final p2 = poly[(i + 1) % poly.length];
      if ((p1.y <= ys && p2.y > ys) || (p2.y <= ys && p1.y > ys)) {
        final x = p1.x + (ys - p1.y) * (p2.x - p1.x) / (p2.y - p1.y);
        if (x >= -0.5 && x <= w - 0.5) xs.add(x);
      }
    }
    xs.sort();
    for (int i = 0; i + 1 < xs.length; i += 2) {
      final x0 = max(0, xs[i].round());
      final x1 = min(w - 1, xs[i + 1].round());
      for (int px = x0; px <= x1; px++) {
        canvas.setPixelRgba(px, py, r, g, b, 255);
      }
    }
  }
}
