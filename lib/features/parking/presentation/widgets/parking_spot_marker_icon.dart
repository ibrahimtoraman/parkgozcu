import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingSpotMarkerIcon {
  static const assetPath = 'assets/images/park_spot_marker.svg';
  static const frameCount = 8;
  static const pixelRatio = 3.0;
  static const anchor = Offset(0.5, 0.97);

  static double? _cachedZoomBucket;
  static ui.Picture? _svgPicture;
  static Size _svgSize = Size.zero;
  static final List<BitmapDescriptor> _frames = [];

  static double displayWidthForZoom(double zoom) {
    const baseWidth = 42.0;
    final scaled = baseWidth * math.pow(1.16, zoom - 16);
    return scaled.clamp(30.0, 58.0);
  }

  static Future<void> ensureFrames({
    required double zoom,
    required int frameIndex,
  }) async {
    final bucket = (zoom * 2).round() / 2;
    if (_cachedZoomBucket == bucket && _frames.length == frameCount) {
      return;
    }

    _cachedZoomBucket = bucket;
    _frames.clear();

    if (_svgPicture == null) {
      final pictureInfo = await vg.loadPicture(
        SvgAssetLoader(assetPath),
        null,
      );
      _svgPicture = pictureInfo.picture;
      _svgSize = pictureInfo.size;
    }

    final displayWidth = displayWidthForZoom(zoom);
    final aspectRatio = _svgSize.height / _svgSize.width;
    final displayHeight = displayWidth * aspectRatio;

    for (var frame = 0; frame < frameCount; frame++) {
      _frames.add(
        await _buildFrame(
          displayWidth: displayWidth,
          displayHeight: displayHeight,
          bounceOffset: _bounceOffset(frame),
        ),
      );
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
    return -6 * math.sin((frame / frameCount) * math.pi * 2);
  }

  static Future<BitmapDescriptor> _buildFrame({
    required double displayWidth,
    required double displayHeight,
    required double bounceOffset,
  }) async {
    const topPadding = 8.0;
    final canvasWidth = displayWidth * pixelRatio;
    final canvasHeight = (displayHeight + topPadding) * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.scale(pixelRatio);
    canvas.translate(0, topPadding + bounceOffset);

    final scaleX = displayWidth / _svgSize.width;
    final scaleY = displayHeight / _svgSize.height;
    canvas.scale(scaleX, scaleY);
    canvas.drawPicture(_svgPicture!);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasWidth.round(),
      canvasHeight.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  static Future<void> preload({double zoom = 17}) {
    return ensureFrames(zoom: zoom, frameIndex: 0);
  }
}
