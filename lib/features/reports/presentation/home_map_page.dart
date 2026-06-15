import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/services/address_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/entities/report.dart';
import 'create_report_page.dart';
import 'report_controller.dart';
import 'report_detail_page.dart';

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});

  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  static const _googleMapsApiKey = 'AIzaSyCg81cHh7wkLFHQUQizINpovwjP7PcQ2Kw';
  static const _maxVisibleMarkers = 180;

  final _addressService = AddressService();
  GoogleMapController? _mapController;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  Timer? _markerRebuildDebounce;
  StreamSubscription<List<ParkingReport>>? _reportsSubscription;
  final _reportIconCache = <String, BitmapDescriptor>{};
  List<ParkingReport> _allReports = const [];
  Set<Marker> _cachedReportMarkers = {};
  LatLngBounds? _visibleBounds;
  bool _markerIconsReady = false;
  bool _reportsLoading = true;
  String? _reportsError;
  String? _currentUserId;
  LatLng? _lastObservedCurrentPosition;
  LatLng? _selectedReportPosition;
  int _lastMapFocusRequestId = 0;
  bool _followCurrentLocation = true;
  List<_AddressSuggestion> _addressSuggestions = [];
  bool _isSearchingAddress = false;
  String? _addressSearchError;

  @override
  void initState() {
    super.initState();
    unawaited(_preloadMarkerIcons());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentUserId = context.read<AuthController>().user?.id;
    _reportsSubscription ??= context.read<ReportController>().reports.listen(
      _onReportsChanged,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _reportsError = error.toString();
          _reportsLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();
    final shell = context.watch<AppShellController>();
    _currentUserId = context.watch<AuthController>().user?.id;
    _moveCameraWhenLocationChanges(controller.currentPosition);
    _moveCameraForMapFocus(shell.mapFocusTarget, shell.mapFocusRequestId);

    final markers = {
      ..._cachedReportMarkers,
      if (_selectedReportPosition != null)
        Marker(
          markerId: const MarkerId('selected-report-position'),
          position: _selectedReportPosition!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Seçilen konum'),
          zIndexInt: 999,
        ),
      Marker(
        markerId: const MarkerId('current-location'),
        position: controller.currentPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Konumum'),
        onTap: () => _showCurrentAddress(controller.currentPosition),
        zIndexInt: 1000,
      ),
    };
    final circles = {
      Circle(
        circleId: const CircleId('current-location-radius'),
        center: controller.currentPosition,
        radius: 22,
        strokeWidth: 4,
        strokeColor: AppColors.red,
        fillColor: AppColors.red.withValues(alpha: 0.16),
      ),
    };

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: controller.currentPosition,
              zoom: 16,
            ),
            onMapCreated: (mapController) {
              _mapController = mapController;
              _animateTo(controller.currentPosition, zoom: 16);
              unawaited(_refreshVisibleBounds());
            },
            onCameraIdle: () => unawaited(_refreshVisibleBounds()),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: _selectReportLocation,
            markers: markers,
            circles: circles,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    isSearching: _isSearchingAddress,
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                  ),
                  if (_addressSuggestions.isNotEmpty ||
                      _addressSearchError != null)
                    _AddressResults(
                      suggestions: _addressSuggestions,
                      errorMessage: _addressSearchError,
                      onSelected: _selectSuggestion,
                    ),
                  const SizedBox(height: 10),
                  const _FilterBar(),
                ],
              ),
            ),
          ),
          if (_reportsLoading)
            const Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_reportsError != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 170,
              child: Material(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Bildirimler yüklenemedi. Firestore kurallarını kontrol et.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 112,
            child: FloatingActionButton.small(
              heroTag: 'go-to-current-location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.red,
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 72,
            right: 72,
            bottom: 24,
            child: SafeArea(
              child: FilledButton.icon(
                onPressed: _openCreateReportFromSelectedPosition,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Bildirim'),
                style: FilledButton.styleFrom(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onReportsChanged(List<ParkingReport> reports) {
    if (!mounted) return;
    setState(() {
      _allReports = reports;
      _reportsLoading = false;
      _reportsError = null;
    });
    _scheduleMarkerRebuild();
  }

  Future<void> _refreshVisibleBounds() async {
    final mapController = _mapController;
    if (mapController == null) return;
    final bounds = await mapController.getVisibleRegion();
    if (!mounted) return;
    _visibleBounds = bounds;
    _scheduleMarkerRebuild();
  }

  void _scheduleMarkerRebuild() {
    _markerRebuildDebounce?.cancel();
    _markerRebuildDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _rebuildReportMarkers();
    });
  }

  void _rebuildReportMarkers() {
    if (!_markerIconsReady) return;

    final center = context.read<ReportController>().currentPosition;
    final visibleReports = _filterReportsForMap(_allReports, center);
    final markers = visibleReports.map((report) {
      final isOwnReport = report.userId == _currentUserId;
      return Marker(
        markerId: MarkerId(report.id),
        position: LatLng(report.latitude, report.longitude),
        icon: _reportMarkerIcon(report, isOwnReport: isOwnReport),
        onTap: () => _openDetail(context, report.id),
        zIndexInt: isOwnReport ? 50 : 1,
      );
    }).toSet();

    setState(() => _cachedReportMarkers = markers);
  }

  List<ParkingReport> _filterReportsForMap(
    List<ParkingReport> reports,
    LatLng center,
  ) {
    Iterable<ParkingReport> visible = reports;
    if (_visibleBounds != null) {
      visible = visible.where(
        (report) => _visibleBounds!.contains(
          LatLng(report.latitude, report.longitude),
        ),
      );
    }

    final filtered = visible.toList();
    if (filtered.length <= _maxVisibleMarkers) {
      return filtered;
    }

    filtered.sort((a, b) {
      final distanceA = _distanceSquared(center, a);
      final distanceB = _distanceSquared(center, b);
      return distanceA.compareTo(distanceB);
    });
    return filtered.take(_maxVisibleMarkers).toList();
  }

  double _distanceSquared(LatLng center, ParkingReport report) {
    final deltaLat = center.latitude - report.latitude;
    final deltaLng = center.longitude - report.longitude;
    return (deltaLat * deltaLat) + (deltaLng * deltaLng);
  }

  Future<void> _preloadMarkerIcons() async {
    for (final type in ReportType.values) {
      for (final isOwn in [false, true]) {
        final key = '${isOwn ? 'own' : 'all'}-${type.name}';
        _reportIconCache[key] = await _buildReportMarkerIconForType(
          type,
          isOwnReport: isOwn,
        );
      }
    }

    if (!mounted) return;
    setState(() => _markerIconsReady = true);
    _scheduleMarkerRebuild();
  }

  void _openDetail(BuildContext context, String reportId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportDetailPage(reportId: reportId)),
    );
  }

  BitmapDescriptor _reportMarkerIcon(
    ParkingReport report, {
    required bool isOwnReport,
  }) {
    final key = '${isOwnReport ? 'own' : 'all'}-${report.type.name}';
    return _reportIconCache[key] ??
        BitmapDescriptor.defaultMarkerWithHue(
          isOwnReport ? BitmapDescriptor.hueViolet : report.type.markerHue,
        );
  }

  Future<BitmapDescriptor> _buildReportMarkerIconForType(
    ReportType type, {
    required bool isOwnReport,
  }) async {
    final color = isOwnReport ? Colors.deepPurple : type.color;
    final label = isOwnReport
        ? 'Benim ${_shortReportLabel(type)}'
        : _shortReportLabel(type);
    const pixelRatio = 3.0;
    const width = 112.0;
    const height = 52.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final bubbleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6, 3, width - 12, 24),
      const Radius.circular(9),
    );
    canvas.drawRRect(bubbleRect.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawRRect(bubbleRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 18);
    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, 9),
    );

    final pinPath = Path()
      ..moveTo(width / 2, height - 3)
      ..cubicTo(41, 38, 41, 26, width / 2, 26)
      ..cubicTo(71, 26, 71, 38, width / 2, height - 3)
      ..close();
    canvas.drawPath(pinPath.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawPath(pinPath, Paint()..color = color);
    canvas.drawCircle(
      const Offset(width / 2, 34),
      5,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * pixelRatio).toInt(),
      (height * pixelRatio).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  String _shortReportLabel(ReportType type) {
    return switch (type) {
      ReportType.parkingFine => 'Ceza',
      ReportType.towedVehicle => 'Araç Çekildi',
      ReportType.noParking => 'Park Yasağı',
      ReportType.heavyInspection => 'Denetim',
    };
  }

  Future<void> _goToCurrentLocation() async {
    final controller = context.read<ReportController>();
    await controller.refreshCurrentLocation();
    if (!mounted) return;
    _followCurrentLocation = true;
    await _animateTo(controller.currentPosition, zoom: 17);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final trimmedQuery = query.trim();

    if (trimmedQuery.length < 3) {
      setState(() {
        _addressSuggestions = [];
        _addressSearchError = null;
        _isSearchingAddress = false;
      });
      return;
    }

    setState(() {
      _isSearchingAddress = true;
      _addressSearchError = null;
    });

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchAddresses(trimmedQuery),
    );
  }

  Future<void> _searchAddresses(String query) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': query,
        'components': 'country:TR',
        'language': 'tr',
        'key': _googleMapsApiKey,
      },
    );

    try {
      final response = await http.get(uri);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String? ?? 'UNKNOWN';

      if (status != 'OK' && status != 'ZERO_RESULTS') {
        throw Exception(status);
      }

      final results = body['results'] as List<dynamic>? ?? const [];
      final googleSuggestions = results.take(6).map((item) {
        final data = item as Map<String, dynamic>;
        final location = data['geometry']['location'] as Map<String, dynamic>;
        return _AddressSuggestion(
          title: data['formatted_address'] as String? ?? 'Adres',
          position: LatLng(
            (location['lat'] as num).toDouble(),
            (location['lng'] as num).toDouble(),
          ),
        );
      }).toList();
      final suggestions = googleSuggestions.isEmpty
          ? await _searchAddressesWithOpenStreetMap(query)
          : googleSuggestions;

      if (!mounted) return;
      setState(() {
        _addressSuggestions = suggestions;
        _addressSearchError = suggestions.isEmpty ? 'Adres bulunamadı.' : null;
        _isSearchingAddress = false;
      });
    } catch (_) {
      final suggestions = await _searchAddressesWithOpenStreetMap(query);
      if (!mounted) return;
      setState(() {
        _addressSuggestions = suggestions;
        _addressSearchError =
            suggestions.isEmpty ? 'Adres araması şu anda yapılamıyor.' : null;
        _isSearchingAddress = false;
      });
    }
  }

  Future<List<_AddressSuggestion>> _searchAddressesWithOpenStreetMap(
    String query,
  ) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': '$query, Türkiye',
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '6',
          'accept-language': 'tr',
        },
      );

      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'ParkGozcu/0.1.0'},
      );
      final results = jsonDecode(response.body) as List<dynamic>;
      return results.map((item) {
        final data = item as Map<String, dynamic>;
        return _AddressSuggestion(
          title: data['display_name'] as String? ?? 'Adres',
          position: LatLng(
            double.parse(data['lat'] as String),
            double.parse(data['lon'] as String),
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _showCurrentAddress(LatLng position) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Anlık adres alınıyor...')),
    );

    final address = await _addressService.reverseAddress(position);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anlık adresim',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Text(address),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _selectReportLocation(position, knownAddress: address);
              },
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Bu konumu bildir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectSuggestion(_AddressSuggestion suggestion) async {
    if (!_ensureSignedInForReport()) return;
    _searchController.text = suggestion.title;
    _searchFocusNode.unfocus();
    setState(() {
      _addressSuggestions = [];
      _addressSearchError = null;
      _selectedReportPosition = suggestion.position;
      _followCurrentLocation = false;
    });
    await _animateTo(suggestion.position, zoom: 17);
    if (!mounted) return;
    await _askReportTypeForPosition(
      suggestion.position,
      knownAddress: suggestion.title,
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _addressSuggestions = [];
      _addressSearchError = null;
      _isSearchingAddress = false;
    });
  }

  void _clearSelectedReportPosition() {
    setState(() {
      _selectedReportPosition = null;
      _followCurrentLocation = true;
    });
  }

  void _moveCameraWhenLocationChanges(LatLng position) {
    if (!_followCurrentLocation || _lastObservedCurrentPosition == position) {
      return;
    }
    _lastObservedCurrentPosition = position;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animateTo(position, zoom: 16);
    });
  }

  void _moveCameraForMapFocus(LatLng? position, int requestId) {
    if (position == null || requestId == _lastMapFocusRequestId) return;
    _lastMapFocusRequestId = requestId;
    _followCurrentLocation = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _animateTo(position, zoom: 18);
    });
  }

  Future<void> _animateTo(LatLng position, {required double zoom}) async {
    final mapController = _mapController;
    if (mapController == null) return;
    await mapController.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: zoom)),
    );
  }

  Future<void> _selectReportLocation(
    LatLng position, {
    String? knownAddress,
  }) async {
    if (!_ensureSignedInForReport()) return;
    setState(() {
      _selectedReportPosition = position;
      _followCurrentLocation = false;
      _addressSuggestions = [];
      _addressSearchError = null;
    });
    _searchFocusNode.unfocus();
    await _animateTo(position, zoom: 17);
    if (!mounted) return;
    await _askReportTypeForPosition(position, knownAddress: knownAddress);
  }

  Future<void> _askReportTypeForPosition(
    LatLng position, {
    String? knownAddress,
  }) async {
    final address =
        knownAddress ?? await _addressService.reverseAddress(position);
    if (!mounted) return;

    final type = await showModalBottomSheet<ReportType>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ne bildiriyorsun?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  address,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              _ReportTypeTile(
                icon: Icons.receipt_long,
                title: 'Park Cezası',
                onTap: () => Navigator.of(context).pop(ReportType.parkingFine),
              ),
              _ReportTypeTile(
                icon: Icons.local_shipping,
                title: 'Aracım Çekildi',
                onTap: () => Navigator.of(context).pop(ReportType.towedVehicle),
              ),
              _ReportTypeTile(
                icon: Icons.block,
                title: 'Park Yasağı',
                onTap: () => Navigator.of(context).pop(ReportType.noParking),
              ),
            ],
          ),
        ),
      ),
    );

    if (type == null || !mounted) {
      _clearSelectedReportPosition();
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateReportPage(
          initialPosition: position,
          initialType: type,
          initialAddress: address,
        ),
      ),
    );
    if (created == true && mounted) {
      _clearSelectedReportPosition();
    }
  }

  Future<void> _openCreateReportFromSelectedPosition() async {
    if (!_ensureSignedInForReport()) return;
    final position = _selectedReportPosition ??
        context.read<ReportController>().currentPosition;
    final address = await _addressService.reverseAddress(position);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateReportPage(
          initialPosition: position,
          initialAddress: address,
        ),
      ),
    );
  }

  bool _ensureSignedInForReport() {
    final auth = context.read<AuthController>();
    if (!auth.isGuest) return true;
    _showGuestSignInDialog(auth);
    return false;
  }

  void _showGuestSignInDialog(AuthController auth) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Giriş gerekli')),
            IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Kapat',
            ),
          ],
        ),
        content: const Text(
          'Bildirim oluşturmak için Google veya Apple ile giriş yapmanız gerekiyor. Giriş ekranına dönmek ister misin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Gezmeye devam et'),
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
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _markerRebuildDebounce?.cancel();
    _reportsSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.mediumGrey),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Adres ara...',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (isSearching)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (controller.text.isNotEmpty)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close),
                tooltip: 'Aramayı temizle',
              ),
          ],
        ),
      ),
    );
  }
}

class _AddressResults extends StatelessWidget {
  const _AddressResults({
    required this.suggestions,
    required this.errorMessage,
    required this.onSelected,
  });

  final List<_AddressSuggestion> suggestions;
  final String? errorMessage;
  final ValueChanged<_AddressSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(errorMessage!),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    leading:
                        const Icon(Icons.place_outlined, color: AppColors.red),
                    title: Text(suggestion.title),
                    onTap: () => onSelected(suggestion),
                  );
                },
              ),
      ),
    );
  }
}

class _ReportTypeTile extends StatelessWidget {
  const _ReportTypeTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.red.withValues(alpha: 0.14),
          child: Icon(icon, color: AppColors.red),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _AddressSuggestion {
  const _AddressSuggestion({
    required this.title,
    required this.position,
  });

  final String title;
  final LatLng position;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'Tüm bildirimler',
            selected: controller.filters.type == null,
            onSelected: () => controller.setTypeFilter(null),
          ),
          _Chip(
            label: 'Sadece Park Cezaları',
            selected: controller.filters.type == ReportType.parkingFine,
            onSelected: () => controller.setTypeFilter(ReportType.parkingFine),
          ),
          _Chip(
            label: 'Sadece Araç Çekilmeleri',
            selected: controller.filters.type == ReportType.towedVehicle,
            onSelected: () => controller.setTypeFilter(ReportType.towedVehicle),
          ),
          _Chip(
            label: 'Son 7 Gün',
            selected: controller.filters.days == 7,
            onSelected: () => controller
                .setDayFilter(controller.filters.days == 7 ? null : 7),
          ),
          _Chip(
            label: 'Son 30 Gün',
            selected: controller.filters.days == 30,
            onSelected: () => controller
                .setDayFilter(controller.filters.days == 30 ? null : 30),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.red.withValues(alpha: 0.15),
        checkmarkColor: AppColors.red,
        backgroundColor: Colors.white,
      ),
    );
  }
}
