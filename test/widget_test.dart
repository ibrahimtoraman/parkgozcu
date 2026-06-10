import 'package:flutter_test/flutter_test.dart';
import 'package:parkgozcu/features/reports/domain/entities/report.dart';

void main() {
  test('report type labels are localized for the MVP', () {
    expect(ReportType.parkingFine.label, 'Park Cezası');
    expect(ReportType.towedVehicle.label, 'Araç Çekildi');
    expect(ReportType.noParking.label, 'Park Yasağı');
    expect(ReportType.heavyInspection.label, 'Yoğun Denetim');
  });
}
