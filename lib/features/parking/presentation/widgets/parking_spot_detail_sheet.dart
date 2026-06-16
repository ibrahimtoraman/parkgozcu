import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/parking_spot_repository.dart';
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
  Timer? _timer;
  late Duration _remaining;
  ParkingSpotPreview? _preview;
  bool _previewLoading = true;

  @override
  void initState() {
    super.initState();
    _remaining = widget.spot.remainingTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = widget.spot.remainingTime);
    });
    unawaited(_loadPreview());
  }

  Future<void> _loadPreview() async {
    final preview = await resolveParkingSpotPreview(
      latitude: widget.spot.latitude,
      longitude: widget.spot.longitude,
    );
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _previewLoading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _remainingLabel {
    if (_remaining <= Duration.zero) return 'Süresi doldu';
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    if (minutes > 0) return '$minutes dk $seconds sn kaldı';
    return '$seconds sn kaldı';
  }

  Future<void> _openDirections() async {
    final opened = await openParkingSpotDirections(
      latitude: widget.spot.latitude,
      longitude: widget.spot.longitude,
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Harita uygulaması açılamadı.')),
    );
  }

  Future<void> _removeSpot() async {
    await context.read<ParkingSpotController>().removeSpot(widget.spot.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final expiresAt = widget.spot.expiresAtLabel('tr_TR');
    final preview = _preview;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  child: const Icon(Icons.local_parking, color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isOwnSpot ? 'Senin boş park bildirimin' : 'Boş park yeri',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                      Text(
                        _remainingLabel,
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Bitiş: $expiresAt',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: _buildPreview(preview),
              ),
            ),
            if (preview != null && !preview.isStreetView) ...[
              const SizedBox(height: 8),
              Text(
                'Bu noktada sokak görünümü yok; uydu görüntüsü gösteriliyor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              widget.spot.address.isEmpty
                  ? '${widget.spot.latitude.toStringAsFixed(5)}, ${widget.spot.longitude.toStringAsFixed(5)}'
                  : widget.spot.address,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openDirections,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Git'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            if (widget.isOwnSpot) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _removeSpot,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Bildirimi kaldır'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ParkingSpotPreview? preview) {
    if (_previewLoading || preview == null) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return CachedNetworkImage(
      imageUrl: preview.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Konum görüntüsü yüklenemedi.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
