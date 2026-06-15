import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/reports/presentation/report_detail_page.dart';

class DeepLinkHandler extends StatefulWidget {
  const DeepLinkHandler({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_handleInitialLink());
    _linkSubscription = _appLinks.uriLinkStream.listen(_openReportFromUri);
  }

  Future<void> _handleInitialLink() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _openReportFromUri(initialUri);
    }
  }

  void _openReportFromUri(Uri uri) {
    if (uri.scheme != 'parkgozcu' || uri.host != 'report') return;

    final reportId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (reportId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ReportDetailPage(reportId: reportId),
        ),
      );
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
