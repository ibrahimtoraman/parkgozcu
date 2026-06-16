import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/app_shell_controller.dart';
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

class _ParkAreaPageState extends State<ParkAreaPage> {
  static const _parkTabIndex = 1;
  static const _maxVisibleSpots = 50;

  final _addressService = AddressService();
  GoogleMapController? _mapController;
  StreamSubscription<List<ParkingSpot>>? _spotsSubscription;
  Timer? _clockTimer;
  Timer? _bounceTimer;
  List<ParkingSpot> _spots = const [];
  Set<Marker> _spotMarkers = {};
  LatLngBounds? _visibleBounds;
  LatLng? _selectedPosition;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _currentUserId;
  bool _iconsReady = false;
  int? _lastVisibleTabIndex;
  LatLng? _lastFocusedPosition;
  int _bounceFrame = 0;
  int _clockTick = 0;
  double _mapZoom = 17;
  Timer? _zoomRebuildDebounce;
  Timer? _markerRebuildDebounce;

  @override
  void initState() {
    super.initState();
    _bounceTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted || !_iconsReady || _visibleSpots().isEmpty) return;
      setState(() {
        _bounceFrame = (_bounceFrame + 1) % ParkingSpotMarkerIcon.frameCount;
      });
      _scheduleMarkerRebuild();
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _spots.isEmpty) return;
      setState(() => _clockTick++);
    });
    unawaited(_preloadIcons());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentUserId = context.watch<AuthController>().user?.id;
    _spotsSubscription ??=
        context.read<ParkingSpotController>().spots.listen((spots) {
      if (!mounted) return;
      setState(() => _spots = spots);
      _scheduleMarkerRebuild();
    });
  }

  Future<void> _preloadIcons() async {
    await ParkingSpotMarkerIcon.preload(zoom: _mapZoom);
    if (!mounted) return;
    setState(() => _iconsReady = true);
    await _rebuildSpotMarkers();
  }

  void _onCameraMove(CameraPosition position) {
    final nextZoom = position.zoom;
    if ((nextZoom - _mapZoom).abs() < 0.08) return;
    _mapZoom = nextZoom;
    _zoomRebuildDebounce?.cancel();
    _zoomRebuildDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_iconsReady) return;
      _scheduleMarkerRebuild(forceIconRebuild: true);
    });
  }

  void _scheduleMarkerRebuild({bool forceIconRebuild = false}) {
    _markerRebuildDebounce?.cancel();
    _markerRebuildDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || !_iconsReady) return;
      unawaited(_rebuildSpotMarkers(forceIconRebuild: forceIconRebuild));
    });
  }

  Future<void> _refreshVisibleBounds() async {
    final controller = _mapController;
    if (controller == null) return;
    final bounds = await controller.getVisibleRegion();
    if (!mounted) return;
    _visibleBounds = bounds;
    _scheduleMarkerRebuild();
  }

  List<ParkingSpot> _visibleSpots() {
    if (_visibleBounds == null) {
      return const [];
    }

    final filtered = _spots
        .where(
          (spot) => _visibleBounds!.contains(
            LatLng(spot.latitude, spot.longitude),
          ),
        )
        .toList();

    if (filtered.length <= _maxVisibleSpots) {
      return filtered;
    }

    final center = _lastFocusedPosition;
    if (center != null) {
      filtered.sort((a, b) {
        final distanceA = _distanceSquared(center, a);
        final distanceB = _distanceSquared(center, b);
        return distanceA.compareTo(distanceB);
      });
    }

    return filtered.take(_maxVisibleSpots).toList();
  }

  double _distanceSquared(LatLng center, ParkingSpot spot) {
    final deltaLat = center.latitude - spot.latitude;
    final deltaLng = center.longitude - spot.longitude;
    return (deltaLat * deltaLat) + (deltaLng * deltaLng);
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AppShellController>();
    final reportController = context.watch<ReportController>();
    final currentPosition = reportController.currentPosition;
    final _ = _clockTick;

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

    final visibleSpots = _visibleSpots();

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
              unawaited(_refreshVisibleBounds());
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: () => unawaited(_refreshVisibleBounds()),
            onTap: _selectPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: markers,
            padding: EdgeInsets.only(
              bottom: visibleSpots.isEmpty ? 120 : 210,
              top: 72,
            ),
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
                      Icon(Icons.timer_outlined, color: Color(0xFF16A34A)),
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
          if (visibleSpots.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 96,
              child: _ActiveSpotsStrip(
                spots: visibleSpots,
                currentUserId: _currentUserId,
                onSpotTap: _openSpotDetail,
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: visibleSpots.isEmpty ? 120 : 210,
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
                      backgroundColor: const Color(0xFF16A34A),
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

  Future<void> _rebuildSpotMarkers({bool forceIconRebuild = false}) async {
    if (!_iconsReady) return;

    final visibleSpots = _visibleSpots();
    if (visibleSpots.isEmpty) {
      if (_spotMarkers.isNotEmpty) {
        setState(() => _spotMarkers = {});
      }
      return;
    }

    if (forceIconRebuild || _spotMarkers.isEmpty) {
      await ParkingSpotMarkerIcon.ensureFrames(zoom: _mapZoom);
    }

    final markers = visibleSpots.map((spot) {
      return Marker(
        markerId: MarkerId(spot.id),
        position: LatLng(spot.latitude, spot.longitude),
        icon: ParkingSpotMarkerIcon.frame(frameIndex: _bounceFrame),
        anchor: ParkingSpotMarkerIcon.anchorForZoom(_mapZoom),
        onTap: () => _openSpotDetail(spot),
        infoWindow: InfoWindow(
          title: spot.remainingLabel,
          snippet: 'Bitiş: ${spot.expiresAtLabel('tr_TR')}',
        ),
        zIndexInt: spot.userId == _currentUserId ? 80 : 40,
      );
    }).toSet();

    if (!mounted) return;
    setState(() => _spotMarkers = markers);
  }

  Future<void> _openSpotDetail(ParkingSpot spot) async {
    final currentUserId = context.read<AuthController>().user?.id;
    final isOwnSpot =
        currentUserId != null && spot.userId.trim() == currentUserId.trim();
    await ParkingSpotDetailSheet.show(
      context,
      spot: spot,
      isOwnSpot: isOwnSpot,
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
    await _refreshVisibleBounds();
  }

  @override
  void dispose() {
    _bounceTimer?.cancel();
    _clockTimer?.cancel();
    _zoomRebuildDebounce?.cancel();
    _markerRebuildDebounce?.cancel();
    _spotsSubscription?.cancel();
    super.dispose();
  }
}

class _ActiveSpotsStrip extends StatelessWidget {
  const _ActiveSpotsStrip({
    required this.spots,
    required this.currentUserId,
    required this.onSpotTap,
  });

  final List<ParkingSpot> spots;
  final String? currentUserId;
  final ValueChanged<ParkingSpot> onSpotTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: spots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final spot = spots[index];
          final viewerId = currentUserId;
          final isOwn =
              viewerId != null && spot.userId.trim() == viewerId.trim();
          return Material(
            color: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSpotTap(spot),
              child: Container(
                width: 168,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_parking,
                          size: 18,
                          color: isOwn ? const Color(0xFF15803D) : const Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isOwn ? 'Senin bildirimin' : 'Boş park',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      spot.remainingLabel,
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Bitiş: ${spot.expiresAtLabel('tr_TR')}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
