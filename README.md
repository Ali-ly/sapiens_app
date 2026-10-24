# SAPIENS

Aplikasi Flutter untuk peternak kecil yang mencatat sapi secara individual. Alur utama adalah **tambah sapi → profil → bobot → pakan → riwayat**. Kelompok/kandang tersedia sebagai opsi tambahan untuk ternak banyak, tanpa menjadi prasyarat profil sapi.

## Farm Command Center — Fondasi 1

Tab **Ringkasan** menyatukan jumlah sapi, kelengkapan bobot, cakupan rencana pakan terkini, rekap bahan harian, antrean tindakan prioritas, dan aktivitas terbaru. Semuanya berasal dari data lokal yang sudah tersimpan.

Setiap sapi mendapat paling banyak satu langkah berikutnya: catat bobot awal, periksa ulang bobot, buat rencana pakan, atau perbarui rencana yang tertinggal. Ini merupakan antrean dari data yang perlu dilengkapi, bukan diagnosis kesehatan atau daftar tugas yang dapat dicentang manual. Tindakan hilang setelah data terkait diperbarui.

Rekap pakan hanya memasukkan sapi dengan rencana terkini. Ringkasan menampilkan cakupannya agar total sebagian tidak dianggap sebagai kebutuhan seluruh kandang.

### Navigasi

- Tab **Ternak** langsung membuka daftar sapi individual. Kelompok/kandang dibuka melalui tautan opsional dan kembali ke daftar yang sama.
- Empat tujuan utama: **Ringkasan, Ternak, Pakan, Profil**. Pencarian, filter, dan posisi halaman tetap tersimpan ketika berpindah tab.
- Pintasan statistik membuka tab terkait; pintasan daftar sapi juga menerapkan filter dan membersihkan pencarian lama agar hasil sesuai pintasan.
- Tombol kembali sistem pada tab utama lain kembali ke Ringkasan. Halaman detail tetap kembali ke halaman asalnya.
- Foto → peninjauan, lalu peninjauan tersimpan → kalkulator, mengganti langkah sebelumnya. Kalkulator → hasil tetap dapat kembali untuk mengubah input sebelum menyimpan. Sesudah hasil disimpan, tombol Selesai maupun kembali sistem menyelesaikan alur ke halaman asal.
- Edit bobot dari kalkulator memakai dialog dan tetap berada di konteks perhitungan.

## Digital Twin Ternak — Fondasi 2

Profil individual menjadi jalur utama di Home, tab Ternak, dan Pakan. Kelompok/kandang adalah opsi tambahan dengan entitas mandiri, dengan nama, jumlah sapi, bobot rata-rata, target, catatan, serta histori perubahan data. Buka **Ternak → Kelompok/kandang**, buat kelompok, lalu hitung kebutuhan pakan tanpa membuat profil sapi satu per satu.

API pakan menerima bobot rata-rata dan target; takaran per ekor dikalikan jumlah sapi. Hasil dan inputnya disimpan sebagai rencana kelompok. Perubahan jumlah, bobot rata-rata, atau target mengharuskan perhitungan ulang; rencana lama tetap tersedia dalam histori. Kelompok berisi sapi dapat diarsipkan dan dipulihkan tanpa menghapus data.

**Ternak** langsung membuka daftar sapi; tombol tambah membuka formulir lalu profil sapi. Data individual tidak otomatis mengubah jumlah atau bobot kelompok. Rekap persiapan pakan membuka data individual secara default dan menyediakan pilihan kelompok agar kedua sumber tidak dihitung ganda. Pintasan **Rekap pakan kelompok** di halaman kelompok langsung memilih cakupan kelompok. Lihat [model, migrasi, dan batas tahap Digital Twin](docs/digital-twin.md).

Tombol **Hitung kebutuhan pakan** di Profil Ternak nonaktif selama bobot belum tersedia dan otomatis aktif setelah bobot manual atau estimasi tersimpan.

## Fitur MVP

- Profil sapi, pencarian, filter, edit identitas, dan riwayat bobot dengan grafik.
- Input bobot manual atau estimasi melalui API dari 1–4 foto.
- Rekomendasi pakan melalui API berdasarkan bobot, target, dan bahan yang tersedia.
- Riwayat rencana, penanda rencana yang perlu diperbarui, dan rekap bahan per kandang.
- Identitas peternakan, interval pengecekan, serta ekspor dan pemulihan cadangan JSON.

## Menjalankan

Folder project bernama `sapiens_app`. Jika sebelumnya menjalankan aplikasi dari `sapita_app`, hentikan proses lama lalu jalankan ulang dari folder baru.

Versi acuan pengembangan dan CI: **Flutter 3.24.5 / Dart 3.5.4**.

```sh
flutter pub get
flutter run
```

Brand aplikasi adalah **SAPIENS**. Nama package Dart tetap `sapita_app` untuk menjaga integrasi internal; identifier penyimpanan dan bundle ID juga tetap dipertahankan. Jalankan `flutter pub get` setelah menarik perubahan agar konfigurasi package lokal diperbarui.

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

Cadangan tersedia pada **Profil → Cadangan data**. Impor memvalidasi seluruh data dan menampilkan konfirmasi sebelum mengganti data perangkat. Ekspor memakai schema versi 4 dengan histori data dan rencana pakan kelompok. Versi 3 dimigrasikan menjadi data kelompok mandiri; relasi lama disimpan sebagai arsip kompatibilitas, tanpa mengendalikan kelompok. Impor versi 2 dan format lama tetap didukung.

## Pemeriksaan kode

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter test --platform chrome test/app_flow_test.dart test/command_center_test.dart test/groups_ui_test.dart test/photo_preview_test.dart
flutter build web --release
```

Tes browser memerlukan Chrome terpasang (atau `CHROME_EXECUTABLE` menunjuk executable Chrome). Analyzer dijalankan tanpa pengecualian untuk info lint.

Workflow [Flutter checks](.github/workflows/flutter.yml) menjalankan perintah tersebut pada push dan pull request. Tes menggunakan storage dalam memori dan respons HTTP fixture; tidak memerlukan backend aktif. Petunjuk perubahan kode ada di [CONTRIBUTING.md](CONTRIBUTING.md).

## Arah pengembangan

Lima fondasi jangka panjang: **Farm Command Center, Digital Twin, Insight Engine, Halo Moo, dan IoT**. Tahap ini mencakup Farm Command Center serta Digital Twin awal untuk sapi individual dan kelompok/kandang. Insight Engine, Halo Moo, dan IoT belum diaktifkan. Lihat [cakupan dan keputusan tahap ini](docs/farm-command-center.md).

## Batas MVP

Data belum disinkronkan ke cloud. Belum ada akun, notifikasi OS, inventaris stok, atau pencatatan realisasi pemberian pakan. Centang daftar persiapan berlaku selama halaman dibuka. Foto dapat memenuhi kuota penyimpanan browser.

Rekap periode menghitung takaran harian × jumlah hari, tanpa memprediksi perubahan kebutuhan. Rekap individual memakai rencana terbaru yang sesuai profil/pengukuran dan interval cek bobot. Rekap kelompok memakai rencana yang sesuai jumlah, bobot rata-rata, dan target terakhir. Estimasi kelompok mengasumsikan kondisi ternak relatif seragam; pembaruan bobot rata-rata dilakukan peternak. Rekomendasi awal ditujukan untuk sapi potong yang tidak bunting dan tidak menyusui.

Build iOS memerlukan Xcode dan signing lokal. Tes, analyzer, build, dan pemeriksaan kamera/galeri pada perangkat harus lolos sebelum rilis. Penambahan workflow atau tes di repositori belum merupakan bukti bahwa pemeriksaan tersebut sudah berhasil.
