# Kontribusi

Gunakan Flutter 3.24.5, lalu jalankan `flutter pub get`. Simpan `pubspec.lock` untuk menjaga resolusi dependensi aplikasi.

## Konvensi

- Gunakan model bertipe untuk hasil service yang dikonsumsi UI. Batasi JSON dinamis pada adapter/codec.
- Simpan aturan data di model rules, bukan hanya validator formulir.
- Ubah data melalui metode `FarmStore`; jangan mutasi koleksi publik atau menambah singleton baru.
- Gunakan operasi parsial untuk edit identitas dan catatan bobot agar data lama di layar tidak menimpa state terbaru.
- Pisahkan transport HTTP, pemetaan respons, persistensi, dan presentasi. Pertahankan widget bersama pada tanggung jawab tampilannya.
- Tambahkan tes untuk perilaku atau regresi yang berubah. Mock jaringan dan storage; jangan mengandalkan endpoint pengembangan dalam tes.
- Jangan commit token, file signing, data peternakan, foto pribadi, atau hasil build.

## Sebelum pull request

```sh
dart format lib test
flutter analyze --no-fatal-infos
flutter test --coverage
flutter build web --release
```

Jelaskan masalah, perilaku sesudah perubahan, serta pemeriksaan yang benar-benar dijalankan. Untuk perubahan UI, periksa juga di perangkat/ukuran layar sasaran. Untuk perubahan schema atau identifier penyimpanan, sertakan strategi migrasi dan tes kompatibilitas.
