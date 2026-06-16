import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/parking_spot.dart';
import '../parking_spot_controller.dart';

class ParkingSpotDetailSheet extends StatefulWidget {
  const ParkingSpotDetailSheet({
    super.key,
    required this.spot,
    required this.isOwnSpot,
  });

  final ParkingSpot spot;
  final bool isOwnSpot;

  static Future<void> show(
    BuildContext context, {
    required ParkingSpot spot,
    required bool isOwnSpot,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ParkingSpotDetailSheet(
        spot: spot,
        isOwnSpot: isOwnSpot,
      ),
    );
  }

  @override
  State<ParkingSpotDetailSheet> createState() => _ParkingSpotDetailSheetState();
}

class _ParkingSpotDetailSheetState extends State<ParkingSpotDetailSheet> {
  Timer? _countdownTimer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.spot.remainingTime;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = widget.spot.remainingTime);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _remainingLabel {
    if (_remaining <= Duration.zero) return 'Süresi doldu';
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes dk $seconds sn kaldı';
    }
    return '$seconds sn kaldı';
  }

  Future<void> _openDirections() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.spot.latitude},${widget.spot.longitude}&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _removeSpot() async {
    final controller = context.read<ParkingSpotController>();
    await controller.removeSpot(widget.spot.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(widget.spot.latitude, widget.spot.longitude);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF43A047).withValues(alpha: 0.15),
                  child: const Icon(Icons.local_parking, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isOwnSpot ? 'Senin boş park bildirimin' : 'Boş park yeri',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _remainingLabel,
                        style: const TextStyle(color: AppColors.mediumGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: position,
                        zoom: 18.5,
                        tilt: 45,
                      ),
                      liteModeEnabled: false,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      markers: {
                        Marker(
                          markerId: MarkerId(widget.spot.id),
                          position: position,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                          anchor: const Offset(0.5, 1.0),
                        ),
                      },
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 36),
                          child: Icon(
                            Icons.person_pin_circle,
                            size: 54,
                            color: AppColors.red.withValues(alpha: 0.92),
                            shadows: const [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.spot.address.isEmpty
                  ? '${widget.spot.latitude.toStringAsFixed(5)}, ${widget.spot.longitude.toStringAsFixed(5)}'
                  : widget.spot.address,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (!widget.isOwnSpot) ...[
              const SizedBox(height: 4),
              Text(
                '${widget.spot.userName} tarafından bildirildi • ${DateFormat.Hm('tr_TR').format(widget.spot.createdAt)}',
                style: const TextStyle(color: AppColors.mediumGrey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openDirections,
              icon: const Icon(Icons.directions),
              label: const Text('Yol tarifi al'),
            ),
            if (widget.isOwnSpot) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _removeSpot,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Artık dolu / Kaldır'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
