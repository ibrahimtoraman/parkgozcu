import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/address_service.dart';
import '../../../core/widgets/edge_swipe_back.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/entities/report.dart';
import 'report_controller.dart';

class CreateReportPage extends StatefulWidget {
  const CreateReportPage({
    super.key,
    this.initialPosition,
    this.initialType,
    this.initialAddress,
  });

  final LatLng? initialPosition;
  final ReportType? initialType;
  final String? initialAddress;

  @override
  State<CreateReportPage> createState() => _CreateReportPageState();
}

class _CreateReportPageState extends State<CreateReportPage> {
  static const _maxImageCount = 4;

  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressService = AddressService();
  final _picker = ImagePicker();
  final _images = <File>[];
  final _reportIconCache = <String, BitmapDescriptor>{};
  final _loadingReportIconKeys = <String>{};
  ReportType _type = ReportType.parkingFine;
  late LatLng _selectedPosition;
  bool _isResolvingAddress = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? ReportType.parkingFine;
    _selectedPosition =
        widget.initialPosition ?? context.read<ReportController>().currentPosition;
    _addressController.text = widget.initialAddress ?? '';
    if (_addressController.text.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSelectedPosition(_selectedPosition);
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportController = context.watch<ReportController>();
    final currentUserId = context.watch<AuthController>().user?.id;
    final currentPosition = reportController.currentPosition;

    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(title: const Text('Bildirim Oluştur')),
        body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            _ReportTypeSelector(
              selectedType: _type,
              onChanged: (type) => setState(() => _type = type),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: AppColors.red, size: 15),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Konumu haritada dokunarak adres değiştirebilirsiniz.',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 270,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.38),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: StreamBuilder<List<ParkingReport>>(
                  stream: reportController.reports,
                  builder: (context, snapshot) {
                    final existingReportMarkers = (snapshot.data ?? const <ParkingReport>[])
                        .where((report) => report.id.isNotEmpty)
                        .map(
                              (report) {
                                final isOwnReport = report.userId == currentUserId;
                                final position = LatLng(report.latitude, report.longitude);
                                return Marker(
                                  markerId: MarkerId('existing-${report.id}'),
                                  position: position,
                                  icon: _reportMarkerIcon(
                                    report,
                                    isOwnReport: isOwnReport,
                                  ),
                                  onTap: () => _updateSelectedPosition(
                                    position,
                                    knownAddress: report.address,
                                  ),
                                  zIndexInt: isOwnReport ? 20 : 1,
                                );
                              },
                            );

                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedPosition,
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                      markers: {
                        ...existingReportMarkers,
                        Marker(
                          markerId: const MarkerId('current-location'),
                          position: currentPosition,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                          infoWindow: const InfoWindow(title: 'Konumum'),
                          onTap: () => _updateSelectedPosition(currentPosition),
                          zIndexInt: 1000,
                        ),
                        Marker(
                          markerId: const MarkerId('selected-report-location'),
                          position: _selectedPosition,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueOrange,
                          ),
                          draggable: true,
                          onDragEnd: _updateSelectedPosition,
                          infoWindow: const InfoWindow(title: 'Seçilen konum'),
                          zIndexInt: 999,
                        ),
                      },
                      circles: {
                        Circle(
                          circleId: const CircleId('current-location-radius'),
                          center: currentPosition,
                          radius: 22,
                          strokeWidth: 4,
                          strokeColor: AppColors.red,
                          fillColor: AppColors.red.withValues(alpha: 0.16),
                        ),
                      },
                      onTap: _updateSelectedPosition,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.red.withValues(alpha: 0.35),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: AppColors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Seçilen adres',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.red,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      if (_isResolvingAddress)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _resolveAddress(_selectedPosition),
                          icon: const Icon(Icons.my_location),
                          tooltip: 'Adresi yenile',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Adres bilgisini buradan düzeltebilirsin.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                hintText: 'Örnek: Park yasak tabelası yoktu, aracım çekildi.',
              ),
            ),
            const SizedBox(height: 14),
            _ImagePickerRow(
              images: _images,
              onAdd: _showImageSourceSheet,
              onRemove: _removeImage,
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: reportController.isSubmitting ? null : _submit,
              icon: reportController.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload),
              label: const Text('Bildirim yayınla'),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _showImageSourceSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_images.length >= _maxImageCount) {
      _showMessage('En fazla $_maxImageCount fotoğraf ekleyebilirsin.');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppColors.red),
                title: const Text('Kamera ile çek'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.red),
                title: const Text('Galeriden seç'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) {
      await _pickImages(source);
    }
  }

  Future<void> _pickImages(ImageSource source) async {
    final remainingSlots = _maxImageCount - _images.length;
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(
        imageQuality: 45,
        maxWidth: 720,
      );
      if (picked.isEmpty) return;
      setState(() {
        _images.addAll(
          picked.take(remainingSlots).map((image) => File(image.path)),
        );
      });
      if (picked.length > remainingSlots) {
        _showMessage('En fazla $_maxImageCount fotoğraf ekleyebilirsin.');
      }
      return;
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 45,
      maxWidth: 720,
    );
    if (picked == null) return;
    setState(() => _images.add(File(picked.path)));
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  BitmapDescriptor _reportMarkerIcon(
    ParkingReport report, {
    required bool isOwnReport,
  }) {
    final key = '${isOwnReport ? 'own' : 'all'}-${report.type.name}';
    final cachedIcon = _reportIconCache[key];
    if (cachedIcon != null) return cachedIcon;

    if (!_loadingReportIconKeys.contains(key)) {
      _loadingReportIconKeys.add(key);
      unawaited(_buildReportMarkerIcon(
        report.type,
        isOwnReport: isOwnReport,
      ).then((icon) {
        if (!mounted) return;
        setState(() {
          _reportIconCache[key] = icon;
          _loadingReportIconKeys.remove(key);
        });
      }));
    }

    return BitmapDescriptor.defaultMarkerWithHue(report.type.markerHue);
  }

  Future<BitmapDescriptor> _buildReportMarkerIcon(
    ReportType type, {
    required bool isOwnReport,
  }) async {
    final color = isOwnReport ? Colors.deepPurple : type.color;
    final label = isOwnReport ? 'Benim ${_shortReportLabel(type)}' : _shortReportLabel(type);
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

  Future<void> _updateSelectedPosition(
    LatLng position, {
    String? knownAddress,
  }) async {
    setState(() => _selectedPosition = position);
    if (knownAddress != null && knownAddress.trim().isNotEmpty) {
      setState(() => _addressController.text = knownAddress.trim());
      return;
    }
    await _resolveAddress(position);
  }

  Future<void> _resolveAddress(LatLng position) async {
    setState(() => _isResolvingAddress = true);
    final address = await _addressService.reverseAddress(position);
    if (!mounted) return;
    setState(() {
      _addressController.text = address;
      _isResolvingAddress = false;
    });
  }

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showMessage('Açıklama yazmadan bildirim yayınlayamazsın.');
      return;
    }

    if (_images.isEmpty) {
      _showMessage('En az 1 fotoğraf yüklemelisin.');
      return;
    }

    final auth = context.read<AuthController>();
    final user = auth.user;
    if (user == null) return;
    if (auth.isGuest) {
      _showGuestSignInDialog(auth);
      return;
    }

    try {
      final messenger = ScaffoldMessenger.of(context);
      await context.read<ReportController>().createReport(
            userId: user.id,
            userName: user.name,
            type: _type,
            address: _addressController.text.trim(),
            description: _descriptionController.text.trim(),
            position: _selectedPosition,
            images: _images,
          );
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      await _showPublishedDialog();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      final message = context.read<ReportController>().errorMessage;
      _showMessage(message ?? 'Bildirim oluşturulamadı. Lütfen tekrar dene.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
              auth.signOut();
            },
            child: const Text('Giriş yap'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPublishedDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Bildirim yayınlandı'),
        content: const Text('Paylaşımın haritada toplulukla paylaşılmaya hazır.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

class _ReportTypeSelector extends StatelessWidget {
  const _ReportTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  final ReportType selectedType;
  final ValueChanged<ReportType> onChanged;

  static const _types = [
    ReportType.parkingFine,
    ReportType.towedVehicle,
    ReportType.noParking,
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olay tipi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ..._types.map((type) {
              final isSelected = selectedType == type;
              final label = type == ReportType.towedVehicle
                  ? 'Aracım Çekildi'
                  : type.label;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.red.withValues(alpha: 0.12)
                          : AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.red : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              isSelected ? AppColors.red : Colors.white,
                          child: Icon(
                            type.icon,
                            size: 19,
                            color: isSelected ? Colors.white : AppColors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected ? AppColors.red : AppColors.mediumGrey,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<File> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Fotoğraflar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Ekle'),
            ),
          ],
        ),
        if (images.isEmpty)
          Container(
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.2)),
            ),
            child: const Text('En az 1 fotoğraf gerekli'),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openPreview(context, images[index]),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              images[index],
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap: () => onRemove(index),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _openPreview(BuildContext context, File image) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.file(
                image,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
