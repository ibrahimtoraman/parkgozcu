import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/services/address_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reports/presentation/report_controller.dart';
import '../domain/parking_spot.dart';
import 'parking_spot_controller.dart';
import 'widgets/parking_spot_detail_sheet.dart';
import 'widgets/parking_spot_marker_icon.dart';

class ParkAreaPage extends StatefulWidget {
  const ParkAreaPage({super.key});

  @override
  State<ParkAreaPage> createState() => _ParkAreaPageState();
}

class _ParkAreaPageState extends State<ParkAreaPage>
    with SingleTickerProviderStateMixin {
  final _addressService = AddressService();
  GoogleMapController? _mapController;
  StreamSubscription<List<ParkingSpot>>? _spotsSubscription;
  List<ParkingSpot> _spots = const [];
  Set<Marker> _spotMarkers = {};
  LatLng? _selectedPosition;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _currentUserId;
  late final AnimationController _bounceController;
  Timer? _markerRefreshTimer;
  double _bouncePhase = 0;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceController.addListener(() {
      _bouncePhase = _bounceController.value * math.pi;
    });
    _markerRefreshTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || _spots.isEmpty) return;
      unawaited(_rebuildSpotMarkers());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentUserId = context.read<AuthController>().user?.id;
    _spotsSubscription ??=
        context.read<ParkingSpotController>().spots.listen((spots) {
      if (!mounted) return;
      setState(() => _spots = spots);
      unawaited(_rebuildSpotMarkers());
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportController = context.watch<ReportController>();
    final currentPosition = reportController.currentPosition;

    final markers = {
      ..._spotMarkers,
      if (_selectedPosition != null)
        Marker(
          markerId: const MarkerId('selected-parking-position'),
          position: _selectedPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          anchor: const Offset(0.5, 1.0),
          zIndexInt: 900,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Park Alanı'),
        actions: [
          IconButton(
            onPressed: () => _goToCurrentLocation(currentPosition),
            icon: const Icon(Icons.my_location),
            tooltip: 'Konumum',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentPosition,
              zoom: 16.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _animateTo(currentPosition);
            },
            onTap: _selectPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: markers,
            padding: const EdgeInsets.only(bottom: 120, top: 72),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: Color(0xFF2E7D32)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Boş park bildirimleri 10 dakika sonra otomatik kaybolur.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Material(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.place, color: Colors.orange),
                          title: const Text(
                            'Haritadan konum seçildi',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: const Text('Boş yer bildir butonuna bas'),
                          trailing: IconButton(
                            onPressed: () => setState(() => _selectedPosition = null),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _reportAvailableSpot,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.local_parking),
                    label: Text(
                      _selectedPosition == null
                          ? 'Burada boş yer var'
                          : 'Seçili yerde boş park bildir',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectPosition(LatLng position) {
    setState(() => _selectedPosition = position);
  }

  Future<void> _rebuildSpotMarkers() async {
    if (_spots.isEmpty) {
      if (_spotMarkers.isNotEmpty) {
        setState(() => _spotMarkers = {});
      }
      return;
    }

    final bounceOffset =
        ParkingSpotMarkerIcon.bounceOffsetForPhase(_bouncePhase);
    final markers = <Marker>{};

    for (final spot in _spots) {
      final isOwnSpot = spot.userId == _currentUserId;
      final icon = await ParkingSpotMarkerIcon.build(
        bounceOffset: bounceOffset,
        isOwnSpot: isOwnSpot,
      );
      markers.add(
        Marker(
          markerId: MarkerId(spot.id),
          position: LatLng(spot.latitude, spot.longitude),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => ParkingSpotDetailSheet.show(
            context,
            spot: spot,
            isOwnSpot: isOwnSpot,
          ),
          zIndexInt: isOwnSpot ? 80 : 40,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _spotMarkers = markers);
  }

  Future<void> _reportAvailableSpot() async {
    if (!_ensureSignedIn()) return;

    final auth = context.read<AuthController>();
    final user = auth.user;
    if (user == null) return;

    final reportController = context.read<ReportController>();
    final position = _selectedPosition ?? reportController.currentPosition;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final address = await _addressService.reverseAddress(position);
      if (!mounted) return;

      final parkingController = context.read<ParkingSpotController>();
      await parkingController.reportAvailableSpot(
        userId: user.id,
        userName: user.name,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      if (!mounted) return;
      setState(() => _selectedPosition = null);
      await _animateTo(position, zoom: 17.5);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Boş park yeri 10 dakika boyunca haritada görünecek.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Park yeri bildirilemedi. Tekrar dene.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _ensureSignedIn() {
    final auth = context.read<AuthController>();
    if (!auth.isGuest) return true;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Giriş gerekli'),
        content: const Text(
          'Boş park yeri bildirmek için Google veya Apple ile giriş yapmalısın.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              auth.signOut();
            },
            child: const Text('Giriş yap'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _goToCurrentLocation(LatLng position) async {
    setState(() => _selectedPosition = null);
    await _animateTo(position, zoom: 16.5);
  }

  Future<void> _animateTo(LatLng position, {double zoom = 16.5}) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoom),
      ),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _markerRefreshTimer?.cancel();
    _spotsSubscription?.cancel();
    super.dispose();
  }
}
