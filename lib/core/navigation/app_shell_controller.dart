import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppShellController extends ChangeNotifier {
  int _selectedIndex = 0;
  LatLng? _mapFocusTarget;
  int _mapFocusRequestId = 0;

  int get selectedIndex => _selectedIndex;
  LatLng? get mapFocusTarget => _mapFocusTarget;
  int get mapFocusRequestId => _mapFocusRequestId;

  void selectTab(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void openMapAt(LatLng position) {
    _selectedIndex = 0;
    _mapFocusTarget = position;
    _mapFocusRequestId++;
    notifyListeners();
  }
}
