# SAPITA

Aplikasi Flutter untuk alur **bobot sapi → estimasi pakan → pemantauan**. UI memakai palet olive/krem, kartu membulat, navigasi mengambang, kontrol Cupertino, transisi iOS, dan ikon brand sendiri.

## Alur inti

1. Daftarkan sapi dan umur dalam bulan.
2. Catat bobot dari timbangan atau ambil 1–4 foto untuk Weight API.
3. Sesudah estimasi, pilih **Simpan & hitung pakan**. Bisa juga membuka tab **Pakan** atau bagian Pakan pada profil sapi.
4. Pilih target **Pemeliharaan / Pertumbuhan / Penggemukan**, bahan **Rumput hijauan / Jerami padi / Dedak padi**, serta kondisi tubuh.
5. Hitung melalui Feed API, tinjau rincian kg pakan segar/hari, bahan kering, komposisi, dan catatan dari layanan.
6. Simpan rencana pada sapi. Buka persiapan pakan untuk rekap seluruh kandang dalam 1, 7, atau 30 hari.

API saat ini menerima `weight`, `target`, dan `available_feeds`. Umur, jenis kelamin, dan kondisi tubuh tersimpan sebagai konteks; tidak diklaim sebagai faktor perhitungan otomatis. Cakupan rencana awal adalah sapi potong yang tidak bunting dan tidak menyusui. Tidak ada kalkulasi pakan lokal palsu saat layanan gagal.

## Halaman dan fitur

- **Beranda:** pintasan bobot/pakan, status rencana, statistik, sapi yang perlu dicek, dan ringkasan aktivitas.
- **Sapi:** pencarian, filter jenis kelamin/perlu dicek/pakan belum siap, urut nama atau bobot, tambah/edit/hapus.
- **Profil sapi:** tab Ringkasan/Bobot/Pakan, grafik berdasarkan tanggal, sumber catatan bobot, galeri, rencana terbaru dan riwayatnya.
- **Pakan:** rencana per sapi, formulir hitung, hasil rekomendasi, riwayat, salin rincian, dan daftar persiapan bahan seluruh kandang.
- **Insight:** rata-rata bobot tercatat, aktivitas 7 hari, kesiapan pakan, dan catatan terbaru.
- **Profil:** identitas peternakan, interval cek bobot, panduan, ekspor/pemulihan cadangan JSON.

Rencana yang bobot/umur/jenis kelamin/tanggal pengukurannya sudah berubah ditandai untuk ditinjau. Hanya rencana terbaru yang cocok dan belum melewati interval cek bobot yang dimasukkan ke rekap bahan terkini. Rekap periode adalah takaran harian × jumlah hari, bukan prediksi perubahan kebutuhan di masa depan.

## Menjalankan

```sh
flutter pub get
flutter run
# Browser, gunakan port tetap untuk mempertahankan origin penyimpanan:
flutter run -d chrome --web-port 8080
```

Endpoint gateway tetap mengikuti konfigurasi proyek sebelumnya. Untuk menggantinya:

```sh
flutter run --dart-define=API_BASE_URL=https://alamat-backend
```

Mulai dengan **Coba dengan data contoh** untuk menjelajahi 5 profil sapi. Data bobot contoh ditandai; rekomendasi pakan tetap diminta ke API sungguhan.

## Penyimpanan

Data disimpan lokal, termasuk foto dan rencana pakan. Browser memakai localStorage; native memakai file JSON. Penulisan diserialkan dan state baru diumumkan setelah penyimpanan berhasil. Data versi sebelumnya yang belum memiliki rencana pakan atau sumber catatan bobot tetap dapat dibaca.

Ekspor melalui **Profil → Cadangan data → Salin cadangan JSON**, lalu simpan ke file. Pemulihan memeriksa data, menampilkan ringkasan, dan meminta konfirmasi sebelum mengganti seluruh data perangkat. Kuota localStorage browser membatasi jumlah foto; bila penuh, aplikasi menampilkan kegagalan simpan. Belum ada akun, sinkronisasi cloud, notifikasi OS, stok inventaris, atau pencatatan pakan benar-benar diberikan. Centang daftar persiapan hanya berlaku selama halaman terbuka.

## Platform

Izin kamera dan galeri iOS, akses internet Android release, serta akses jaringan/file pilihan macOS sudah dikonfigurasi. Kamera pada perangkat yang tidak mendukungnya akan menampilkan pesan agar memilih galeri. Brand icon tersedia untuk iOS, Android, macOS, dan web; layar peluncuran iOS/Android disesuaikan.

## Verifikasi

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

- API pakan hidup diuji dengan 21 kombinasi: 18 rekomendasi HTTP 200 dan 3 penolakan dedak-saja HTTP 400 sesuai aturan serat. Preflight CORS browser mengizinkan header yang digunakan aplikasi.
- File Dart diperiksa dengan parser dan formatter Dart versi bahasa 3.5.0. Impor lokal, ikon, plist/XML, dan ukuran ikon aplikasi diperiksa statis.
- Tes mencakup kontrak HTTP, validasi respons, persistensi/migrasi rencana, perubahan bobot, rekap, kegagalan simpan, cadangan, CRUD, dan alur UI termasuk ukuran 320/390/430 px.
- **Tes Flutter, pemeriksaan tipe/analyzer, build, dan QA visual runtime belum berhasil dijalankan di sandbox ini.** Dart 3.5.4 berhenti sebelum kompilasi pada `cpuinfo_macos.cc:42`; SDK lain membutuhkan macOS 14 sementara host melaporkan macOS 13. Parsing sintaks dan pengujian API tidak menggantikan pengujian aplikasi. Jalankan perintah di atas dari terminal normal sebelum menganggap aplikasi siap rilis.

File lama `screens/weight/weight_check_screen.dart` dipertahankan sebagai referensi implementasi sebelumnya. Navigasi utama memakai alur bobot dan pakan yang terhubung dengan profil sapi.

## Penyempurnaan SAPITA

Nama produk sekarang **SAPITA** pada UI, label platform, judul browser, dan produk desktop. Nama package Dart `cattle_app`, bundle/application ID, serta kunci/lokasi penyimpanan dipertahankan untuk kompatibilitas data dan impor kode lama. Pintu masuk UI memakai `SapitaApp`; alias `CattleApp` tetap tersedia untuk integrasi lama.

- Tambah sapi langsung membuka profil untuk melanjutkan pencatatan bobot dan rencana pakan.
- Formulir tambah/edit sapi dan preferensi memberi konfirmasi bila ditinggalkan sebelum disimpan.
- Edit identitas membaca data terkini saat penyimpanan, sehingga tidak menimpa bobot/riwayat yang diperbarui setelah formulir dibuka.
- Data contoh bisa dihapus dari Profil secara terpisah; sapi yang ditambahkan sendiri dan rencana pakannya dipertahankan.
- Pembacaan penyimpanan menggunakan data sementara sebelum mengganti state aktif, sehingga file rusak tidak menyebabkan pembaruan sebagian data.
- Penggunaan pertama menyediakan pintasan pengaturan peternakan dan tidak mengasumsikan nama pemilik tertentu.
- `.gitignore` mencakup kredensial lokal, berkas penandatanganan, screenshot otomatis, dan folder ekspor/cadangan.

Delapan tes tambahan mencakup identitas, riwayat terkini, penghapusan contoh, kegagalan simpan/baca, branding SAPITA, dan perlindungan formulir. Batas verifikasi runtime SDK masih berlaku seperti dijelaskan di atas.
