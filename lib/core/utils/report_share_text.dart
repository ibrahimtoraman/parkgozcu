import '../../features/reports/domain/entities/report.dart';

class ReportShareText {
  static String build(ParkingReport report) {
    final mapsLink =
        'https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}';
    final appLink = 'parkgozcu://report/${report.id}';

    return '''
ParkGözcü Bildirimi
Tür: ${report.type.label}
Oluşturan: ${report.userName}
Konum: ${report.address.isEmpty ? 'Belirtilmemiş' : report.address}
Açıklama: ${report.description.isEmpty ? 'Yok' : report.description}

Haritada aç: $mapsLink
Uygulamada aç: $appLink
'''
        .trim();
  }
}
