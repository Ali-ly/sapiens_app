# Arsitektur SAPITA

## Pembagian tanggung jawab

| Direktori | Tanggung jawab |
| --- | --- |
| `lib/core` | Konfigurasi API, warna, teks brand, dan tema |
| `lib/models` | Entity, snapshot, hasil estimasi bertipe, dan aturan validasi |
| `lib/data` | Codec cadangan/persistensi dan pembuat data contoh |
| `lib/state` | Siklus state aplikasi dan adapter penyimpanan per platform |
| `lib/services` | Transport HTTP, pemetaan respons API, serta pemilihan gambar |
| `lib/screens` | Halaman dan state interaksi pengguna |
| `lib/widgets` | Komponen tampilan bersama |
| `test/helpers` | Pembungkus aplikasi tes dan pembaca fixture |

Tidak ada singleton state aplikasi. `SapitaApp` membuat satu `FarmStore` dan menyediakannya melalui `FarmScope`. Tes dapat memasukkan store sendiri melalui konstruktor. Aplikasi hanya membuang store yang dibuatnya sendiri. `FarmScope.read` tidak berlangganan perubahan; halaman yang membutuhkan pembaruan menggunakan `AnimatedBuilder` dengan store tersebut.

## Invarian data dan penulisan

`FarmSnapshot`, `Cattle`, dan `FeedPlan` mengekspos koleksi yang tidak dapat dimutasi. `SelectedImage` menyalin byte input dan memberikan tampilan byte read-only. Perubahan dilakukan melalui metode store, bukan dengan mengubah list dari halaman.

`FarmStore` mengurutkan pembacaan dan penulisan melalui antrean. Mutasi saat startup menunggu pembacaan awal. Builder mutasi menggunakan snapshot terbaru; data baru diterapkan dan listener diberi tahu setelah penulisan berhasil. Kegagalan satu operasi tidak mengunci antrean berikutnya.

`updateIdentity` hanya mengubah identitas. `recordWeight` menambahkan catatan pada riwayat terbaru, sehingga halaman lama tidak menimpa edit identitas atau catatan lain. Hasil AI menyertakan panjang riwayat saat permintaan dibuat; hasil yang sudah tertinggal ditolak. `saveCattle` digunakan untuk pembuatan/penggantian entity secara eksplisit, bukan untuk edit parsial dari UI.

Jika data lokal tidak dapat dibaca, snapshot yang sudah ada dipertahankan dan mutasi biasa diblokir. Pemulihan dari cadangan valid merupakan jalur pemulihan yang eksplisit. Kegagalan menulis tidak dianggap berhasil oleh UI.

`CattleRules` digunakan untuk mutasi maupun pemulihan, termasuk rentang angka, urutan riwayat, dan kecocokan bobot terakhir. `FeedPlanRules` memeriksa identitas, bahan, takaran, dan total. Codec juga memeriksa ID/nama duplikat serta hubungan rencana dengan sapi.

## Persistensi dan kompatibilitas

`FarmBackupCodec` memiliki schema JSON versi 2. Pembacaan disk dan impor cadangan memakai decoder yang sama. Format lama tanpa `schemaVersion`, `feedPlans`, atau sumber catatan bobot tetap diterima. Versi schema yang tidak dikenali ditolak.

Identifier penyimpanan, lokasi file, dan bundle/application ID lama sengaja tidak diubah saat package Dart menjadi `sapita_app`. Perubahan identifier tersebut membutuhkan rencana migrasi tersendiri. Nama lama pada identifier bukan teks brand yang ditampilkan pengguna.

Adapter native menulis file sementara lalu menggantikan file utama. Adapter browser memakai localStorage. Foto diserialkan sebagai base64, sehingga batas kuota perangkat/browser tetap berlaku. `latestCheckImages` bersifat sementara untuk alur peninjauan; foto tersimpan ada di `images`.

## API

Alamat gateway berasal dari `ApiConstants.baseUrl` dan dapat diganti dengan `--dart-define=API_BASE_URL=...`.

### Estimasi bobot

`POST /predict-weight`, multipart dengan satu sampai empat bagian `files`. `WeightService` mengembalikan `WeightEstimate`, bukan map JSON mentah. Field respons:

- `estimated_weight_kg`: bobot numerik yang valid.
- `prediction_spread_kg`: variasi prediksi opsional.
- `num_valid_images`: jumlah foto yang diterima, dan `rejected_files`: daftar foto yang ditolak (keduanya opsional).

Variasi prediksi tidak diperlakukan sebagai interval kepercayaan klinis atau jaminan akurasi.

### Perhitungan pakan

`POST /calculate-feed`, JSON:

```json
{
  "weight": 350,
  "target": "penggemukan",
  "available_feeds": ["rumput", "jerami", "dedak"]
}
```

Target yang didukung: `pemeliharaan`, `pertumbuhan`, `penggemukan`. Minimal satu sumber serat (`rumput` atau `jerami`) dipilih dalam formulir. Tidak ada field umur, jenis kelamin, atau kondisi tubuh yang ditambahkan ke kontrak backend tanpa dukungan backend.

Respons memiliki `recommendation` per bahan dengan `as_fed_kg`, opsional `dry_matter_kg` dan `ratio_dm`; dapat menyertakan `total_dry_matter_kg`, `weight_kg`, `target`, `warning`, dan `notes`. Fixture kontrak ada di `test/fixtures/feed_response.json`.

`FeedResponseMapper` memisahkan kontrak gateway dari model penyimpanan. Kg pakan segar dan kg bahan kering dipertahankan sebagai besaran berbeda. Bahan tidak dipilih, nilai negatif/non-finite, total nol, atau hasil yang tidak cocok dengan permintaan ditolak.

`ApiResponse` menangani JSON dan error gateway/FastAPI yang dapat bertingkat. Timeout dan kegagalan jaringan diubah menjadi `ApiException`. Client HTTP yang disuntikkan tetap dimiliki pemanggil; client bawaan ditutup oleh service.

## Rencana aktif

Rencana menyimpan snapshot bobot, tanggal pengukuran, umur, dan jenis kelamin. Rencana menjadi tidak aktif untuk rekap saat data tersebut berubah atau bobot perlu diperiksa lagi. Riwayat rencana tetap disimpan. Nama sapi boleh diedit tanpa mengubah takaran sebelumnya; nama dalam rencana adalah snapshot saat perhitungan.

Jam store dapat disuntikkan agar batas aktivitas tujuh hari dan pengingat dapat diuji deterministik. Jika dua rencana memiliki timestamp yang sama, rencana yang terakhir disimpan dipilih.

## Verifikasi

Tes mencakup kontrak HTTP, pemetaan satuan, data tidak valid, persistensi, kegagalan simpan, operasi bersamaan, hasil AI tertinggal, pemulihan cadangan, isolasi store, dan alur widget. Tes widget ukuran layar tidak menggantikan pengujian kamera, keyboard, aksesibilitas, dan signing pada perangkat.

CI mengikuti [panduan Flutter continuous delivery](https://docs.flutter.dev/deployment/cd) dan [flutter-action](https://github.com/subosito/flutter-action). Flutter dipatok ke 3.24.5 agar perubahan SDK dilakukan sebagai perubahan terpisah. Diagnostic info bersifat advisory; error dan warning analyzer menggagalkan CI. CI saat ini membangun web; build/signing iOS perlu dilakukan pada macOS dengan Xcode.
