# ParkGozcu

ParkGozcu, suruculerin park cezasi, arac cekilmesi, park yasagi ve yogun denetim noktalarini harita uzerinde paylasabildigi Flutter tabanli bir MVP uygulamasidir.

## Kurulum

1. Flutter SDK'yi kurun ve PATH'e ekleyin.
2. Firebase projesi olusturun.
3. FlutterFire CLI ile platform dosyalarini guncelleyin:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Google Maps API anahtarlarini ekleyin:
   - Android: `android/app/src/main/res/values/strings.xml`
   - iOS: `ios/Runner/AppDelegate.swift`
5. Bagimliliklari alin ve calistirin:

```bash
flutter pub get
flutter run
```

## MVP Ozellikleri

- Google, Apple ve misafir girisi
- Google Maps ana ekran
- Mevcut konum ve rapor marker'lari
- Foto yuklemeli bildirim olusturma
- Bildirim detayi, dogrulama ve yanlis bilgi bildirimi
- Tip ve tarih filtreleri
- Kullanici profil metrikleri
- Firebase Authentication, Firestore, Storage ve Messaging entegrasyonu
