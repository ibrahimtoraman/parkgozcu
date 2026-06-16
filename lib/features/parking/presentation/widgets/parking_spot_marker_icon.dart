import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingSpotMarkerIcon {
  static Future<BitmapDescriptor> build({
    required double bounceOffset,
    bool isOwnSpot = false,
  }) async {
    const pixelRatio = 3.0;
    const width = 56.0;
    const height = 72.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(width / 2, height - 6 + bounceOffset),
        width: 18,
        height: 6,
      ),
      shadowPaint,
    );

    final pinPath = Path()
      ..moveTo(width / 2, height - 8 + bounceOffset)
      ..cubicTo(
        width / 2 - 18,
        height - 28 + bounceOffset,
        width / 2 - 18,
        16 + bounceOffset,
        width / 2,
        16 + bounceOffset,
      )
      ..cubicTo(
        width / 2 + 18,
        16 + bounceOffset,
        width / 2 + 18,
        height - 28 + bounceOffset,
        width / 2,
        height - 8 + bounceOffset,
      )
      ..close();

    final fillPaint = Paint()
      ..color = isOwnSpot ? const Color(0xFF1B5E20) : const Color(0xFF43A047);
    canvas.drawPath(pinPath, fillPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(pinPath, borderPaint);

    final iconPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(width / 2, 28 + bounceOffset),
          width: 18,
          height: 18,
        ),
        const Radius.circular(4),
      ),
      iconPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(width / 2, 28 + bounceOffset),
          width: 10,
          height: 10,
        ),
        const Radius.circular(2),
      ),
      fillPaint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).round(),
      (height * pixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static double bounceOffsetForPhase(double phase) {
    return -5 * math.sin(phase);
  }
}
