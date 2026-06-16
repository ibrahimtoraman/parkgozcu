import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingSpotMarkerIcon {
  static const assetPath = 'assets/images/park_spot_marker.png';
  static const frameCount = 8;
  static const displayWidth = 68.0;
  static const pixelRatio = 3.0;
  static const anchor = Offset(0.5, 0.98);

  static ui.Image? _sourceImage;
  static final List<BitmapDescriptor> _frames = [];

  static Future<void> preload() async {
    if (_frames.isNotEmpty) return;

    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: (displayWidth * pixelRatio).round(),
    );
    final frameInfo = await codec.getNextFrame();
    _sourceImage = frameInfo.image;

    for (var frame = 0; frame < frameCount; frame++) {
      _frames.add(await _buildFrame(_bounceOffset(frame)));
    }
  }

  static BitmapDescriptor frame({
    required bool isOwnSpot,
    required int frameIndex,
  }) {
    if (_frames.isEmpty) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    return _frames[frameIndex % _frames.length];
  }

  static double _bounceOffset(int frame) {
    return -8 * math.sin((frame / frameCount) * math.pi * 2);
  }

  static Future<BitmapDescriptor> _buildFrame(double bounceOffset) async {
    final image = _sourceImage!;
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    const topPadding = 10.0;
    final canvasHeight = height + topPadding;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(width / 2, canvasHeight - 3),
        width: width * 0.38,
        height: 7,
      ),
      shadowPaint,
    );

    canvas.drawImage(
      image,
      Offset(0, topPadding + bounceOffset),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final output = await picture.toImage(
      width.round(),
      canvasHeight.round(),
    );
    final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
