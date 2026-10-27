# Pakan individual — Pedaging dan Perah

Pembaruan 27 Oktober 2026. Fokus pada alur Pakan individual yang jelas, konsisten, dan mudah dipakai.

## Alur pengguna

- **Farm Both:** kartu Sapi Pedaging/Sapi Perah tampil sebelum daftar sapi. Pilihan menyaring sapi aktif, ringkasan evaluasi, dan proses berikutnya. Pilihan dari halaman Pakan diteruskan tanpa pertanyaan ulang.
- **Farm single-domain:** langsung masuk konteks farm; label Pedaging/Perah tetap terlihat jelas.
- Entry dari profil sapi, hasil estimasi bobot, dashboard, serta modul Beef/Dairy memakai pintu masuk yang sama. Kategori sapi tidak dianggap sebagai pilihan domain pengguna untuk farm Both.
- Farm legacy tanpa sistem produksi diarahkan ke pengaturan. Kategori null tidak ditebak; sapi nonaktif tidak masuk pilihan evaluasi.

## Penyempurnaan UX

- Kartu pilihan responsif, area tekan besar, deskripsi singkat, serta jumlah sapi aktif.
- Ringkasan menampilkan jumlah **evaluasi tersimpan**, tanpa menyamakan evaluasi v2 dengan ransum aktif/siap stok.
- Field bahan memakai nama yang dapat dibaca, tanpa ID teknis; catatan sumber backend ditampilkan untuk bahan terpilih bila tersedia.
- Sapi yang belum lengkap memiliki aksi langsung ke profil atau daftar sapi belum diklasifikasi.
- Tambah sapi dari konteks Pedaging/Perah membawa kategori awal; tidak perlu memilih dari nol lagi. Pengguna tetap dapat mengubahnya secara eksplisit pada form existing.
- Pergantian domain meminta konfirmasi hanya bila ada input pakan/ADG yang belum disimpan. Batal mempertahankan input; lanjut membersihkannya tanpa menghapus histori.
- Reklasifikasi dan perubahan sistem farm membatalkan konteks lama; katalog terlambat diabaikan.

## Implementasi

File utama: `individual_feed_entry_screen.dart`, `feed_hub_screen.dart`, `feed_calculator_screen.dart`, dan komponen bersama `widgets/feed_domain_choice.dart`. `AddCattleScreen` mendapat parameter kategori awal opsional. Entry point individual lainnya hanya diarahkan ke pintu masuk baru.

Model, FarmStore, serializer, schema, histori, API v2, backend, dan layar Group Feed tidak diubah dalam fase UX ini. Assertion/fixture di `groups_ui_test.dart` yang menyentuh navigasi **individual** disesuaikan; perilaku kelompok tetap diuji.

## Verifikasi

- 18 kasus widget khusus alur domain: Both, single-domain, filter sapi, request konteks Twin, pergantian domain, pembatalan input, legacy, penambahan sapi sesuai konteks, serta lebar 320/390.
- Tes terfokus awal: **53 lulus**.
- Formatter: lulus, 0 perubahan yang diperlukan.
- `flutter analyze`: tanpa issue.
- Full VM: **420 lulus**.
- Chrome regression terkait: **113 lulus**.
- `flutter build web --release`: berhasil.
- `git diff --check`: bersih.
- Pratinjau release diperiksa melalui browser: kartu Both, daftar sapi Perah, serta masuk ke form Perah tanpa pertanyaan ulang. Katalog live berhasil dimuat. Data pratinjau menggunakan farm uji terpisah di localhost.
- Log dan screenshot tersedia di `outputs/individual-feed-domain-redesign/` pada workspace percakapan.
- Hambatan startup Dart pada sesi sebelumnya sudah teratasi; hasil pengujian fase sebelumnya tidak dipakai sebagai pengganti verifikasi kode ini.

Tidak ada commit/push. Tampilan scientific result, Group Feed, serta workflow domain lengkap di luar Pakan individual bukan bagian redesign ini.
