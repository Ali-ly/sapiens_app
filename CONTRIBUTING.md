# Kontribusi

Gunakan Flutter 3.24.5, lalu jalankan `flutter pub get`. Simpan `pubspec.lock` untuk menjaga resolusi dependensi aplikasi.

## Konvensi

- Gunakan model bertipe untuk hasil service yang dikonsumsi UI. Batasi JSON dinamis pada adapter/codec.
- Simpan aturan data di model rules, bukan hanya validator formulir.
- Kelompok adalah data bulk mandiri. Gunakan histori `GroupRecord` dan mutasi `FarmStore`; jangan menurunkan jumlah/bobot kelompok dari profil individual. `LegacyGroupMembership` hanya untuk kompatibilitas cadangan lama.
- Dalam `testWidgets`, buat dan muat store di body tes agar Future antrean memakai zona/jam tes yang sama. Cari scrollable vertikal secara eksplisit pada halaman dengan input teks.
- Ubah data melalui metode `FarmStore`; jangan mutasi koleksi publik atau menambah singleton baru.
- Gunakan operasi parsial untuk edit identitas dan catatan bobot agar data lama di layar tidak menimpa state terbaru.
- Pecah bagian halaman yang punya tanggung jawab sendiri menjadi widget bertipe di `screens/<fitur>/widgets/`. Kirim data dan callback secara eksplisit; widget tampilan tidak menulis ke storage.
- Pisahkan transport HTTP, pemetaan respons, persistensi, dan presentasi. Pertahankan widget bersama pada tanggung jawab tampilannya.
- Tambahkan tes untuk perilaku atau regresi yang berubah. Mock jaringan dan storage; jangan mengandalkan endpoint pengembangan dalam tes.
- Jangan commit token, file signing, data peternakan, foto pribadi, atau hasil build.

## Sebelum pull request

```sh
dart format lib test
flutter analyze
flutter test --coverage
flutter test --platform chrome test/app_flow_test.dart test/command_center_test.dart test/groups_ui_test.dart test/photo_preview_test.dart
flutter build web --release
```

Jelaskan masalah, perilaku sesudah perubahan, serta pemeriksaan yang benar-benar dijalankan. Untuk perubahan UI, periksa juga di perangkat/ukuran layar sasaran. Untuk perubahan schema atau identifier penyimpanan, sertakan strategi migrasi dan tes kompatibilitas.

## Organisasi tes

- `app_flow_test.dart`: startup, penyimpanan, dan alur tambah/cari/catat sapi.
- `cattle_editing_test.dart`: edit identitas, perlindungan stale form, cleanup data lama, dan formulir belum tersimpan.
- `state_integrity_test.dart`: immutability, antrean tulis, hasil tertinggal, pemulihan, dan lifecycle store.
- `groups_store_test.dart` / `groups_ui_test.dart`: kelompok mandiri serta hierarchy individual sebagai alur utama.
- `command_center_test.dart`, `feed_test.dart`, `feed_flow_test.dart`, dan `photo_preview_test.dart`: proyeksi operasional, kontrak pakan, navigasi, serta decoder foto VM/browser.

Jangan menambahkan aturan ignore lint global untuk membuat CI lulus. Adapter `storage_web.dart` memiliki pengecualian import yang spesifik karena hanya dipilih melalui conditional export pada browser.
