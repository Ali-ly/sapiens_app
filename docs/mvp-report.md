# SAPIENS MVP rebuild — 27 Oktober 2026

## Fitur yang diimplementasikan

- Onboarding akun lokal Potong/Perah; navigasi Beranda–Ternak–Pakan–Profil; konteks mode diwariskan tanpa pilihan ulang di setiap proses.
- Tambah sapi dua langkah dengan bobot awal wajib (manual atau estimasi 1–4 foto), identitas sederhana, kondisi yang berbeda per mode/jenis kelamin.
- Profil sapi adaptif, edit identitas terpisah dari kondisi, pencarian/filter, arsip/pulihkan, daftar aktif yang konsisten.
- Bobot, perubahan, grafik riwayat aktual, galeri foto, estimasi Gateway v2, penandaan foto ditolak, dan histori append-only.
- Pakan cattle-centric: katalog backend sesuai mode, jumlah bahan segar per hari, konteks Twin, evaluasi v2, hasil dan metadata backend, snapshot tersimpan, penanda perlu evaluasi ulang ketika konteks berubah.
- Perah: susu total harian atau AM/PM, data parsial, koreksi tanpa overwrite, unit eksplisit, rata-rata hari lengkap 7/30 hari, tren, peak tercatat, kurva aktual, DIM dari calving nyata dan nomor laktasi bila diketahui.
- Perawatan per domain; catatan manual IB, pemeriksaan kebuntingan, konsepsi terkonfirmasi yang terkait IB, calving, observasi ambing/susu, dan masa tahan berdasarkan tanggal pengguna. Fresh/Early dan Dry/Close-Up tetap berbeda.
- Beranda memakai data nyata untuk ringkasan, perhatian yang bisa ditindaklanjuti, aktivitas terbaru, dan aksi cepat. Tidak ada warning berdasarkan threshold arbitrer.
- Backup/restore tervalidasi, penanganan data rusak tanpa overwrite, reset mode terkonfirmasi `GANTI` yang menghapus semua sapi dan histori.

## Arsitektur dan model

Flutter/Riverpod dengan controller aplikasi, model immutable, repository serial, IndexedDB web dan file atomik native. Format rebuild schema 1 terpisah dari frontend lama, checksum/reader guard, UUIDv4 dan referensi tervalidasi. Tidak ada migrasi atau pembacaan data aplikasi backup. Backend tidak diubah.

NutritionEvaluation menyimpan request, response, snapshot konteks, nama bahan dan hash konteks. Evaluasi bukan ransum aktif. Susu memakai correction chain; bobot/foto/kondisi/perawatan tetap ditambahkan. Penggantian mode dan restore adalah operasi eksplisit dengan guard revision.

## Konflik dan keputusan

- Nama berkas lampiran v0.1, isi PRD aktual v0.2. Mengikuti isi aktual serta instruksi pengguna untuk langsung eksekusi; tidak menjalankan approval proposal yang diminta dokumen.
- Backend belum mendukung Beef Pembibitan, sejumlah stage Dairy, atau nutrisi jantan Dairy. UI pencatatan tersedia, evaluasi diblokir secara jelas; tidak memakai kalkulator pengganti.
- Fase Beef Awal/Akhir tidak memengaruhi formula backend saat ini. DIM 0 valid secara data tetapi ditolak kontrak nutrisi; tidak diubah menjadi DIM 1.
- Susu menerima kg atau liter secara eksplisit; nutrisi hanya menggunakan catatan lengkap kg. Tidak mengonversi liter diam-diam.
- Produk spesifik belum menerima override label/lab pada request backend; input tersebut ditunda agar tidak memberi kesan dipakai dalam evaluasi.
- Akun MVP lokal, tanpa login/cloud/multi-farm. Bahasa Indonesia, target Flutter mobile + web; verifikasi build pada web.

## Verifikasi

| Pemeriksaan | Hasil |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test tool` | 60 berkas; 0 perubahan |
| `flutter analyze` | 0 issue |
| Full VM suite | 51 lulus; 3 skip (2 live opt-in, 1 IndexedDB khusus web) |
| Full Chrome suite | 52 lulus; 2 skip (live opt-in) |
| Live Flutter VM → Gateway | 3 lulus: Beef, Dairy, Weight; snapshot round trip |
| Live Flutter Chrome → Gateway | 2 lulus: Beef/Dairy, CORS/preflight, snapshot round trip |
| Preview widget asli | 1 tes lulus; 8 PNG, tampilan diperiksa |
| `flutter build web --release` | Berhasil; `build/web` |
| Whitespace source/docs | Tidak ada trailing whitespace |

Cakupan regression: mandatory initial weight, pemisahan mode/jenis kelamin, context routing, API contract, partial Dairy status, append-only weight/photo/milk/condition/event, stale in-flight evaluation, reset mode, koreksi susu, paritas/DIM, larangan memakai susu laktasi lama setelah calving baru, histori arsip, disk failure, backup/restore, future-reader guards, dan layout 320/390/1024 px.

Hasil awal lint/test yang ditemukan selama implementasi sudah diperbaiki; tabel mencatat hasil final. Live request memakai data sintetis dan foto publik. Kamera/galeri fisik tidak diklaim telah diuji. Pada verifikasi MVP awal, whitespace diperiksa langsung sebelum inisialisasi Git. Publikasi GitHub dilakukan terpisah setelah instruksi pengguna.

Ringkasan hasil: [verification.json](verification.json). Preview dan log lengkap tersedia pada output lokal sesi implementasi. App release dapat dicoba secara lokal pada [localhost:8736](http://localhost:8736); restart server dari project dengan `python3 -m http.server 8736 --bind 127.0.0.1 --directory build/web` bila diperlukan.

## Area review dan batas yang disengaja

1. Uji pemakaian peternak: istilah, urutan form, pengisian konteks laktasi, dan pemilihan satuan susu.
2. Kesepakatan kapabilitas backend: Pembibitan, stage belum didukung, DIM 0, fase Beef, rentang bobot/ADG dan nutrien Dairy yang belum evaluable penuh.
3. Kamera/galeri, share/import backup dan izin pada perangkat Android/iOS fisik; native signing/release dan finalisasi ikon launcher belum dikerjakan.
4. Kebijakan akun/cloud dan port/origin web produksi. Data browser terikat origin; media disimpan utuh, tanpa optimasi/enkripsi/cloud backup.
5. Kebijakan penghapusan foto yang terkait bobot, custom feed label/lab, serta reminder ilmiah belum ditetapkan. Fitur tersebut tidak ditebak dalam MVP.

Tidak mencakup Group Feed, stok/MRP, Halo Moo, IoT, AI BCS baru, diagnosis, formula lokal, atau advanced economics. Publikasi source berada pada branch `codex/sapiens-mvp-rebuild`; versi lama di `main` dipertahankan untuk review. Tidak ada deploy.
