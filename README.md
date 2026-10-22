# SAPITA

Aplikasi Flutter untuk mencatat bobot sapi dan merencanakan kebutuhan pakan. Alur utamanya adalah **daftar sapi → catat atau estimasi bobot → hitung pakan → simpan dan pantau rencana**.

## Fitur MVP

- Profil sapi, pencarian, filter, edit identitas, dan riwayat bobot dengan grafik.
- Input bobot manual atau estimasi melalui API dari 1–4 foto.
- Rekomendasi pakan melalui API berdasarkan bobot, target, dan bahan yang tersedia.
- Riwayat rencana, penanda rencana yang perlu diperbarui, dan rekap bahan per kandang.
- Identitas peternakan, interval pengecekan, serta ekspor dan pemulihan cadangan JSON.
- Data contoh untuk menjelajahi aplikasi tanpa membuat profil sapi terlebih dahulu.

## Menjalankan

Versi acuan pengembangan dan CI: **Flutter 3.24.5 / Dart 3.5.4**.

```sh
flutter pub get
flutter run
```

Nama package Dart adalah `sapita_app`. Jalankan `flutter pub get` setelah menarik perubahan agar konfigurasi package lokal diperbarui.

Untuk web, gunakan port tetap supaya penyimpanan browser tetap menggunakan origin yang sama:

```sh
flutter run -d chrome --web-port 8080
```

### Konfigurasi backend

Alamat API diatur melalui `API_BASE_URL`. Nilai bawaan di `lib/core/constants/api_constants.dart` mengikuti gateway pengembangan proyek dan dapat berubah atau tidak tersedia.

```sh
flutter run --dart-define=API_BASE_URL=https://backend.example.com
flutter build web --release --dart-define=API_BASE_URL=https://backend.example.com
```

Backend harus menyediakan `POST /predict-weight` dan `POST /calculate-feed`. Untuk web, backend juga harus mengizinkan CORS dari origin aplikasi. Lihat [kontrak API dan arsitektur](docs/architecture.md).

Umur, jenis kelamin, dan kondisi tubuh disimpan sebagai konteks rencana. API pakan saat ini hanya menerima bobot, target, dan bahan tersedia; aplikasi tidak mengklaim konteks lain ikut menentukan perhitungan. Saat API gagal, aplikasi menampilkan error dan tidak membuat rekomendasi pengganti.

## Data lokal

Browser memakai localStorage; platform native memakai file JSON. Foto ikut disimpan. Penulisan berlangsung berurutan, dan tampilan menerima state baru setelah penyimpanan berhasil. Nama lokasi penyimpanan lama dipertahankan agar pembaruan brand/package tidak memutus akses data pengguna.

Cadangan tersedia pada **Profil → Cadangan data**. Impor memvalidasi seluruh data dan menampilkan konfirmasi sebelum mengganti data perangkat. Cadangan versi 2 dan format lama tanpa daftar rencana pakan tetap didukung.

## Pemeriksaan kode

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test --coverage
flutter build web --release
```

Workflow [Flutter checks](.github/workflows/flutter.yml) menjalankan perintah tersebut pada push dan pull request. Tes menggunakan storage dalam memori dan respons HTTP fixture; tidak memerlukan backend aktif. Petunjuk perubahan kode ada di [CONTRIBUTING.md](CONTRIBUTING.md).

## Batas MVP

Data belum disinkronkan ke cloud. Belum ada akun, notifikasi OS, inventaris stok, atau pencatatan realisasi pemberian pakan. Centang daftar persiapan berlaku selama halaman dibuka. Foto dapat memenuhi kuota penyimpanan browser.

Rekap periode menghitung takaran harian × jumlah hari, tanpa memprediksi perubahan kebutuhan. Hanya rencana terbaru yang masih sesuai dengan profil/pengukuran dan interval cek bobot yang masuk ke rekap. Rekomendasi awal ditujukan untuk sapi potong yang tidak bunting dan tidak menyusui.

Build iOS memerlukan Xcode dan signing lokal. Tes, analyzer, build, dan pemeriksaan kamera/galeri pada perangkat harus lolos sebelum rilis. Penambahan workflow atau tes di repositori belum merupakan bukti bahwa pemeriksaan tersebut sudah berhasil.
