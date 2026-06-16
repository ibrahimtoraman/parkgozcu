import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/parking_spot_repository.dart';
import '../../domain/parking_spot.dart';
import '../parking_spot_controller.dart';

class ParkingSpotDetailSheet extends StatelessWidget {
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
      showDragHandle: true,
      builder: (_) => ParkingSpotDetailSheet(
        spot: spot,
        isOwnSpot: isOwnSpot,
      ),
    );
  }

  Future<void> _openStreetView() async {
    await openParkingSpotStreetView(
      latitude: spot.latitude,
      longitude: spot.longitude,
    );
  }

  Future<void> _removeSpot(BuildContext context) async {
    await context.read<ParkingSpotController>().removeSpot(spot.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF43A047).withValues(alpha: 0.15),
                child: const Icon(Icons.local_parking, color: Color(0xFF2E7D32)),
              ),
              title: Text(
                isOwnSpot ? 'Senin boş park bildirimin' : 'Boş park yeri',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                spot.address.isEmpty
                    ? '${spot.latitude.toStringAsFixed(5)}, ${spot.longitude.toStringAsFixed(5)}'
                    : spot.address,
              ),
            ),
            FilledButton.icon(
              onPressed: _openStreetView,
              icon: const Icon(Icons.streetview),
              label: const Text('Sokak Görünümü'),
            ),
            if (isOwnSpot) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _removeSpot(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Bildirimi kaldır'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
