import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class AddressService {
  static const _googleMapsApiKey = 'AIzaSyCg81cHh7wkLFHQUQizINpovwjP7PcQ2Kw';

  Future<String> reverseAddress(LatLng position) async {
    try {
      final googleUri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '${position.latitude},${position.longitude}',
          'language': 'tr',
          'key': _googleMapsApiKey,
        },
      );
      final response = await http.get(googleUri);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>? ?? const [];
      if (results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        return first['formatted_address'] as String? ?? _fallback(position);
      }
    } catch (_) {
      // OpenStreetMap fallback below handles temporary Google/API issues.
    }

    try {
      final osmUri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': position.latitude.toString(),
          'lon': position.longitude.toString(),
          'format': 'jsonv2',
          'accept-language': 'tr',
        },
      );
      final response = await http.get(
        osmUri,
        headers: const {'User-Agent': 'ParkGozcu/0.1.0'},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['display_name'] as String? ?? _fallback(position);
    } catch (_) {
      return _fallback(position);
    }
  }

  String _fallback(LatLng position) {
    return 'Adres bulunamadı. Konum: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }
}
