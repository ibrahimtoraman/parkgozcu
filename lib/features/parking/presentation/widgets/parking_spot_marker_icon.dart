import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingSpotMarkerIcon {
  static const assetPath = 'assets/images/park_spot_marker.svg';
  static const frameCount = 6;
  static const pixelRatio = 4.0;
  static const viewBoxWidth = 120.0;
  static const viewBoxHeight = 156.0;
  static const pinTipY = 92.0;
  static const topPadding = 4.0;
  static const bottomPadding = 8.0;

  static Offset anchorForZoom(double zoom) {
    final displayWidth = displayWidthForZoom(zoom);
    final displayHeight = displayWidth * (viewBoxHeight / viewBoxWidth);
    final tipY = topPadding + (pinTipY / viewBoxHeight) * displayHeight;
    final totalHeight = topPadding + displayHeight + bottomPadding;
    return Offset(0.5, tipY / totalHeight);
  }

  static double? _cachedZoomBucket;
  static ui.Image? _sourceImage;
  static final List<BitmapDescriptor> _frames = [];

  static double displayWidthForZoom(double zoom) {
    const baseWidth = 30.0;
    final scaled = baseWidth * math.pow(1.08, zoom - 16);
    return scaled.clamp(24.0, 46.0);
  }

  static Future<void> ensureFrames({required double zoom}) async {
    final bucket = (zoom * 2).round() / 2;
    if (_cachedZoomBucket == bucket && _frames.length == frameCount) {
      return;
    }

    _cachedZoomBucket = bucket;
    _frames.clear();

    if (_sourceImage == null) {
      _sourceImage = await _loadSvgImage();
    }

    final displayWidth = displayWidthForZoom(zoom);
    final displayHeight = displayWidth * (viewBoxHeight / viewBoxWidth);

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
    return -2.5 * math.sin((frame / frameCount) * math.pi * 2);
  }

  static Future<ui.Image> _loadSvgImage() async {
    final svgString = await rootBundle.loadString(assetPath);
    final pictureInfo = await vg.loadPicture(
      SvgStringLoader(svgString),
      null,
    );

    final renderWidth = (viewBoxWidth * pixelRatio).round();
    final renderHeight = (viewBoxHeight * pixelRatio).round();
    final scale = renderWidth / pictureInfo.size.width;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawPicture(pictureInfo.picture);

    final picture = recorder.endRecording();
    return picture.toImage(renderWidth, renderHeight);
  }

  static Future<BitmapDescriptor> _buildFrame({
    required ui.Image image,
    required double displayWidth,
    required double displayHeight,
    required double bounceOffset,
  }) async {
    const topPadding = ParkingSpotMarkerIcon.topPadding;
    const bottomPadding = ParkingSpotMarkerIcon.bottomPadding;
    final canvasWidth = displayWidth * pixelRatio;
    final canvasHeight = (displayHeight + topPadding + bottomPadding) * pixelRatio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        0,
        topPadding + bounceOffset,
        displayWidth,
        displayHeight,
      ),
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
