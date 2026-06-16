import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/services/address_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reports/presentation/report_controller.dart';
import '../data/parking_spot_repository.dart';
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
  static const _parkTabIndex = 1;

  final _addressService = AddressService();
  GoogleMapController? _mapController;
  StreamSubscription<List<ParkingSpot>>? _spotsSubscription;
  List<ParkingSpot> _spots = const [];
  Set<Marker> _spotMarkers = {};
  LatLng? _selectedPosition;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _currentUserId;
  bool _iconsReady = false;
  int? _lastVisibleTabIndex;
  LatLng? _lastFocusedPosition;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseController.addListener(() {
      if (mounted && _spots.isNotEmpty) setState(() {});
    });
    unawaited(_preloadIcons());
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

  Future<void> _preloadIcons() async {
    await ParkingSpotMarkerIcon.preload();
    if (!mounted) return;
    setState(() => _iconsReady = true);
    await _rebuildSpotMarkers();
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AppShellController>();
    final reportController = context.watch<ReportController>();
    final currentPosition = reportController.currentPosition;

    if (shell.selectedIndex == _parkTabIndex && _lastVisibleTabIndex != _parkTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_focusCurrentLocation(currentPosition, force: true));
        unawaited(reportController.refreshCurrentLocation());
      });
    }
    _lastVisibleTabIndex = shell.selectedIndex;

    if (shell.selectedIndex == _parkTabIndex) {
      _moveCameraWhenLocationChanges(currentPosition);
    }

    final pulse = Curves.easeInOut.transform(_pulseController.value);
    final pulseCircles = _spots.map((spot) {
      return Circle(
        circleId: CircleId('pulse-${spot.id}'),
        center: LatLng(spot.latitude, spot.longitude),
        radius: 6 + (pulse * 10),
        fillColor: const Color(0xFF4CAF50).withValues(alpha: 0.12 + pulse * 0.14),
        strokeColor: const Color(0xFF2E7D32).withValues(alpha: 0.35 + pulse * 0.35),
        strokeWidth: 2,
        zIndex: 1,
      );
    }).toSet();

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
            onPressed: () => _focusCurrentLocation(currentPosition, force: true),
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
              zoom: 17,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              unawaited(_focusCurrentLocation(currentPosition, force: true));
            },
            onTap: _selectPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: markers,
            circles: pulseCircles,
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

  void _moveCameraWhenLocationChanges(LatLng currentPosition) {
    if (_lastFocusedPosition == null) {
      _lastFocusedPosition = currentPosition;
      return;
    }

    final deltaLat = (_lastFocusedPosition!.latitude - currentPosition.latitude).abs();
    final deltaLng = (_lastFocusedPosition!.longitude - currentPosition.longitude).abs();
    if (deltaLat < 0.00005 && deltaLng < 0.00005) return;

    _lastFocusedPosition = currentPosition;
    if (_selectedPosition == null) {
      unawaited(_animateTo(currentPosition, zoom: 17));
    }
  }

  void _selectPosition(LatLng position) {
    setState(() => _selectedPosition = position);
  }

  Future<void> _rebuildSpotMarkers() async {
    if (!_iconsReady) return;

    if (_spots.isEmpty) {
      if (_spotMarkers.isNotEmpty) {
        setState(() => _spotMarkers = {});
      }
      return;
    }

    final markers = _spots.map((spot) {
      final isOwnSpot = spot.userId == _currentUserId;
      return Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        icon: ParkingSpotMarkerIcon.icon(isOwnSpot: isOwnSpot),
        anchor: const Offset(0.5, 1.0),
        onTap: () => _onSpotTapped(spot, isOwnSpot),
        zIndexInt: isOwnSpot ? 80 : 40,
      );
    }).toSet();

    if (!mounted) return;
    setState(() => _spotMarkers = markers);
  }

  Future<void> _onSpotTapped(ParkingSpot spot, bool isOwnSpot) async {
    if (isOwnSpot) {
      await ParkingSpotDetailSheet.show(
        context,
        spot: spot,
        isOwnSpot: true,
      );
      return;
    }

    final opened = await openParkingSpotStreetView(
      latitude: spot.latitude,
      longitude: spot.longitude,
    );
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sokak Görünümü açılamadı. Google Maps yüklü olmalı.'),
      ),
    );
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

      await context.read<ParkingSpotController>().reportAvailableSpot(
            userId: user.id,
            userName: user.name,
            latitude: position.latitude,
            longitude: position.longitude,
            address: address,
          );

      if (!mounted) return;
      setState(() => _selectedPosition = null);
      await _animateTo(position, zoom: 17.5);
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

  Future<void> _focusCurrentLocation(LatLng position, {required bool force}) async {
    if (!force && _selectedPosition != null) return;
    _lastFocusedPosition = position;
    await _animateTo(position, zoom: 17);
  }

  Future<void> _animateTo(LatLng position, {double zoom = 17}) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoom, tilt: 0, bearing: 0),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spotsSubscription?.cancel();
    super.dispose();
  }
}
