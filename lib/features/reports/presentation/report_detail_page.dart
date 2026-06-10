import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/widgets/edge_swipe_back.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/entities/report.dart';
import 'report_controller.dart';

class ReportDetailPage extends StatelessWidget {
  const ReportDetailPage({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ReportController>();

    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(title: const Text('Bildirim Detayı')),
        body: StreamBuilder<ParkingReport>(
        stream: controller.watchReport(reportId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data!;
          final auth = context.watch<AuthController>();
          final currentUserId = auth.user?.id;
          final isOwner = currentUserId == report.userId;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImageGallery(urls: report.imageUrls),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: report.type.color.withValues(alpha: 0.15),
                    child: Icon(report.type.icon, color: report.type.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.type.label,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(DateFormat.yMMMMd('tr_TR').add_Hm().format(report.createdAt)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (report.address.isNotEmpty)
                _InfoCard(
                  title: 'Konum Bilgisi',
                  child: _LocationInfo(report: report),
                ),
              _InfoCard(
                title: 'Açıklama',
                child: Text(
                  report.description.isEmpty
                      ? 'Bu bildirim için açıklama eklenmemiş.'
                      : report.description,
                ),
              ),
              _InfoCard(
                title: 'Oluşturan',
                child: Text(report.userName),
              ),
              _InfoCard(
                title: 'Topluluk doğrulaması',
                child: Row(
                  children: [
                    Expanded(child: Text('${report.verifyCount} doğrulama')),
                    Expanded(child: Text('${report.falseReportCount} yanlış bilgi bildirimi')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (isOwner)
                _OwnerActions(reportId: report.id)
              else
                _ActionButtons(reportId: report.id),
            ],
          );
        },
        ),
      ),
    );
  }
}

class _LocationInfo extends StatelessWidget {
  const _LocationInfo({required this.report});

  final ParkingReport report;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openMap(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(report.address)),
            const SizedBox(width: 10),
            const Icon(Icons.map_outlined, color: AppColors.red),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context) async {
    context.read<AppShellController>().openMapAt(
          LatLng(report.latitude, report.longitude),
        );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class _ImageGallery extends StatefulWidget {
  const _ImageGallery({required this.urls});

  final List<String> urls;

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openPhotoPreview(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _ReportPhoto(source: urls[index]),
                ),
              );
            },
          ),
          if (urls.length > 1) ...[
            Positioned(
              top: 12,
              right: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${_index + 1} / ${urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: _GalleryArrow(
                icon: Icons.chevron_left,
                onTap: _index == 0 ? null : () => _goTo(_index - 1),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: _GalleryArrow(
                icon: Icons.chevron_right,
                onTap: _index >= urls.length - 1 ? null : () => _goTo(_index + 1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _openPhotoPreview(int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => _PhotoPreviewDialog(
        urls: widget.urls,
        initialIndex: initialIndex,
      ),
    );
  }
}

class _PhotoPreviewDialog extends StatefulWidget {
  const _PhotoPreviewDialog({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoPreviewDialog> createState() => _PhotoPreviewDialogState();
}

class _PhotoPreviewDialogState extends State<_PhotoPreviewDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: _ReportPhoto(
                    source: widget.urls[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          if (widget.urls.length > 1) ...[
            Positioned(
              top: 42,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: _GalleryArrow(
                icon: Icons.chevron_left,
                onTap: _index == 0 ? null : () => _goTo(_index - 1),
              ),
            ),
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: _GalleryArrow(
                icon: Icons.chevron_right,
                onTap: _index >= widget.urls.length - 1 ? null : () => _goTo(_index + 1),
              ),
            ),
          ],
          Positioned(
            top: 36,
            right: 12,
            child: IconButton.filled(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  const _GalleryArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black.withValues(alpha: onTap == null ? 0.18 : 0.48),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _ReportPhoto extends StatelessWidget {
  const _ReportPhoto({
    required this.source,
    this.fit = BoxFit.cover,
  });

  final String source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (_isInlineImage(source)) {
      return Image.memory(
        _decodeInlineImage(source),
        fit: fit,
        height: double.infinity,
        width: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }

    return CachedNetworkImage(
      imageUrl: source,
      fit: fit,
      height: double.infinity,
      width: double.infinity,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }
}

bool _isInlineImage(String source) => source.startsWith('data:image/');

Uint8List _decodeInlineImage(String source) {
  final commaIndex = source.indexOf(',');
  final payload = commaIndex == -1 ? source : source.substring(commaIndex + 1);
  return base64Decode(payload);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red.shade700,
        side: BorderSide(color: Colors.red.shade700),
      ),
      onPressed: () => _confirmDelete(context),
      icon: const Icon(Icons.delete_outline),
      label: const Text('Bildirimi sil'),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bildirimi sil'),
        content: const Text(
          'Bu bildirimi silmek istediğine emin misin? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final controller = context.read<ReportController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    navigator.pop();

    try {
      await controller.deleteReport(reportId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Bildirim silindi.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Bildirim silinemedi. Tekrar dene.')),
      );
    }
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final userId = auth.user?.id;
    final controller = context.read<ReportController>();
    if (userId == null) {
      return const SizedBox.shrink();
    }

    if (auth.isGuest) {
      return Row(
        children: [
          Expanded(
            child: _VoteButton(
              icon: Icons.verified,
              label: 'Doğru bilgi',
              isSelected: false,
              onPressed: () => _showGuestSignInDialog(context, auth),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _VoteButton(
              icon: Icons.report,
              label: 'Yanlış bilgi',
              isSelected: false,
              onPressed: () => _showGuestSignInDialog(context, auth),
            ),
          ),
        ],
      );
    }

    return StreamBuilder<bool>(
      stream: controller.watchUserVerification(reportId, userId),
      builder: (context, verifySnapshot) {
        final verified = verifySnapshot.data ?? false;
        return StreamBuilder<bool>(
          stream: controller.watchUserFalseReport(reportId, userId),
          builder: (context, falseSnapshot) {
            final markedFalse = falseSnapshot.data ?? false;
            return Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    icon: Icons.verified,
                    label: verified ? 'Doğrulamayı geri al' : 'Doğru bilgi',
                    isSelected: verified,
                    onPressed: () async {
                      await controller.verifyReport(reportId, userId);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VoteButton(
                    icon: Icons.report,
                    label: markedFalse ? 'Yanlışı geri al' : 'Yanlış bilgi',
                    isSelected: markedFalse,
                    onPressed: () async {
                      await controller.flagFalseReport(reportId, userId);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGuestSignInDialog(BuildContext context, AuthController auth) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Giriş yapman gerekiyor'),
        content: const Text(
          'Doğru veya yanlış bilgi bildirmek için Google veya Apple ile giriş yapman gerekiyor. İstersen gezmeye devam edebilir ya da giriş ekranına dönebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Gezmeye devam et'),
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
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? AppColors.red.withValues(alpha: 0.10) : null,
          foregroundColor: isSelected ? AppColors.red : AppColors.darkGrey,
          side: BorderSide(
            color: isSelected ? AppColors.red : AppColors.mediumGrey.withValues(alpha: 0.32),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
