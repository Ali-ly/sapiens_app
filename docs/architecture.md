# Arsitektur rebuild

Implementasi baru dari folder kosong, tanpa menyalin frontend lama. Guardrail: dokumen lampiran bernama PRD v0.1, yang isi aktualnya berjudul PRD v0.2 (27 Oktober 2026). Instruksi pengguna untuk langsung eksekusi mengesampingkan instruksi persetujuan proposal di dokumen.

## Alur dan kepemilikan state

`Screen → Riverpod FarmController → immutable FarmData → FarmRepository → platform storage`.

- Mode Potong/Perah berada pada `FarmAccount`, tidak diduplikasi sebagai kategori per sapi.
- `Cattle` menyimpan identitas bersama dan histori; kondisi memakai tipe `BeefCondition` atau `DairyCondition`. Layar ringkasan kedua domain terpisah.
- Form draft berada di widget; mode, konteks sapi, dan histori durable berada di controller/repository. Provider API dipisahkan dari model domain dan penyimpanan.
- Bobot awal dan kondisi disimpan atomik saat membuat sapi. UUIDv4 tidak bergantung clock. Semua pengukuran, foto valid, kondisi, susu, perawatan, dan evaluasi ditambahkan sebagai catatan baru.
- Susu memakai satu mode per tanggal (total atau AM/PM). Koreksi mengacu ID aktif sebelumnya; histori tidak ditimpa. Sesi kosong tetap null, unit kg/liter tidak dicampur.
- Evaluasi membawa snapshot konteks, request, response, nama bahan, dan hash konteks. Perubahan input nutrisi menandai hasil lama perlu evaluasi ulang. Request yang sedang berjalan tidak boleh menyimpan hasil bila konteks sudah berubah. Hasil evaluasi bukan ransum aktif.
- Arsip bersifat reversible dan mengecualikan sapi dari operasi aktif. Ganti mode adalah reset terkonfirmasi yang berbeda, menghapus seluruh histori sapi.

## Penyimpanan dan keamanan pembacaan

Format baru `application: sapiens-rebuild`, schema 1 / minimum reader 1, checksum SHA-256 atas payload kanonik, revision, dan validasi relasi. Snapshot aplikasi lama/asing, versi lebih baru, field persisted tak dikenal, checksum rusak, dan referensi invalid ditolak sebelum write.

Web memakai transaksi IndexedDB (`sapiens_rebuild/account/snapshot`). Native memakai application-support `sapiens_rebuild/account-v1.json`, write ke pending lalu rename. State baru baru dipublikasikan setelah write sukses; antrean repository mencegah kehilangan update paralel. Kegagalan load tidak memulai akun kosong dan menimpa data. Restore eksplisit bisa memulihkan cadangan valid; restore/reset memakai guard terhadap state yang berubah.

Cadangan berisi seluruh data termasuk bytes foto. Belum ada enkripsi, sinkronisasi, kompresi/optimasi media, atau migrasi aplikasi lama. Pengguna perlu mencadangkan sebelum clear browser data, pindah origin, atau reset mode. Batas quota browser dilaporkan sebagai kegagalan simpan, bukan keberhasilan palsu.

## Struktur

- `lib/domain`: immutable identity, condition, records, validasi dan metrik susu deterministik.
- `lib/api`: kontrak Gateway, parser, HTTP v2 dan multipart.
- `lib/application`: providers, controller mutation, penyusunan konteks dan invalidasi evaluasi.
- `lib/data`: codec cadangan, repository, storage platform.
- `lib/features`: onboarding, home, cattle, weight, care, milk, feed, settings.
- `lib/ui`: komponen tampilan bersama, avatar, chart histori aktual.
- `test`: kontrak response nyata, unit/storage, widget dan IndexedDB browser.
- `tool`: tes live opt-in dan renderer preview lokal.

Android/iOS memiliki deklarasi izin kamera/galeri dan akses jaringan yang diperlukan. Build native/release/signing serta kamera fisik belum diverifikasi; target yang dibangun pada pekerjaan ini adalah web.
