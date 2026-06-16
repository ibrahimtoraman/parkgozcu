import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingSpotMarkerIcon {
  static const assetPath = 'assets/images/park_spot_marker.png';
  static const frameCount = 8;
  static const pixelRatio = 3.0;
  static const anchor = Offset(0.5, 0.98);

  static double? _cachedZoomBucket;
  static ui.Image? _sourceImage;
  static double _imageAspectRatio = 1.3;
  static final List<BitmapDescriptor> _frames = [];

  static double displayWidthForZoom(double zoom) {
    const baseWidth = 26.0;
    final scaled = baseWidth * math.pow(1.1, zoom - 16);
    return scaled.clamp(20.0, 40.0);
  }

  static Future<void> ensureFrames({required double zoom}) async {
    final bucket = (zoom * 2).round() / 2;
    if (_cachedZoomBucket == bucket && _frames.length == frameCount) {
      return;
    }

    _cachedZoomBucket = bucket;
    _frames.clear();

    if (_sourceImage == null) {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frameInfo = await codec.getNextFrame();
      _sourceImage = frameInfo.image;
      _imageAspectRatio = _sourceImage!.height / _sourceImage!.width;
    }

    final displayWidth = displayWidthForZoom(zoom);
    final displayHeight = displayWidth * _imageAspectRatio;

    for (var frame = 0; frame < frameCount; frame++) {
      _frames.add(
        await _buildFrame(
          image: _sourceImage!,
          displayWidth: displayWidth,
          displayHeight: displayHeight,
          bounceOffset: _bounceOffset(frame),
        ),
      );
    }
  }

  static BitmapDescriptor frame({required int frameIndex}) {
    if (_frames.isEmpty) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
    return _frames[frameIndex % _frames.length];
  }

  static double _bounceOffset(int frame) {
    return -5 * math.sin((frame / frameCount) * math.pi * 2);
  }

  static Future<BitmapDescriptor> _buildFrame({
    required ui.Image image,
    required double displayWidth,
    required double displayHeight,
    required double bounceOffset,
  }) async {
    const topPadding = 6.0;
    final canvasWidth = displayWidth * pixelRatio;
    final canvasHeight = (displayHeight + topPadding) * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(displayWidth / 2, displayHeight + topPadding - 1),
        width: displayWidth * 0.34,
        height: 5,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, topPadding + bounceOffset, displayWidth, displayHeight),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final output = await picture.toImage(
      canvasWidth.round(),
      canvasHeight.round(),
    );
    final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static Future<void> preload({double zoom = 17}) {
    return ensureFrames(zoom: zoom);
  }
}
