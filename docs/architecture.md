# Arsitektur SAPIENS

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

Tidak ada singleton state aplikasi. `SapiensApp` membuat satu `FarmStore` dan menyediakannya melalui `FarmScope`. Tes dapat memasukkan store sendiri melalui konstruktor. Aplikasi hanya membuang store yang dibuatnya sendiri. `FarmScope.read` tidak berlangganan perubahan; halaman yang membutuhkan pembaruan menggunakan `AnimatedBuilder` dengan store tersebut.

## Invarian data dan penulisan

`FarmSnapshot`, `Cattle`, dan `FeedPlan` mengekspos koleksi yang tidak dapat dimutasi. `SelectedImage` menyalin byte input dan memberikan tampilan byte read-only. Perubahan dilakukan melalui metode store, bukan dengan mengubah list dari halaman.

`FarmStore` mengurutkan pembacaan dan penulisan melalui antrean. Mutasi saat startup menunggu pembacaan awal. Builder mutasi menggunakan snapshot terbaru; data baru diterapkan dan listener diberi tahu setelah penulisan berhasil. Kegagalan satu operasi tidak mengunci antrean berikutnya.

`updateIdentity` hanya mengubah identitas. `recordWeight` menambahkan catatan pada riwayat terbaru, sehingga halaman lama tidak menimpa edit identitas atau catatan lain. Hasil AI menyertakan panjang riwayat saat permintaan dibuat; hasil yang sudah tertinggal ditolak. `saveCattle` digunakan untuk pembuatan/penggantian entity secara eksplisit, bukan untuk edit parsial dari UI.

Jika data lokal tidak dapat dibaca, snapshot yang sudah ada dipertahankan dan mutasi biasa diblokir. Pemulihan dari cadangan valid merupakan jalur pemulihan yang eksplisit. Kegagalan menulis tidak dianggap berhasil oleh UI.

`CattleRules` digunakan untuk mutasi maupun pemulihan, termasuk rentang angka, urutan riwayat, dan kecocokan bobot terakhir. `FeedPlanRules` memeriksa identitas, bahan, takaran, dan total. Codec juga memeriksa ID/nama duplikat serta hubungan rencana dengan sapi.

## Persistensi dan kompatibilitas

`FarmBackupCodec` menulis envelope schema JSON versi 5 untuk sapi, pakan individual, histori kelompok, rencana pakan kelompok, dan arsip relasi lama. Payload berada di `data`, shared foundation versi 2, domain namespace versi 1. [Aturan migrasi](schema-migration.md) menjelaskan validasi, identitas dan proteksi reader lama. Versi unversioned/2/3/4 tetap dapat dimigrasikan. Migrasi versi 3 membuat satu catatan awal kelompok dari data lama; data individual sesudahnya tidak mengubah kelompok. Pembacaan disk dan impor cadangan memakai decoder yang sama. Format lama tanpa `schemaVersion`, `feedPlans`, atau sumber catatan bobot tetap diterima. Versi schema yang tidak dikenali ditolak.

Identifier penyimpanan, lokasi file, dan bundle/application ID lama sengaja tidak diubah saat package Dart menjadi `sapita_app`. Perubahan identifier tersebut membutuhkan rencana migrasi tersendiri. Nama lama pada identifier bukan teks brand yang ditampilkan pengguna.

Adapter native menulis file sementara lalu menggantikan file utama. Adapter browser memakai localStorage. Foto diserialkan sebagai base64, sehingga batas kuota perangkat/browser tetap berlaku. `latestCheckImages` bersifat sementara untuk alur peninjauan; foto tersimpan ada di `images`.

## API

Alamat gateway berasal dari `ApiConstants.baseUrl` dan dapat diganti dengan `--dart-define=API_BASE_URL=...`.

### Estimasi bobot

`POST /v2/weight`, multipart dengan satu sampai empat bagian `files`. `WeightService` mengembalikan `WeightEstimate`, bukan map JSON mentah. Field respons:

- `estimated_weight_kg`: bobot numerik yang valid.
- `prediction_spread_kg`: variasi prediksi opsional.
- `num_valid_images`: jumlah foto yang diterima, dan `rejected_files`: daftar foto yang ditolak (keduanya opsional).

Variasi prediksi tidak diperlakukan sebagai interval kepercayaan klinis atau jaminan akurasi.

### Perhitungan pakan

`POST /calculate-feed`, JSON (kompatibilitas Group Feed saja):

```json
{
  "weight": 350,
  "target": "penggemukan",
  "available_feeds": ["rumput", "jerami", "dedak"]
}
```

Target yang didukung: `pemeliharaan`, `pertumbuhan`, `penggemukan`. Minimal satu sumber serat (`rumput` atau `jerami`) dipilih dalam formulir. Tidak ada field umur, jenis kelamin, atau kondisi tubuh yang ditambahkan ke kontrak backend tanpa dukungan backend.

Respons memiliki `recommendation` per bahan dengan `as_fed_kg`, opsional `dry_matter_kg` dan `ratio_dm`; dapat menyertakan `total_dry_matter_kg`, `weight_kg`, `target`, `warning`, dan `notes`. Fixture kontrak ada di `test/helpers/feed_fixture.dart`.

Individual memakai `FeedService.fetchFeeds` (`GET /v2/feeds/{production_category}`) dan `calculateNutrition` (`POST /v2/nutrition`), dengan DTO request/response v2 serta `CattleNutritionContext`. `FarmStore` membuat snapshot evaluasi bertipe `nutritionEvaluation`; ini tidak otomatis menjadi ransum aktif/stok. `calculatePlan` dan `FeedResponseMapper` individual sudah dihapus. `FeedRation` tetap memvalidasi respons legacy Group Feed. Kg pakan segar dan bahan kering pada arsip legacy tetap merupakan besaran terpisah. [Detail cleanup](legacy-individual-cleanup.md).

`ApiResponse` menangani JSON dan error gateway/FastAPI yang dapat bertingkat. Timeout dan kegagalan jaringan diubah menjadi `ApiException`. Client HTTP yang disuntikkan tetap dimiliki pemanggil; client bawaan ditutup oleh service.

## Rencana aktif

Rencana menyimpan snapshot bobot, tanggal pengukuran, umur, dan jenis kelamin. Rencana menjadi tidak aktif untuk rekap saat data tersebut berubah atau bobot perlu diperiksa lagi. Riwayat rencana tetap disimpan. Nama sapi boleh diedit tanpa mengubah takaran sebelumnya; nama dalam rencana adalah snapshot saat perhitungan.

Jam store dapat disuntikkan agar batas aktivitas tujuh hari dan pengingat dapat diuji deterministik. Jika dua rencana memiliki timestamp yang sama, rencana yang terakhir disimpan dipilih.

## Verifikasi

Tes mencakup kontrak HTTP, pemetaan satuan, data tidak valid, persistensi, kegagalan simpan, operasi bersamaan, hasil AI tertinggal, pemulihan cadangan, isolasi store, dan alur widget. Tes widget ukuran layar tidak menggantikan pengujian kamera, keyboard, aksesibilitas, dan signing pada perangkat.

CI mengikuti [panduan Flutter continuous delivery](https://docs.flutter.dev/deployment/cd) dan [flutter-action](https://github.com/subosito/flutter-action). Flutter dipatok ke 3.24.5 agar perubahan SDK dilakukan sebagai perubahan terpisah. Diagnostic info bersifat advisory; error dan warning analyzer menggagalkan CI. CI saat ini membangun web; build/signing iOS perlu dilakukan pada macOS dengan Xcode.


## Farm Command Center

`FarmStatus` memusatkan aturan pengingat bobot, pemilihan rencana terbaru, dan kesiapan rencana. Store, daftar sapi, rekap pakan, serta proyeksi Command Center memakai aturan yang sama.

`FarmCommandCenter.fromSnapshot` membentuk proyeksi read-only dari `FarmSnapshot` dan waktu yang diberikan store. Proyeksi memiliki ringkasan, satu tindakan berikutnya per sapi, rekap bahan aktif, dan gabungan aktivitas bobot/rencana. Tidak ada schema persisten atau sumber kebenaran kedua. Aktivitas bertanggal di masa depan tidak masuk daftar terbaru. Urutan prioritas deterministik: prasyarat bobot, lalu kebutuhan rencana, dengan bobot tertua didahulukan dalam prioritas yang sama.

`FarmTab` mendefinisikan empat tujuan shell. `MainScreen` menyimpan tujuan aktif dan permintaan filter. `CattleListScreen.didUpdateWidget` menerapkan permintaan filter baru tanpa membuat salinan halaman daftar. `IndexedStack` mempertahankan state tab. `PopScope` mengembalikan pengguna ke Ringkasan dari tab utama lain; route detail tetap ditangani Navigator yang sudah ada.

Penangkapan foto diganti oleh peninjauan hasil. Sesudah bobot disimpan dan pengguna lanjut ke pakan, route peninjauan diganti kalkulator. Dua langkah kalkulator/hasil tetap berpasangan agar input dapat diperbaiki. Validator, kontrak API, tetap berlaku. Cadangan memakai schema 5 dengan migrasi unversioned/2/3/4.

Brand tampilan dan class entry point menjadi SAPIENS/`SapiensApp`; package Dart tetap `sapita_app`. Binary desktop menjadi `sapiens`, sedangkan application ID serta lokasi data lama dipertahankan. Rename bundle ID atau package internal adalah migrasi terpisah.


## Preview foto lintas platform

Model `SelectedImage` tetap menyimpan byte read-only. Widget `PhotoPreview` membuat satu salinan `Uint8List` biasa untuk decoder gambar Flutter/browser, lalu menggunakan salinan itu sampai objek foto berubah. Ini menghindari kegagalan interop decoder web pada buffer read-only tanpa membuka mutasi model. Widget yang sama dipakai pada pemilihan foto, hasil estimasi AI, avatar, dan galeri profil. Kegagalan format ditampilkan sebagai pesan agar pengguna memilih file lain. Tes Chrome dan VM memeriksa empat foto terpilih, penghapusan, perubahan foto, penggunaan kembali buffer, serta file rusak.


## Digital Twin Ternak: individual utama, kelompok mandiri opsional

`LivestockGroup` memiliki ID stabil, tanggal dibuat, dan histori immutable `GroupRecord`. Data kini berasal dari catatan terakhir, bukan agregasi sapi. Catatan menyimpan nama, jumlah, bobot rata-rata opsional, target, catatan pengguna, status arsip, waktu, dan sumber perubahan. `FarmStore` menambahkan catatan melalui antrean transaksi yang sama dengan fitur individual. Edit individual tidak mengubah kelompok atau historinya.

`GroupFeedService` mengirim bobot rata-rata ke transport `FeedService` yang sudah ada. `FeedRation` memetakan serta memvalidasi respons legacy Group Feed; individual tidak memakainya. `GroupFeedPlan` menyimpan takaran per ekor beserta jumlah, bobot rata-rata, target, dan revisi input. Total kelompok diturunkan dari snapshot rencana tersebut. `inputRevision` berubah hanya saat input perhitungan berubah; perubahan bolak-balik tetap menghasilkan revisi baru, sehingga rencana lama tidak hidup kembali. Hasil tertinggal ditolak saat disimpan. Nama/catatan tidak membatalkan pakan.

`GroupRules` memvalidasi histori, batas angka, identitas, dan relasi rencana terhadap input historisnya. UI berada di `screens/groups/` dan memakai komponen yang sudah ada. `MainScreen` langsung memakai `CattleListScreen` pada tab Ternak. Tidak ada pemilih mode atau wrapper kelompok pada jalur utama. `GroupListScreen` dibuka sebagai route tambahan dari tautan opsional; kembali menampilkan halaman asal dengan pencarian/filter tetap tersimpan. Home dan Pakan mengutamakan profil individual. Rekap bahan membuka cakupan individual secara default; pintasan dari kelompok memakai `initialGroupScope: true`. Kedua cakupan tetap tidak dijumlahkan otomatis.

`LegacyGroupMembership` adalah lampiran read-only untuk menjaga cadangan lama, tanpa operasi perpindahan atau pembacaan anggota aktif di aplikasi. `LegacyGroupMigration` dipanggil hanya untuk format lama. Detail migrasi, pengarsipan, dan batas pengembangan dicatat di [Digital Twin](digital-twin.md).

## Komponen tampilan fitur

`CommandCenterScreen` menyusun bagian halaman dan menangani navigasi. `FarmMetricCard` serta `FarmFeedSummary` menerima nilai/proyeksi dan callback; keduanya tidak mengakses store. `CattleFeedPanel` menerima sapi, rencana, dan status terkini untuk menampilkan aksi pakan; penyimpanan tetap berada di alur kalkulator/store. `GroupRecordTile` hanya memformat satu catatan historis kelompok, termasuk label sumber dan waktu lokal.

Komponen tersebut berada dalam `screens/<fitur>/widgets/`, agar widget khusus fitur tidak memenuhi direktori widget bersama. Folder `lib/widgets/` berisi komponen lintas fitur seperti panel, halaman, dan preview foto. Perubahan ini tidak menambah state kedua atau mengubah serialisasi data.

## Phase 1 — fondasi model data bersama

`Cattle` kini menjadi facade untuk komposisi `SharedTwinCore` dan batas modul Beef/Dairy. Sistem produksi bertipe, status keluar/arsip, histori bersama, pemeriksaan ID, serta aturan retry rencana dijelaskan pada [Data Model Foundation](data-model-foundation.md). Phase 1 memakai schema 4 dengan blok tambahan versi 1; Phase 2 menaikkan envelope ke schema 5.

Phase 2 menambah `FarmPayloadCodec`/`FarmPayloadShape` untuk validasi isi lintas versi, `SnapshotUpgrade` untuk backfill murni, dan `FarmIdentity` untuk identitas lokal/legacy yang dibedakan asalnya. Store melakukan write upgrade sebelum publish. `PersistedTime` mempertahankan literal timestamp dan `AgeEvidence` menjaga kepastian umur tanpa DOB buatan. Adapter/lokasi data tetap sama.

Shared Core UI memakai operasi store yang sama untuk kategori, status, tahap hidup, dan kesehatan. Form memeriksa identitas farm, revisi pengaturan, atau jumlah event sesuai operasi sebelum menyimpan agar form tertinggal tidak menimpa perubahan yang relevan. Guard tersebut bersifat lokal dan tidak menambah field persistensi atau menggantikan kontrol konkurensi lintas perangkat. Detail tampilan, histori, dan batas umur ada di [Shared Core UI](shared-core-ui.md).


## Phase 4 — Beef

`BeefExtension` memiliki histori immutable bertipe, sementara `BeefGrowth`, `BeefFeedContext`, dan `BeefFeedDemand` menyediakan aturan deterministik. `BeefRules` memvalidasi ledger dan referensi reproduksi sebelum persistensi; tidak menambah state management atau sumber kebenaran kedua. `FarmSnapshot.feedStock` adalah ledger bersama dalam kg pakan segar. Semua mutasi melalui FarmStore dan write-before-publish. Detail gate versi, batas backend dan cakupan stok ada di [Beef Module](beef-module.md).


## Phase 5 — Dairy

`DairyExtension` versi 2 memuat event domain dan snapshot susu immutable. `DairyRules` menjaga shape, tanggal, koreksi harian, paritas dan referensi lintas histori; `DairyMetrics` adalah proyeksi kalender tanpa event sintetis atau state kedua. Calving adalah sumber siklus, susu adalah fakta per tanggal, dan window masa tahan berasal dari pengguna. Reader Phase 4 menolak namespace baru; root schema 5/foundation 3, Shared Twin 2 serta Beef 2 dipertahankan. Detail denominator, boundaries dan batas backend ada di [Dairy Module](dairy-module.md).
