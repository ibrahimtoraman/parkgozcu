import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingSpotMarkerIcon {
  static const frameCount = 8;
  static const _ownColor = Color(0xFF16A34A);
  static const _otherColor = Color(0xFF22C55E);

  static final List<BitmapDescriptor> _ownFrames = [];
  static final List<BitmapDescriptor> _otherFrames = [];

  static Future<void> preload() async {
    if (_ownFrames.isNotEmpty) return;

    for (var frame = 0; frame < frameCount; frame++) {
      final bounce = _bounceOffset(frame);
      _ownFrames.add(await _build(color: _ownColor, bounceOffset: bounce));
      _otherFrames.add(await _build(color: _otherColor, bounceOffset: bounce));
    }
  }

  static BitmapDescriptor frame({required bool isOwnSpot, required int frameIndex}) {
    final frames = isOwnSpot ? _ownFrames : _otherFrames;
    if (frames.isEmpty) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    return frames[frameIndex % frames.length];
  }

  static double _bounceOffset(int frame) {
    return -7 * math.sin((frame / frameCount) * math.pi * 2);
  }

  static Future<BitmapDescriptor> _build({
    required Color color,
    required double bounceOffset,
  }) async {
    const pixelRatio = 3.0;
    const width = 52.0;
    const height = 68.0;
    const centerX = width / 2;
    final pinTipY = height - 5 + bounceOffset;
    final headCenterY = 22 + bounceOffset;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, pinTipY + 3), width: 18, height: 6),
      shadowPaint,
    );

    final pinPath = Path()
      ..moveTo(centerX, pinTipY)
      ..cubicTo(centerX - 2, pinTipY - 12, centerX - 17, headCenterY + 4, centerX - 17, headCenterY - 8)
      ..arcToPoint(
        Offset(centerX + 17, headCenterY - 8),
        radius: const Radius.circular(17),
        clockwise: false,
      )
      ..cubicTo(centerX + 17, headCenterY + 4, centerX + 2, pinTipY - 12, centerX, pinTipY)
      ..close();

    canvas.drawPath(pinPath, Paint()..color = color);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    canvas.drawCircle(
      Offset(centerX, headCenterY),
      12,
      Paint()..color = Colors.white,
    );

    _drawParkingGlyph(canvas, Offset(centerX, headCenterY), color);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).round(),
      (height * pixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static void _drawParkingGlyph(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 1), width: 12, height: 14),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawCircle(center.translate(0, -7), 2.2, paint);
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(-4.5, 5), width: 3, height: 3),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(center: center.translate(4.5, 5), width: 3, height: 3),
      paint,
    );
  }
}
