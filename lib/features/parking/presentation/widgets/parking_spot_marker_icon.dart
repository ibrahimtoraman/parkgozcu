import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingSpotMarkerIcon {
  static BitmapDescriptor? _ownIcon;
  static BitmapDescriptor? _otherIcon;

  static Future<void> preload() async {
    _ownIcon ??= await _build(isOwnSpot: true);
    _otherIcon ??= await _build(isOwnSpot: false);
  }

  static BitmapDescriptor icon({required bool isOwnSpot}) {
    return (isOwnSpot ? _ownIcon : _otherIcon) ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  static Future<BitmapDescriptor> _build({required bool isOwnSpot}) async {
    const pixelRatio = 3.0;
    const width = 48.0;
    const height = 62.0;
    const centerX = width / 2;
    const pinTop = 8.0;
    const pinBottom = height - 4.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, pinBottom + 1),
        width: 16,
        height: 5,
      ),
      shadowPaint,
    );

    final fillColor =
        isOwnSpot ? const Color(0xFF1B5E20) : const Color(0xFF4CAF50);
    final pinPaint = Paint()..color = fillColor;

    final pinPath = Path()
      ..moveTo(centerX, pinBottom)
      ..quadraticBezierTo(centerX - 1, pinBottom - 10, centerX - 16, pinTop + 10)
      ..arcToPoint(
        Offset(centerX + 16, pinTop + 10),
        radius: const Radius.circular(16),
        clockwise: false,
      )
      ..quadraticBezierTo(centerX + 1, pinBottom - 10, centerX, pinBottom)
      ..close();
    canvas.drawPath(pinPath, pinPaint);

    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      Offset(centerX, pinTop + 18),
      11,
      Paint()..color = Colors.white,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'P',
        style: TextStyle(
          color: fillColor,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, pinTop + 18 - textPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).round(),
      (height * pixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
