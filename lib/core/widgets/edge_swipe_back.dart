import 'package:flutter/material.dart';

class EdgeSwipeBack extends StatefulWidget {
  const EdgeSwipeBack({super.key, required this.child});

  final Widget child;

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  bool _startedFromEdge = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _startedFromEdge = details.globalPosition.dx < 36;
      },
      onHorizontalDragEnd: (details) {
        final canPop = Navigator.of(context).canPop();
        final velocity = details.primaryVelocity ?? 0;
        if (_startedFromEdge && canPop && velocity > 450) {
          Navigator.of(context).pop();
        }
        _startedFromEdge = false;
      },
      child: widget.child,
    );
  }
}
